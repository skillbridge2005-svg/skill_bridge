
require("dotenv").config();

const { initializeApp } = require("firebase-admin/app");
const {
  FieldValue,
  getFirestore,
} = require("firebase-admin/firestore");

const crypto = require("crypto");

const { setGlobalOptions } = require("firebase-functions");
const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const logger = require("firebase-functions/logger");
const Razorpay = require("razorpay");
const { GoogleGenAI } = require("@google/genai");

setGlobalOptions({
  maxInstances: 10,
});

initializeApp();

const db = getFirestore();

/**
 * Create a Gemini client when an API key is available.
 * @return {GoogleGenAI|null} Gemini client, or null if unconfigured.
 */
function getGeminiClient() {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey) {
    return null;
  }

  return new GoogleGenAI({apiKey: apiKey});
}

/**
 * Read an image payload from a Gemini Interactions response.
 * @param {object} interaction Gemini interactions response.
 * @return {{imageBase64: string, mimeType: string}|null} Image payload.
 */
function extractInteractionImage(interaction) {
  const candidates = [
    interaction?.output_image,
    interaction?.outputImage,
    interaction?.outputs?.find?.((item) => item?.type === "image"),
  ];

  for (const image of candidates) {
    const imageBase64 = image?.data || image?.imageBytes || image?.b64_json;
    if (typeof imageBase64 === "string" && imageBase64.trim()) {
      return {
        imageBase64: imageBase64.trim(),
        mimeType: image.mime_type || image.mimeType || "image/png",
      };
    }
  }

  return null;
}

/**
 * Read an inline image from a Gemini generateContent response.
 * @param {object} response Gemini SDK response.
 * @return {{imageBase64: string, mimeType: string}|null} Image payload.
 */
function extractInlineImage(response) {
  const parts = response?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) {
    return null;
  }

  for (const part of parts) {
    const data = part.inlineData || part.inline_data;
    if (data && typeof data.data === "string" && data.data.trim()) {
      return {
        imageBase64: data.data.trim(),
        mimeType: data.mimeType || data.mime_type || "image/png",
      };
    }
  }

  return null;
}

/**
 * Generate one UI mockup image.
 * @param {GoogleGenAI} ai Gemini client.
 * @param {string} prompt Image prompt.
 * @param {string} aspectRatio Aspect ratio such as 16:9 or 9:16.
 * @return {Promise<{imageBase64: string, mimeType: string}>} Image payload.
 */
async function generateOneDesignImage(ai, prompt, aspectRatio) {
  try {
    const interaction = await ai.interactions.create({
      model: "gemini-nano-banana-2.1",
      input: prompt,
      generation_config: {
        image_config: {
          aspect_ratio: aspectRatio,
          image_size: "1K",
        },
      },
    });

    const fromInteraction = extractInteractionImage(interaction);
    if (fromInteraction) {
      return fromInteraction;
    }
  } catch (error) {
    logger.warn("Interactions image generation failed", {
      message: error?.message,
    });
  }

  const response = await ai.models.generateContent({
    model: "gemini-2.5-flash-image",
    contents: prompt,
    config: {
      responseModalities: ["TEXT", "IMAGE"],
      imageConfig: {
        aspectRatio: aspectRatio,
        imageSize: "1K",
      },
    },
  });

  const fromContent = extractInlineImage(response);
  if (fromContent) {
    return fromContent;
  }

  throw new Error("The AI returned no generated project image.");
}

/**
 * Choose key software screens from the project requirements.
 * @param {string} text Model JSON/text response.
 * @param {string[]} categories Selected project categories.
 * @return {Array<{name: string, purpose: string}>} Screen list.
 */
function parseProjectScreens(text, categories) {
  const fallback = [
    {
      name: "Home",
      purpose: "Primary landing or home experience for the product.",
    },
    {
      name: "Dashboard",
      purpose: "Main workspace showing core actions and status.",
    },
    {
      name: "Details",
      purpose: "Key feature screen based on the project requirements.",
    },
    {
      name: "Profile",
      purpose: "Account, settings, or follow-up workflow screen.",
    },
  ];

  const match = String(text || "").match(/\[[\s\S]*\]/);
  if (!match) {
    return fallback;
  }

  try {
    const parsed = JSON.parse(match[0]);
    if (!Array.isArray(parsed)) {
      return fallback;
    }

    const screens = parsed
        .map((item) => ({
          name: String(item?.name || item?.title || "").trim(),
          purpose: String(item?.purpose || item?.description || "").trim(),
        }))
        .filter((item) => item.name)
        .slice(0, 4);

    return screens.length >= 3 ? screens : fallback;
  } catch (error) {
    logger.warn("Unable to parse AI screen list", {
      message: error?.message,
      categories: categories,
    });
    return fallback;
  }
}

/**
 * Read visible model text from a Gemini generateContent response.
 * @param {object} response Gemini SDK response.
 * @return {string} Trimmed generated text, or an empty string.
 */
function extractGeneratedText(response) {
  if (response && typeof response.text === "string") {
    const direct = response.text.trim();
    if (direct) {
      return direct;
    }
  }

  const parts = response?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) {
    return "";
  }

  return parts
      .filter((part) => !part.thought && typeof part.text === "string")
      .map((part) => part.text)
      .join("\n")
      .trim();
}

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

/*
|--------------------------------------------------------------------------
| Helper: Get Project Payment Amount
|--------------------------------------------------------------------------
*/

function getProjectAmount(projectData) {
  const possibleAmounts = [
    projectData.budget,
    projectData.amount,
    projectData.projectAmount,
  ];

  for (const value of possibleAmounts) {
    if (
      typeof value === "number" &&
      Number.isFinite(value) &&
      value > 0
    ) {
      return value;
    }
  }

  return null;
}

/*
|--------------------------------------------------------------------------
| Create Razorpay Order
|--------------------------------------------------------------------------
*/

exports.createRazorpayOrder = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to create a payment order."
    );
  }

  const { projectId } = request.data || {};

  if (!projectId || typeof projectId !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "A valid project ID is required."
    );
  }

  const clientId = request.auth.uid;

  try {
    const projectReference = db
      .collection("projects")
      .doc(projectId);

    const projectSnapshot = await projectReference.get();

    if (!projectSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "The SkillBridge project was not found."
      );
    }

    const projectData = projectSnapshot.data();

    if (projectData.clientId !== clientId) {
      throw new HttpsError(
        "permission-denied",
        "You are not authorized to make a payment for this project."
      );
    }

    const projectAmount = getProjectAmount(projectData);

    if (
      projectAmount === null ||
      !Number.isFinite(projectAmount) ||
      projectAmount <= 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The project does not have a valid payment amount."
      );
    }

    const amountInPaise = Math.round(projectAmount * 100);

    if (
      !Number.isSafeInteger(amountInPaise) ||
      amountInPaise <= 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The project payment amount is invalid."
      );
    }

    if (projectData.paymentStatus === "paid") {
      throw new HttpsError(
        "failed-precondition",
        "This project has already been paid."
      );
    }

    const order = await razorpay.orders.create({
      amount: amountInPaise,
      currency: "INR",
      receipt: `skillbridge_${projectId}_${Date.now()}`,
      notes: {
        projectId: projectId,
        clientId: clientId,
      },
    });

    logger.info("Razorpay order created", {
      orderId: order.id,
      projectId: projectId,
      clientId: clientId,
      amount: projectAmount,
    });

    return {
      success: true,
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: process.env.RAZORPAY_KEY_ID,
    };
  } catch (error) {
    logger.error("Razorpay order creation failed", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Unable to create Razorpay order."
    );
  }
});

/*
|--------------------------------------------------------------------------
| Verify Razorpay Payment
|--------------------------------------------------------------------------
*/

exports.verifyRazorpayPayment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to verify a payment."
    );
  }

  const {
    razorpayOrderId,
    razorpayPaymentId,
    razorpaySignature,
  } = request.data || {};

  if (
    typeof razorpayOrderId !== "string" ||
    !razorpayOrderId ||
    typeof razorpayPaymentId !== "string" ||
    !razorpayPaymentId ||
    typeof razorpaySignature !== "string" ||
    !/^[a-fA-F0-9]{64}$/.test(razorpaySignature)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Payment verification data is incomplete."
    );
  }

  const clientId = request.auth.uid;

  const paymentReference = db
    .collection("payments")
    .doc(razorpayPaymentId);

  try {
    const keySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!keySecret) {
      throw new HttpsError(
        "internal",
        "Payment verification is not configured."
      );
    }

    /*
     * 1. Verify Razorpay signature.
     */
    const generatedSignature = crypto
      .createHmac("sha256", keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");

    const isValid = crypto.timingSafeEqual(
      Buffer.from(generatedSignature, "hex"),
      Buffer.from(razorpaySignature, "hex")
    );

    if (!isValid) {
      logger.warn("Invalid Razorpay payment signature", {
        orderId: razorpayOrderId,
        paymentId: razorpayPaymentId,
        userId: clientId,
      });

      throw new HttpsError(
        "permission-denied",
        "Payment verification failed."
      );
    }

    /*
     * 2. Check duplicate payment.
     */
    const existingPayment = await paymentReference.get();

    if (existingPayment.exists) {
      const existingData = existingPayment.data();

      const matchesVerifiedPayment =
        existingData.paymentId === razorpayPaymentId &&
        existingData.orderId === razorpayOrderId &&
        existingData.clientId === clientId &&
        existingData.status === "verified" &&
        typeof existingData.projectId === "string";

      if (!matchesVerifiedPayment) {
        throw new HttpsError(
          "already-exists",
          "A conflicting payment record already exists."
        );
      }

      return {
        success: true,
        verified: true,
        alreadyProcessed: true,
        paymentId: razorpayPaymentId,
        orderId: razorpayOrderId,
        projectId: existingData.projectId,
      };
    }

    /*
     * 3. Fetch Razorpay order.
     */
    const order = await razorpay.orders.fetch(razorpayOrderId);

    /*
     * 4. Check order ownership.
     */
    if (
      !order.notes ||
      order.notes.clientId !== clientId
    ) {
      logger.warn("Razorpay order does not belong to caller", {
        orderId: razorpayOrderId,
        userId: clientId,
      });

      throw new HttpsError(
        "permission-denied",
        "This payment order does not belong to you."
      );
    }

    /*
     * 5. Get project ID from order notes.
     */
    const projectId = order.notes.projectId;

    if (
      typeof projectId !== "string" ||
      !projectId
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Project information is missing from the payment order."
      );
    }

    /*
     * 6. Validate order amount and currency.
     */
    if (
      !Number.isSafeInteger(order.amount) ||
      order.amount <= 0 ||
      order.currency !== "INR"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The payment order has an invalid amount or currency."
      );
    }

    /*
     * 7. Fetch actual Razorpay payment.
     */
    const payment = await razorpay.payments.fetch(
      razorpayPaymentId
    );

    /*
     * 8. Verify payment belongs to order.
     */
    if (payment.order_id !== razorpayOrderId) {
      throw new HttpsError(
        "failed-precondition",
        "Payment does not belong to the specified order."
      );
    }

    /*
     * 9. Verify payment is captured.
     */
    if (payment.status !== "captured") {
      throw new HttpsError(
        "failed-precondition",
        `Payment is not captured. Current status: ${payment.status}`
      );
    }

    /*
     * 10. Verify payment amount.
     */
    if (payment.amount !== order.amount) {
      throw new HttpsError(
        "failed-precondition",
        "Payment amount does not match the order amount."
      );
    }

    /*
     * 11. Verify currency.
     */
    if (payment.currency !== order.currency) {
      throw new HttpsError(
        "failed-precondition",
        "Payment currency does not match the order currency."
      );
    }

    const verifiedAmount = order.amount / 100;

    /*
     * 12. Prepare project reference.
     */
    const projectReference = db
      .collection("projects")
      .doc(projectId);

    /*
     * 13. Atomic Firestore transaction.
     */
    await db.runTransaction(async (transaction) => {
      const [
        existingPaymentInTransaction,
        projectSnapshot,
      ] = await Promise.all([
        transaction.get(paymentReference),
        transaction.get(projectReference),
      ]);

      if (!projectSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "The SkillBridge project was not found."
        );
      }

      const projectData = projectSnapshot.data();

      if (projectData.clientId !== clientId) {
        throw new HttpsError(
          "permission-denied",
          "You are not authorized to pay for this project."
        );
      }

      const projectAmount = getProjectAmount(projectData);

      if (projectAmount === null) {
        throw new HttpsError(
          "failed-precondition",
          "The project does not have a valid payment amount."
        );
      }

      const expectedAmountInPaise = Math.round(
        projectAmount * 100
      );

      if (expectedAmountInPaise !== order.amount) {
        throw new HttpsError(
          "failed-precondition",
          "Payment amount does not match the project amount."
        );
      }

      if (existingPaymentInTransaction.exists) {
        const existingData =
          existingPaymentInTransaction.data();

        const matchesVerifiedPayment =
          existingData.paymentId === razorpayPaymentId &&
          existingData.orderId === razorpayOrderId &&
          existingData.projectId === projectId &&
          existingData.clientId === clientId &&
          existingData.amount === verifiedAmount &&
          existingData.amountInPaise === order.amount &&
          existingData.currency === order.currency &&
          existingData.status === "verified";

        if (!matchesVerifiedPayment) {
          throw new HttpsError(
            "already-exists",
            "A conflicting payment record already exists."
          );
        }
      } else {
        transaction.create(paymentReference, {
          paymentId: razorpayPaymentId,
          orderId: razorpayOrderId,
          projectId: projectId,
          clientId: clientId,
          amount: verifiedAmount,
          amountInPaise: order.amount,
          currency: order.currency,
          status: "verified",
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      if (projectData.paymentStatus !== "paid") {
        transaction.update(projectReference, {
          paymentStatus: "paid",
          paymentId: razorpayPaymentId,
          paidAmount: verifiedAmount,
          paidAt: FieldValue.serverTimestamp(),
        });
      }
    });

    logger.info("Payment verified and saved", {
      paymentId: razorpayPaymentId,
      orderId: razorpayOrderId,
      projectId: projectId,
      clientId: clientId,
      amount: verifiedAmount,
    });

    return {
      success: true,
      verified: true,
      paymentId: razorpayPaymentId,
      orderId: razorpayOrderId,
      projectId: projectId,
      amount: verifiedAmount,
      currency: order.currency,
    };
  } catch (error) {
    logger.error("Payment verification failed", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Unable to verify and save payment."
    );
  }
});

/*
|--------------------------------------------------------------------------
| Generate AI Project Content — Gemini
|--------------------------------------------------------------------------
*/

exports.generateProjectContent = onCall(
  {
    maxInstances: 5,
    timeoutSeconds: 120,
  },
  async (request) => {
    /*
     * 1. Authentication.
     */
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please log in to use the AI Project Assistant."
      );
    }

    /*
     * 2. Read request data.
     */
    const {
      title,
      categories,
      description,
      requirements,
      contentType,
    } = request.data || {};

    /*
     * 3. Validate title.
     */
    if (
      typeof title !== "string" ||
      !title.trim() ||
      title.trim().length > 150
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Enter a valid project title."
      );
    }

    /*
     * 4. Validate categories.
     */
    if (
      !Array.isArray(categories) ||
      categories.length > 10 ||
      !categories.every(
        (category) =>
          typeof category === "string" &&
          category.length <= 80
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Project categories are invalid."
      );
    }

    /*
     * 5. Validate content type.
     */
    const supportedTypes = [
      "description",
      "requirements",
      "technologies",
      "analysis",
    ];

    if (!supportedTypes.includes(contentType)) {
      throw new HttpsError(
        "invalid-argument",
        "Unsupported project content type."
      );
    }

    /*
     * 6. Validate optional fields.
     */
    if (
      description != null &&
      (
        typeof description !== "string" ||
        description.length > 5000
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Project description is too long."
      );
    }

    if (
      requirements != null &&
      (
        typeof requirements !== "string" ||
        requirements.length > 5000
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Project requirements are too long."
      );
    }

    /*
     * 7. Check Gemini API key.
     */
    const ai = getGeminiClient();

    if (!ai) {
      logger.error("GEMINI_API_KEY is not configured.");

      throw new HttpsError(
        "failed-precondition",
        "AI generation is not configured."
      );
    }

    /*
     * 8. Prepare common project information.
     */
    const projectDetails = `
Project title: ${title.trim()}
Categories: ${categories.join(", ") || "Not specified"}
Description: ${description || "Not provided"}
Requirements: ${requirements || "Not provided"}
`;

    /*
     * 9. Prepare prompts for all supported operations.
     */
    const prompts = {
      description: `
You are a professional software project planning assistant.

Based on the following project details, create a clear and
professional project description.

${projectDetails}

Explain the project's purpose, target users, main features,
and expected outcome. Use language suitable for a client
publishing a software development project.

Make the description specific to this project.
Return only the project description.
`,

      requirements: `
You are an experienced software requirements analyst.

Create detailed, realistic requirements for this project.

${projectDetails}

Generate 8 to 12 numbered requirements covering relevant
functional features, security, data validation, error handling,
testing, and deployment where appropriate.

Make the requirements specific to the proposed project.
Avoid generic filler and unrelated features.

Return only the numbered requirements.
`,

      technologies: `
You are an experienced software technology advisor.

Recommend suitable technologies for this project.

${projectDetails}

Recommend appropriate frontend, backend, database,
authentication, API, and deployment technologies where relevant.

Briefly explain why each recommendation is appropriate.
Do not assume Flutter or Firebase is required unless suitable.

Return a concise, organized list of recommendations.
`,

      analysis: `
You are an experienced software architect and project analyst.

Analyze the proposed project.

${projectDetails}

Provide a structured analysis with these sections:

1. Project understanding and primary objective.
2. Major functional modules.
3. Important technical requirements.
4. Security and validation considerations.
5. Recommended development phases.
6. Technical risks and practical suggestions.
7. Missing information that should be clarified.

Tailor the analysis to the actual project.
Do not claim that development or testing has already occurred.

Return the analysis in clear, readable sections.
`,
    };

    /*
     * 10. Generate content with Gemini.
     */
    try {
      const response = await ai.models.generateContent({
        model: "gemini-3.5-flash-lite",
        contents: prompts[contentType],
        config: {
          temperature: 0.4,
          maxOutputTokens: 8192,
          thinkingConfig: {
            thinkingLevel: "MINIMAL",
          },
        },
      });

      const generatedText = extractGeneratedText(response);

      if (!generatedText) {
        const finishReason =
          response?.candidates?.[0]?.finishReason || "unknown";

        logger.error("AI returned empty content", {
          contentType,
          finishReason,
        });

        throw new Error(
          `The AI returned an empty response (${finishReason}).`
        );
      }

      logger.info("AI project content generated", {
        contentType: contentType,
        userId: request.auth.uid,
      });

      return {
        success: true,
        contentType: contentType,
        content: generatedText,
      };
    } catch (error) {
      logger.error("AI project content generation failed", {
        contentType: contentType,
        errorName: error?.name,
        message: error?.message,
        status: error?.status,
        code: error?.code,
        stack: error?.stack,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Unable to generate project content. Please try again."
      );
    }
  }
);

/*
|--------------------------------------------------------------------------
| Generate AI Project Design — Gemini
|--------------------------------------------------------------------------
*/

exports.generateProjectDesign = onCall(
  {
    maxInstances: 5,
    timeoutSeconds: 240,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please log in to generate a project design."
      );
    }

    const {
      title,
      categories,
      description,
      requirements,
      technologies,
    } = request.data || {};

    if (
      typeof title !== "string" ||
      !title.trim() ||
      title.trim().length > 150
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Enter a valid project title."
      );
    }

    if (
      !Array.isArray(categories) ||
      categories.length > 10 ||
      !categories.every(
        (category) =>
          typeof category === "string" &&
          category.length <= 80
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Project categories are invalid."
      );
    }

    const optionalFields = {
      description,
      requirements,
      technologies,
    };

    for (const [field, value] of Object.entries(optionalFields)) {
      if (
        value != null &&
        (
          typeof value !== "string" ||
          value.length > 5000
        )
      ) {
        throw new HttpsError(
          "invalid-argument",
          `Project ${field} is invalid or too long.`
        );
      }
    }

    if (
      typeof requirements !== "string" ||
      !requirements.trim()
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Enter project requirements before generating a design."
      );
    }

    const ai = getGeminiClient();

    if (!ai) {
      logger.error("GEMINI_API_KEY is not configured.");

      throw new HttpsError(
        "failed-precondition",
        "AI generation is not configured."
      );
    }

    const joinedCategories = categories.join(", ") || "Not specified";
    const isMobile = joinedCategories.toLowerCase().includes("mobile");
    const aspectRatio = isMobile ? "9:16" : "16:9";

    try {
      const screenResponse = await ai.models.generateContent({
        model: "gemini-3.5-flash-lite",
        contents: `
You plan software UI screens from project requirements.

Project title: ${title.trim()}
Categories: ${joinedCategories}
Description: ${description || "Not provided"}
Requirements:
${requirements}

Return ONLY a JSON array of 4 objects.
Each object must have:
- name: short screen title
- purpose: one sentence describing what this page does

Choose the 4 most important user-facing pages for this product.
`,
        config: {
          temperature: 0.2,
          maxOutputTokens: 800,
          thinkingConfig: {
            thinkingLevel: "MINIMAL",
          },
        },
      });

      const screens = parseProjectScreens(
          extractGeneratedText(screenResponse),
          categories
      );

      const images = await Promise.all(screens.map(async (screen) => {
        const prompt = `
Create one polished, realistic software UI mockup image for a single
application page. Show a complete high-fidelity ${isMobile ?
    "mobile app" : "web or desktop"} screen with readable layout,
consistent branding, and production-quality visual design.

This image is page ${screen.name} of a multi-page product design.
Screen purpose: ${screen.purpose}

Use the project requirements below so the layout, features, labels,
and content match this software. Show only this one full page. Do not
create a collage, extra device frames, watermarks, or captions outside
the UI.

Project title: ${title.trim()}
Categories: ${joinedCategories}
Description: ${description || "Not provided"}
Suggested technologies: ${technologies || "Not provided"}
Requirements:
${requirements}
`;

        const generated = await generateOneDesignImage(
            ai,
            prompt,
            aspectRatio
        );

        return {
          label: screen.name,
          purpose: screen.purpose,
          mimeType: generated.mimeType,
          imageBase64: generated.imageBase64,
        };
      }));

      if (!images.length) {
        throw new Error("The AI returned no generated project pages.");
      }

      logger.info("AI multi-page project design generated", {
        userId: request.auth.uid,
        pageCount: images.length,
      });

      return {
        success: true,
        imageBase64: images[0].imageBase64,
        images: images,
      };
    } catch (error) {
      logger.error("AI project design generation failed", {
        errorName: error?.name,
        message: error?.message,
        status: error?.status,
        code: error?.code,
        userId: request.auth.uid,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Unable to generate the project design. Please try again."
      );
    }
  }
);
