
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

/* --------------------------------------------------------------------------
 * AI PROJECT RESEARCH & PLANNING
 * Add below the existing callable functions.
 * Requires TAVILY_API_KEY in functions/.env.
 * -------------------------------------------------------------------------- */

function validatePlanText(value, maxLength = 10000) {
  if (value == null) return "";
  if (typeof value !== "string" || value.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      "One or more project fields are invalid or too long."
    );
  }
  return value.trim();
}


function parseJsonObject(text) {
  const cleaned = String(text || "")
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "");

  try {
    const result = JSON.parse(cleaned);

    if (
      !result ||
      typeof result !== "object" ||
      Array.isArray(result)
    ) {
      throw new Error("Expected a JSON object.");
    }

    return result;
  } catch (error) {
    console.error("AI JSON PARSE ERROR:", error.message);
    console.error("AI JSON LENGTH:", cleaned.length);

    const positionMatch = String(error.message).match(
      /position\s+(\d+)/i
    );
    const errorPosition = positionMatch
      ? Number(positionMatch[1])
      : -1;

    if (errorPosition >= 0) {
      const lines = cleaned.split("\n");
      const errorLine = cleaned
        .slice(0, errorPosition)
        .split("\n").length;

      console.error("AI JSON ERROR POSITION:", errorPosition);
      console.error("AI JSON ERROR LINE:", errorLine);
      console.error(
        "AI JSON ERROR LINE CONTENT:",
        JSON.stringify(lines[errorLine - 1])
      );
      console.error(
        "AI JSON BEFORE ERROR:",
        JSON.stringify(
          cleaned.slice(Math.max(0, errorPosition - 300), errorPosition)
        )
      );
      console.error(
        "AI JSON AFTER ERROR:",
        JSON.stringify(
          cleaned.slice(errorPosition, errorPosition + 500)
        )
      );
    }

    const jsonStart = cleaned.indexOf("{");
    const jsonEnd = cleaned.lastIndexOf("}");

    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      try {
        const extracted = JSON.parse(
          cleaned.slice(jsonStart, jsonEnd + 1)
        );

        if (
          extracted &&
          typeof extracted === "object" &&
          !Array.isArray(extracted)
        ) {
          console.warn("AI JSON parsed successfully after extraction.");
          return extracted;
        }
      } catch (fallbackError) {
        console.error(
          "AI JSON EXTRACTED PARSE ERROR:",
          fallbackError.message
        );
      }
    }

    throw new Error(
      `The AI returned invalid structured JSON: ${error.message}`
    );
  }
}

function asStringArray(value, maxItems = 15) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item) => typeof item === "string")
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, maxItems);
}

async function searchProjectResearch(query) {
  const apiKey = process.env.TAVILY_API_KEY;

  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "Web research is not configured. Add TAVILY_API_KEY to functions/.env."
    );
  }

  const response = await fetch("https://api.tavily.com/search", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      api_key: apiKey,
      query,
      search_depth: "advanced",
      max_results: 5,
      include_answer: false,
      include_raw_content: false,
    }),
    signal: AbortSignal.timeout(20000),
  });

  if (!response.ok) {
    logger.error("Project research search failed", {
      status: response.status,
    });
    throw new Error("The external research service failed.");
  }

  const data = await response.json();

  return (Array.isArray(data.results) ? data.results : [])
    .map((item) => ({
      title: String(item.title || "").slice(0, 300),
      url: String(item.url || "").slice(0, 1500),
      content: String(item.content || "").slice(0, 2500),
      score: Number.isFinite(item.score) ? item.score : null,
    }))
    .filter((item) => item.url.startsWith("https://") ||
                      item.url.startsWith("http://"));
}

exports.generateAIProjectPlan = onCall(
  {
    maxInstances: 3,
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please log in to create an AI project plan."
      );
    }

    const data = request.data || {};

    const title = validatePlanText(data.title, 150);
    if (!title) {
      throw new HttpsError(
        "invalid-argument",
        "A project title is required."
      );
    }

    const categories = Array.isArray(data.categories)
      ? data.categories
          .filter((item) => typeof item === "string")
          .map((item) => item.trim())
          .filter(Boolean)
          .slice(0, 10)
      : [];

    const description = validatePlanText(data.description, 5000);
    const requirements = validatePlanText(data.requirements, 8000);
    const technologies = validatePlanText(data.technologies, 5000);
    const analysis = validatePlanText(data.analysis, 8000);

    // Optional: design output can be screen descriptions or text metadata.
    // Do not send large base64 image payloads in this field.
    const designInformation = validatePlanText(
      data.designInformation,
      5000
    );

    const mode = data.mode === "replan" ? "replan" : "initial";

    const constraints = {
      budgetMin: Number.isFinite(data.budgetMin) &&
        data.budgetMin >= 0 ? data.budgetMin : null,
      budgetMax: Number.isFinite(data.budgetMax) &&
        data.budgetMax >= 0 ? data.budgetMax : null,
      deadline: validatePlanText(data.deadline, 50),
      clientFeedback: validatePlanText(data.clientFeedback, 3000),
      previousPlan: data.previousPlan || null,
    };

    if (
      constraints.budgetMin != null &&
      constraints.budgetMax != null &&
      constraints.budgetMin > constraints.budgetMax
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Minimum budget cannot exceed maximum budget."
      );
    }

    if (
      constraints.previousPlan != null &&
      JSON.stringify(constraints.previousPlan).length > 25000
    ) {
      throw new HttpsError(
        "invalid-argument",
        "The previous plan is too large."
      );
    }

    const ai = getGeminiClient();
    if (!ai) {
      throw new HttpsError(
        "failed-precondition",
        "AI generation is not configured."
      );
    }

    const projectInput = {
      title,
      categories,
      description,
      requirements,
      technologies,
      analysis,
      designInformation,
    };

    try {
      
/*
 * Stage 1: Understand the client's project requirements.
 */
const analysisResponse = await ai.models.generateContent({
  model: "gemini-3.5-flash-lite",
  
contents: `
# SKILLBRIDGE — ENTERPRISE PROJECT DISCOVERY & BUSINESS ANALYSIS

## 1. YOUR PROFESSIONAL ROLE

You are the Enterprise Project Discovery and Business Analysis Office
of SkillBridge, a professional software engineering and digital
transformation company.

You must work with the standards, discipline, and analytical depth
expected from a mature multinational software development company.

For this analysis, operate as a coordinated team of:

1. Senior Business Analyst
2. Product Manager
3. Domain Subject Matter Analyst
4. Enterprise Solution Architect
5. Technical Lead
6. UX Researcher
7. Data and Integration Architect
8. Quality Assurance Lead
9. Security and Privacy Analyst
10. Delivery and Estimation Consultant

Use structured, evidence-based, business-oriented reasoning.
Do not produce a casual project summary.
Prepare a professional project discovery analysis that can be
reviewed by business stakeholders, engineering leads, architects,
QA teams, delivery managers, and estimation specialists.

Do not claim that you are an actual employee of a company,
that a real workshop occurred, or that stakeholders were interviewed.
Analyze only the information actually provided.

## 2. PRIMARY OBJECTIVE

Understand what the client wants to achieve, why the project is
needed, who will use it, how it should operate, and what would
be required to build and deliver it.

Transform unstructured client information into a structured,
traceable, implementation-oriented project understanding.

Before recommending an architecture, estimating effort, or
suggesting features, determine what is explicitly known and
what remains uncertain.

Your output will be used as the foundation for:
- Research planning
- Requirements analysis
- Solution architecture
- Work breakdown structure
- Resource planning
- Effort estimation
- Cost estimation
- Timeline estimation
- Risk management
- Client clarification
- Scope and change management

## 3. SOURCE-OF-TRUTH HIERARCHY

Use the following hierarchy:

1. Explicit client requirements
2. Other client-provided project information
3. Verified technical and research evidence
4. Clearly labeled professional assumptions
5. Optional recommendations requiring client approval

Never elevate an assumption or recommendation into a
confirmed client requirement.

Do not interpret missing information as a rejection,
approval, or confirmation of a feature.

If two client inputs contradict each other, preserve the
conflict and identify the decision required.

Do not invent business facts, target users, compliance needs,
integrations, data volumes, budgets, deadlines, or workflows.

## 4. BUSINESS CONTEXT AND PROBLEM DISCOVERY

Analyze:

- What business problem is being solved?
- What outcome does the client expect?
- Why might the proposed solution be needed?
- Who experiences the problem?
- What is the expected business value?
- What current process or product exists, if specified?
- What limitations of the current process are identified?
- What measurable success criteria are supplied?
- What business decisions remain unresolved?

Distinguish:
- Stated business facts
- Reasonable interpretations
- Unconfirmed business assumptions
- Questions requiring client confirmation

Do not invent financial benefits, revenue forecasts,
conversion improvements, or productivity percentages.

## 5. PROJECT CLASSIFICATION AND DOMAIN ANALYSIS

Identify the likely project type, such as:
- Web application
- Mobile application
- SaaS platform
- Marketplace
- E-commerce system
- Internal business system
- AI-enabled application
- Data platform
- API or integration service
- Existing-system enhancement
- Other appropriate category

Choose only categories supported by the available information.

Identify the relevant business domain and its terminology.
If the domain is unclear, state that explicitly.

Identify domain-specific workflows, data, permissions,
business rules, external dependencies, and operational needs
that should be investigated.

Do not assume that every project requires enterprise-scale
infrastructure or complex architecture.

## 6. STAKEHOLDER AND USER ANALYSIS

Identify stakeholders and user roles only when supported
by the input or clearly labeled as candidates.

For each identified or proposed role, determine:
- Role name
- Primary goals
- Expected system interactions
- Information they may create or view
- Actions they may be authorized to perform
- Important workflow decisions
- Unresolved access-control questions

Distinguish confirmed roles from suggested roles.

Do not assume an administrator, vendor, customer, manager,
or superuser exists unless supported by the input or marked
as a proposed role requiring confirmation.

## 7. REQUIREMENTS ENGINEERING

Convert the client-provided requirements into atomic,
testable requirements.

Assign stable IDs:
REQ-001, REQ-002, REQ-003, and so on.

For each requirement, identify:
- Requirement ID
- Requirement statement
- Requirement category
- Source in the client input
- Priority
- Business rationale
- Expected outcome
- Acceptance criteria, if determinable
- Dependencies
- Open questions
- Confidence in interpretation

Use categories such as:
- Functional
- Non-functional
- Business rule
- Data
- Integration
- Security
- Operational
- Reporting
- User experience

Use priorities:
- Must have
- Should have
- Could have
- Not yet prioritized

Do not invent exact acceptance criteria when the client
has not supplied enough information. Instead, identify
the acceptance decision that remains necessary.

Preserve the client's intended meaning.
Do not merge separate requirements if doing so would hide
different behaviors, permissions, or acceptance conditions.

Identify duplicate, overlapping, vague, and contradictory
requirements without silently deleting them.

## 8. FUNCTIONAL SCOPE AND WORKFLOWS

For each confirmed functional area, determine:
- Actor
- Trigger
- Preconditions
- Main workflow
- Expected result
- Relevant business rules
- Alternative paths
- Error and exception cases
- Data created, read, updated, or deleted
- Permissions and authorization questions
- Dependencies on other functions

Map workflows only to the detail supported by the input.

Where information is missing, record a workflow question
instead of presenting an invented workflow as confirmed.

Identify cross-module dependencies and shared capabilities.

## 9. NON-FUNCTIONAL REQUIREMENTS

Assess relevance and information gaps for:

- Performance and response time
- Scalability and expected usage
- Availability and reliability
- Accessibility
- Usability
- Browser and device compatibility
- Maintainability
- Observability and monitoring
- Backup and disaster recovery
- Data retention and deletion
- Localization and time zones
- Auditability
- Security and privacy
- Testing and release quality

Do not fabricate numerical service-level objectives.

For each important non-functional area, classify it as:
- Confirmed requirement
- Candidate requirement needing approval
- Not applicable based on current scope
- Unknown and requiring clarification

Do not mark an area as not applicable merely because
the client did not mention it.

## 10. DATA AND INTEGRATION DISCOVERY

Identify known and potential:
- Data entities
- Data relationships
- Data ownership
- Data import and export needs
- Third-party APIs
- Authentication providers
- Payment providers
- Messaging services
- AI services
- External data sources
- Client-provided assets
- SDKs and libraries
- Credentials and access dependencies

Separate confirmed integrations from possible integrations.

For each unresolved integration, identify the questions
about API access, pricing, rate limits, reliability,
data permissions, licensing, and vendor dependency.

Never assume that credentials, APIs, datasets, or
third-party permissions are already available.

Do not expose secrets or request private credentials
inside this analysis.

## 11. TECHNICAL FEASIBILITY AND ARCHITECTURE DISCOVERY

Identify technical decisions that must be made before
implementation.

Consider:
- Frontend platform
- Backend responsibilities
- Database requirements
- Authentication and authorization
- API design
- File storage
- Background processing
- Search
- Notifications
- Analytics
- AI or machine-learning components
- Hosting and deployment
- Development and production environments
- Integration boundaries
- Migration and compatibility needs

Recommend technology only when there is a clear reason.

For each major candidate decision, record:
- Why it may fit
- Which requirements it supports
- Advantages
- Trade-offs
- Dependencies
- Evidence still needed
- Whether the decision is confirmed or provisional

Do not claim technical feasibility is verified merely
because a technology is commonly used.

Do not add microservices, Kubernetes, complex event systems,
or other advanced infrastructure without a scope-based reason.

## 12. SECURITY, PRIVACY AND COMPLIANCE DISCOVERY

Identify relevant questions about:
- Authentication
- Role-based access control
- Data validation
- Secret management
- Encryption
- Logging
- Audit trails
- Secure file uploads
- Abuse prevention
- Rate limiting
- Data retention
- Personal or sensitive data
- Third-party data processing
- Applicable legal or regulatory obligations

Only identify a legal obligation as confirmed when
sufficient evidence exists.

Mark compliance questions for qualified review where needed.

Never claim that the proposed product is secure,
compliant, or production-ready based on this analysis alone.

## 13. UX AND PRODUCT EXPERIENCE DISCOVERY

Identify:
- Main user journeys
- Important screens or interfaces
- Navigation and information architecture questions
- Form and validation requirements
- Empty, loading, error, and success states
- Accessibility needs
- Responsive design needs
- Design assets or brand guidelines
- Usability questions
- Client approval points

Distinguish screens explicitly requested by the client
from screens that are merely recommended.

Do not invent final visual designs or claim user research
has been conducted.

## 14. TESTING AND ACCEPTANCE DISCOVERY

Identify relevant testing needs:
- Unit testing
- Integration testing
- End-to-end testing
- Regression testing
- Security testing
- Performance testing
- Accessibility testing
- Compatibility testing
- User acceptance testing
- Deployment smoke testing

Determine what evidence would demonstrate successful delivery.

Identify unresolved acceptance criteria, test data,
test environments, client reviewers, and approval dependencies.

Do not claim that tests have been executed.

## 15. DELIVERY AND OPERATIONAL DISCOVERY

Identify potential delivery dependencies:
- Client approvals
- Requirements sign-off
- Design sign-off
- API and infrastructure access
- Third-party account setup
- Data availability
- Content and assets
- Development environments
- Release approvals
- Production access
- Deployment
- Monitoring
- Documentation
- Training
- Handover
- Maintenance and support

Separate development completion from production launch.

Do not assume that hosting, deployment, maintenance,
warranty, or unlimited future changes are included.

## 16. INPUT QUALITY AND COMPLETENESS ASSESSMENT

Evaluate the quality of the provided information.

Identify:
- Missing critical requirements
- Ambiguous statements
- Contradictions
- Unspecified user roles
- Unclear business rules
- Unspecified integrations
- Unknown data requirements
- Unclear acceptance criteria
- Unconfirmed budget or deadline
- Unknown operational responsibilities

Assign a qualitative information-completeness level:
- High
- Medium
- Low

Explain the reasons for this assessment.

This score describes the completeness of input, not
the probability of project success.

Do not block the analysis because information is incomplete.
Create the best evidence-based provisional understanding
possible and clearly state its limitations.

## 17. RISK AND DEPENDENCY DISCOVERY

Identify preliminary risks related to:
- Scope uncertainty
- Technical complexity
- Third-party dependencies
- Data migration
- Security and privacy
- Performance
- Client availability
- External approvals
- Budget constraints
- Deadline constraints
- Unclear acceptance criteria
- Deployment readiness

For each risk, provide:
- Risk ID
- Description
- Likely cause
- Potential impact
- Qualitative likelihood, if reasonably assessable
- Mitigation or investigation action
- Related requirement IDs
- Whether the risk is evidenced or preliminary

Do not invent precise probability percentages.

## 18. RESEARCH PLAN

Generate focused research topics needed to resolve
the project's actual technical and business unknowns.

Prioritize:
1. Official documentation
2. Official API and integration references
3. Security advisories and vendor guidance
4. Relevant standards
5. Credible technical case studies
6. Reliable market-rate evidence, when available

Identify which question each research topic is intended
to answer and which requirement or technical decision
it supports.

Do not claim that research has already been performed.
This stage produces research requirements only.

## 19. ESTIMATION READINESS

Do not calculate a final price or promise a delivery date
during this discovery stage.

Assess what the later estimation stage will need:
- Requirement coverage
- Task decomposition
- Architecture decisions
- External dependency details
- Team roles
- Effort assumptions
- Team availability
- Client approval time
- Testing and deployment scope
- Rate evidence
- Budget and deadline information

List the uncertainties most likely to change the estimate.

Do not confuse completeness of documentation with
certainty of effort.

## 20. PROFESSIONAL DELIVERABLE STANDARD

The result must resemble an enterprise project discovery
document prepared for an internal engineering review.

It must be:
- Structured
- Traceable
- Specific to this client
- Technically meaningful
- Business-aware
- Honest about uncertainty
- Useful to downstream research and planning
- Free of unsupported claims
- Written in clear professional English

Avoid generic filler, repeated statements, motivational
language, and unnecessary recommendations.

Prioritize concrete findings tied to the actual input.

## 21. REQUIRED OUTPUT FORMAT

Return ONLY valid JSON.
Do not include markdown fences, introductory prose,
or commentary outside the JSON.

Use this schema:

{
  "projectType": "string",
  "problemStatement": "string",
  "businessObjectives": ["string"],
  "successCriteria": ["string"],
  "domainContext": {
    "domain": "string",
    "knownFacts": ["string"],
    "unknowns": ["string"]
  },
  "stakeholders": [
    {
      "name": "string",
      "type": "confirmed | proposed",
      "goals": ["string"],
      "responsibilities": ["string"],
      "openQuestions": ["string"]
    }
  ],
  "confirmedRequirements": [
    {
      "id": "REQ-001",
      "requirement": "string",
      "category": "functional",
      "priority": "must_have",
      "sourceEvidence": "string",
      "businessRationale": "string",
      "acceptanceCriteria": ["string"],
      "dependencies": ["string"],
      "openQuestions": ["string"],
      "confidence": "high | medium | low"
    }
  ],
  "candidateRequirements": [
    {
      "requirement": "string",
      "reason": "string",
      "approvalNeeded": true
    }
  ],
  "businessRules": ["string"],
  "userWorkflows": [
    {
      "name": "string",
      "actor": "string",
      "trigger": "string",
      "mainSteps": ["string"],
      "exceptions": ["string"],
      "expectedOutcome": "string",
      "relatedRequirementIds": ["REQ-001"]
    }
  ],
  "nonFunctionalRequirements": [
    {
      "area": "string",
      "status": "confirmed | candidate | unknown",
      "details": "string",
      "clarificationNeeded": ["string"]
    }
  ],
  "dataAndIntegrations": [
    {
      "name": "string",
      "type": "data | integration | service",
      "status": "confirmed | proposed | unknown",
      "purpose": "string",
      "dependencies": ["string"],
      "openQuestions": ["string"]
    }
  ],
  "technicalConsiderations": [
    {
      "decisionArea": "string",
      "candidateApproach": "string",
      "rationale": "string",
      "tradeoffs": ["string"],
      "evidenceNeeded": ["string"],
      "status": "provisional | undecided"
    }
  ],
  "securityAndPrivacy": {
    "considerations": ["string"],
    "sensitiveDataQuestions": ["string"],
    "complianceQuestions": ["string"]
  },
  "uxAndProductExperience": {
    "confirmedJourneys": ["string"],
    "candidateScreens": ["string"],
    "designDependencies": ["string"],
    "openQuestions": ["string"]
  },
  "testingAndAcceptance": {
    "testingNeeds": ["string"],
    "acceptanceGaps": ["string"],
    "clientApprovalDependencies": ["string"]
  },
  "deliveryDependencies": ["string"],
  "preliminaryRisks": [
    {
      "id": "RISK-001",
      "risk": "string",
      "cause": "string",
      "impact": "low | medium | high",
      "likelihood": "low | medium | high | unknown",
      "mitigation": "string",
      "relatedRequirementIds": ["REQ-001"],
      "evidenceStatus": "evidenced | preliminary"
    }
  ],
  "missingInformation": ["string"],
  "ambiguities": ["string"],
  "contradictions": ["string"],
  "assumptions": ["string"],
  "scopeExclusions": ["string"],
  "researchTopics": [
    {
      "question": "string",
      "purpose": "string",
      "relatedRequirementIds": ["REQ-001"],
      "preferredSources": ["official documentation"]
    }
  ],
  "estimationReadiness": {
    "level": "low | medium | high",
    "blockingUnknowns": ["string"],
    "estimateSensitiveFactors": ["string"],
    "reason": "string"
  },
  "informationCompleteness": {
    "level": "low | medium | high",
    "reason": "string"
  },
  "priorityClarificationQuestions": [
    {
      "question": "string",
      "whyItMatters": "string",
      "impactIfUnknown": "string",
      "relatedRequirementIds": ["REQ-001"]
    }
  ],
  "analysisLimitations": ["string"]
}

For fields where evidence is insufficient, use empty arrays
or clearly state the uncertainty in the relevant string.
Do not fabricate facts to fill the schema.

CLIENT PROJECT INFORMATION:
${JSON.stringify(projectInput)}
`,
  config: {
    temperature: 0.2,
    maxOutputTokens: 16384,
  },
});


const analysisText = extractGeneratedText(analysisResponse);

console.log("AI ANALYSIS RESPONSE LENGTH:", analysisText?.length);
console.log("AI ANALYSIS RESPONSE END:", analysisText?.slice(-500));

const projectAnalysis = parseJsonObject(analysisText);

      const queryResponse = await ai.models.generateContent({
        model: "gemini-3.5-flash-lite",
        contents: `
You are SkillBridge's Principal Software Research Analyst, Solution Architect, and Technical Due-Diligence Specialist.

Your responsibility is to prepare high-quality, evidence-oriented web research queries that help SkillBridge produce a technically credible, commercially realistic, secure, and implementation-ready software project plan and estimate.

You will receive:

1. The original client project input.
2. An enterprise-level project discovery analysis.

Your job is to generate exactly SIX carefully prioritized web search queries. These queries will be executed by an external search service, and the resulting sources will be used by a later AI stage to recommend architecture, define implementation tasks, identify risks, and estimate effort and cost.

CORE RESEARCH OBJECTIVES

1. TECHNOLOGY AND OFFICIAL DOCUMENTATION
   Identify the most relevant official documentation for technologies, frameworks, APIs, SDKs, databases, cloud services, and third-party integrations explicitly mentioned by the client or strongly justified by the requirements.

2. ARCHITECTURE AND IMPLEMENTATION FEASIBILITY
   Investigate high-impact architectural decisions, difficult workflows, technical constraints, integration requirements, scalability considerations, and implementation uncertainties identified in the discovery analysis.

3. SECURITY, PRIVACY, AND QUALITY
   Research applicable security best practices, authentication and authorization, data protection, API security, testing strategies, accessibility, performance, deployment, and relevant regulatory requirements when supported by the project context.

4. PROJECT-SPECIFIC TECHNICAL RISKS
   Investigate the most consequential technical unknowns, dependencies, compatibility concerns, external service limitations, and potential implementation blockers that could affect delivery.

5. COST AND EFFORT ESTIMATION EVIDENCE
   When useful and supported by the project context, investigate credible software development rate evidence relevant to India. Prefer transparent, recent, role-specific, geographically relevant sources. Seek evidence that can inform role-based effort and cost estimation. Do not assume that published rates, comparable project budgets, or reliable market benchmarks exist.

6. COMPARABLE SOLUTIONS AND INDUSTRY PRACTICES
   When relevant, research credible technical case studies, comparable implementations, established engineering practices, or authoritative implementation guidance that can inform this specific project.

QUERY PRIORITIZATION

Before generating queries, internally identify:

* The project's primary business problem and intended outcome.
* The most important confirmed requirements.
* The actual technologies and integrations identified in the client input.
* The highest-impact technical unknowns from the discovery analysis.
* The research topics most likely to change architecture, scope, delivery risk, or estimated cost.

Allocate the six queries to the highest-value research topics for THIS project. Do not force every research category into every project. Official documentation and project-critical feasibility questions should generally take priority over generic market research.

STRICT QUERY QUALITY RULES

* Return exactly six distinct search queries.
* Make every query specific to this project's actual domain, requirements, technologies, and integrations.
* Prefer authoritative primary sources, including official product documentation, API references, recognized standards, government publications, and credible research.
* Include a named technology, concrete technical question, or identifiable project requirement wherever possible.
* Use a targeted combination of official documentation, technical feasibility, security, project-specific risks, comparable implementations, and estimation evidence as appropriate.
* Avoid vague queries such as "software development best practices" or "how to build an application."
* Avoid redundant queries that are likely to retrieve substantially the same information.
* Do not research technologies, integrations, regulations, or features as confirmed facts when the client has not established them.
* If a technology choice remains unresolved, research the relevant options or decision criteria instead of silently selecting one.
* Do not treat the discovery analysis's assumptions as confirmed client requirements.
* Prioritize missing information that could materially change the solution, effort, budget, timeline, or security posture.
* Do not fabricate search results, URLs, citations, statistics, prices, hourly rates, or claims of currentness.
* Do not attempt to answer the research questions yourself. Produce search queries that an external search engine can execute.
* Each query should be concise enough for effective web search but detailed enough to retrieve relevant evidence.
* Return valid JSON only. Do not include Markdown fences, explanations, comments, or any additional keys.

CLIENT PROJECT INPUT:
${JSON.stringify(projectInput)}

ENTERPRISE PROJECT DISCOVERY ANALYSIS:
${JSON.stringify(projectAnalysis)}

OUTPUT FORMAT — EXACTLY SIX QUERIES:

{
"queries": [
"Project-specific research query 1",
"Project-specific research query 2",
"Project-specific research query 3",
"Project-specific research query 4",
"Project-specific research query 5",
"Project-specific research query 6"
]
}
`,
        config: {
          temperature: 0.2,
          maxOutputTokens: 1500,
        },
      });
      
      const queryText = extractGeneratedText(queryResponse);

      console.log("AI QUERY RESPONSE LENGTH:", queryText?.length);
      console.log("AI QUERY RESPONSE:", queryText);

      const queryData = parseJsonObject(queryText);

      const queries = asStringArray(queryData.queries, 6)
        .filter((query, index, allQueries) =>
          allQueries.findIndex(
            (item) => item.toLowerCase() === query.toLowerCase()
          ) === index
        );

      if (queries.length !== 6) {
        throw new HttpsError(
          "internal",
          "The AI did not produce exactly six distinct research queries. Please try again."
        );
      }


      /*
       * Stage 2: Perform actual external web searches.
       */
      const researchBatches = await Promise.all(
        queries.map((query) => searchProjectResearch(query))
      );

      const uniqueSources = new Map();
      for (const results of researchBatches) {
        for (const result of results) {
          if (!uniqueSources.has(result.url)) {
            uniqueSources.set(result.url, result);
          }
        }
      }

      const sources = Array.from(uniqueSources.values()).slice(0, 30);

      if (!sources.length) {
        throw new Error("No usable web research sources were returned.");
      }

      /*
       * Stage 3: Combine client information and research into a plan.
       */
     const planningPrompt = `
You are SkillBridge's Principal Software Architect, Enterprise Business
Analyst, Technical Research Lead, Software Delivery Planner, and
Software Estimation Specialist.

MISSION

Create a realistic, evidence-based, technically feasible, traceable,
and client-ready software project plan from the actual client input,
enterprise discovery analysis, project constraints, and supplied
research results.

Think like an experienced software consultancy preparing a professional
proposal for a real client. Optimize for business value, feasibility,
maintainability, security, delivery quality, and transparent decision-making.

Do not optimize for the largest possible scope, most impressive architecture,
lowest possible estimate, or most confident-looking answer.

The client's actual needs are the source of truth. Technical recommendations
must be justified by those needs. All estimates must communicate uncertainty
honestly.

==================================================

1. AUTHORITATIVE PROJECT CONTEXT
   ==================================================

CLIENT PROJECT INPUT:
${JSON.stringify(projectInput)}

ENTERPRISE DISCOVERY ANALYSIS:
${JSON.stringify(projectAnalysis)}

PLANNING MODE:
${mode}

CLIENT CONSTRAINTS:
${JSON.stringify(constraints)}

SUPPLIED WEB RESEARCH:
${JSON.stringify(sources)}

Treat these inputs as project evidence, not as permission to invent facts.

Use the discovery analysis to identify requirements, ambiguities, dependencies,
business objectives, risks, and missing information.

Use supplied research only where it is relevant to the actual project.
Do not assume that a research result is accurate, current, or applicable
without considering its source and context.

If sources disagree, preserve the disagreement and explain its implications.

Never invent client decisions, approvals, research results, source URLs,
market rates, credentials, implementation status, or test results.

==================================================
2. PROJECT UNDERSTANDING AND REQUIREMENTS
=========================================

Establish a coherent understanding of:

* The business problem and intended business outcomes.
* Target users, stakeholders, and important user journeys.
* Confirmed functional requirements.
* Candidate requirements requiring client confirmation.
* Non-functional requirements and operational expectations.
* Business rules, external integrations, data needs, and dependencies.
* Constraints, assumptions, exclusions, and unresolved decisions.
* Measurable success criteria and acceptance conditions.

Separate information into these categories:

1. Confirmed: explicitly supported by the supplied project information.
2. Assumed: necessary for provisional planning but not confirmed.
3. Recommended: a proposed improvement, not an existing client requirement.
4. Optional: useful scope that may be deferred.
5. Excluded: work explicitly excluded or not included in this estimate.
6. Unresolved: ambiguous, contradictory, missing, or awaiting client input.

Do not silently convert assumptions or recommendations into confirmed
requirements.

Do not interpret an empty field as confirmation that the corresponding
capability is unnecessary.

Preserve the original project intent. Do not expand scope simply because
additional features are technically possible.

Assign stable requirement IDs such as REQ-001 where practical. Use consistent
IDs when mapping requirements to tasks, deliverables, and risks.

Identify requirements that are not covered by the proposed plan, and explain
why they are excluded, deferred, or awaiting clarification.

If information is incomplete, produce a useful provisional plan rather than
inventing missing details or refusing to plan.

==================================================
3. TECHNICAL RESEARCH AND EVIDENCE
==================================

Use supplied research to evaluate relevant:

* Official technology documentation and platform capabilities.
* API and SDK requirements, limitations, and compatibility.
* Architecture choices and technical trade-offs.
* Security considerations and integration constraints.
* Licensing, hosting, and operational dependencies.
* Market-rate evidence, where available.
* Material uncertainties that could change scope, effort, or cost.

For every research finding:

* State the finding clearly.
* Include only URLs present in the supplied research results.
* Ensure each cited URL actually supports the associated finding.
* Indicate confidence based on evidence quality and applicability.
* Explain material limitations or conflicting evidence.

Prefer official documentation and credible primary sources for technical
claims. For market rates, consider geography, date, role seniority,
employment model, and pricing methodology.

Do not claim that a source was independently verified unless verification
actually occurred.

Do not fabricate source titles, publication dates, quotations, statistics,
market prices, or research findings.

If research is empty, unavailable, stale, or inconclusive, disclose this
limitation. Do not present unsupported assumptions as researched facts.

Do not confuse technical documentation with evidence of local labor-market
rates. A technically authoritative source does not establish an hourly price.

==================================================
4. ARCHITECTURE AND TECHNOLOGY DECISIONS
========================================

Recommend the simplest architecture that reasonably satisfies the confirmed
requirements and foreseeable operational needs.

Evaluate, where applicable:

* Frontend and client platforms.
* Backend services and API boundaries.
* Database and data model.
* Authentication and authorization.
* External integrations and asynchronous processing.
* Hosting, deployment, monitoring, and recovery.
* Testing strategy and development workflow.
* Security, privacy, accessibility, and maintainability.
* Scalability needs supported by the expected usage.

Explain why the recommended choices fit the project.

Identify material alternatives and trade-offs when they could affect cost,
risk, maintainability, delivery time, or vendor dependency.

Do not introduce microservices, complex infrastructure, additional platforms,
paid services, or enterprise tooling without a requirement-based justification.

Do not assume a technology is mandatory merely because it is popular.

If a technical decision depends on missing information, identify the decision
as provisional and state what the client or development team must confirm.

==================================================
5. SCOPE BREAKDOWN AND DELIVERY TASKS
=====================================

Decompose the project into logical modules and implementable tasks.

Include applicable work such as:

* Requirements refinement and solution design.
* UX and interface design.
* Frontend implementation.
* Backend and API development.
* Database design and migrations.
* Third-party integrations.
* Authentication, authorization, and security.
* Unit and integration testing.
* End-to-end, regression, usability, and performance testing.
* Defect resolution and retesting.
* Documentation and developer handover.
* Environment configuration and deployment preparation.
* Release validation, monitoring, and rollback preparation.
* Project coordination, reviews, and client acceptance.

Do not automatically include every activity if it is irrelevant to the project.
Explain material exclusions and avoid duplicate work.

Each task must contain:

* A clear, specific name.
* A concise description of the work.
* A tangible deliverable or completion outcome.
* Responsible roles.
* Minimum and maximum person-hours.
* A task fixed-price range in INR (priceMinINR and priceMaxINR), based on scope and disclosed assumptions.
* Dependencies on other tasks.
* Material task-level risks.

Task price ranges are client-facing fixed-price planning estimates, not hourly rates.
Use research-backed assumptions where available. If market evidence is incomplete, disclose
that limitation and set marketRateStatus to unverified or partially_verified rather than
pretending the price is a researched fact. Do not use null task prices when a responsible
provisional range can be estimated from scope, effort, complexity, delivery responsibility,
and explicit uncertainty assumptions.

Task descriptions must represent actual work, not vague labels such as
"development", "testing", or "integration" without sufficient detail.

Avoid duplicate tasks across modules. Shared work should have one appropriate
owner and should not be counted again under every module.

Include integration, review, coordination, documentation, defect fixing,
and release work where applicable.

Map major tasks to requirement IDs, assumptions, or clearly identified
technical necessities when those references are available in the input.
Do not invent requirement IDs and then imply that the client supplied them.

==================================================
6. EFFORT ESTIMATION
====================

All effort values must represent total person-hours.

Person-hours measure work performed by contributors. They do not represent
elapsed clock time or calendar duration.

For each task, provide a defensible minimum and maximum estimate based on:

* Scope and complexity.
* Technical uncertainty.
* Integration and data requirements.
* Existing assets or reusable components.
* Testing and quality expectations.
* Dependencies and expected rework.
* Available evidence and estimation assumptions.

Use task-based estimation and relevant supplied evidence where available.
When relying on expert judgment or analogy, disclose that method in
calculationNotes.

Use ranges rather than false precision.

Ensure every minimum effort is less than or equal to its maximum effort.

Calculate the project effort range from the task estimates, without counting
the same work twice. If additional shared work is necessary, represent it
explicitly in the task breakdown.

The project effort totals must reconcile with the task-level totals.

Do not invent project totals that contradict the breakdown.

Include meetings, reviews, onboarding, coordination, defect fixing, and
rework in task estimates where appropriate. Explain any material exclusions.

Do not automatically multiply every task estimate by every assigned role.
The task's effort is the combined effort of all contributors performing it,
unless the task is explicitly decomposed into separate role-specific tasks.

==================================================
7. TEAM AND RESOURCE PLANNING
=============================

Recommend the smallest practical team that can reasonably deliver the scope
with appropriate quality.

For each role, specify:

* The role's purpose.
* Main responsibilities.
* Reasonable headcount.
* Relevant rate assumptions, if defensible evidence is available.
* Source URLs supporting the rate assumptions, when available.

Consider which activities can be performed by the same person and which
require distinct expertise.

Avoid unnecessary staffing and unrealistic expectations that one contributor
can simultaneously perform all specialized responsibilities.

State reasonable assumptions about weekly working hours, availability,
holidays, onboarding, reviews, and non-project time in calculationNotes.

Do not assume every team member contributes at full capacity throughout
the entire project.

The team section is a role and staffing recommendation. Do not imply that
specific people have been hired or are available unless the input confirms it.

==================================================
8. COST ESTIMATION AND MARKET RATES
===================================

Use INR for India-based estimates unless another currency is explicitly
requested by the client.

Distinguish:

* Employee compensation and employer cost.
* Independent contractor or freelancer rates.
* Agency or consultancy billing rates.
* Fixed-price project quotations.
* Third-party and recurring operating expenses.

These pricing models are not interchangeable. Do not convert between them
without a justified and clearly disclosed assumption.

Only provide rate values when there is a defensible basis for the relevant
role and pricing model.

Use the supplied research to evaluate market-rate assumptions. Consider
geography, seniority, date, employment model, and source reliability.

Do not fabricate verified rates or present illustrative rates as researched
market facts.

If credible market-rate evidence is insufficient, do not invent or claim verified
market rates. You may still provide provisional fixed-price task estimates using task scope,
person-hour range, complexity, delivery responsibility, and explicitly disclosed assumptions.
Mark marketRateStatus as "unverified" or "partially_verified" where appropriate.

This response schema and application validation require a numeric priceMinINR and
priceMaxINR for every task. Provide a provisional fixed-price range based on the described
scope, effort, complexity, delivery responsibility, and explicit assumptions even when
market-rate evidence is incomplete; never describe such an estimate as market-verified
unless the supplied evidence supports that claim. If scope is too ambiguous for a responsible
range, ask a focused clarification question before generating the plan rather than emitting
null task prices.

Task prices are pre-contingency amounts. The application independently sums task prices and
applies contingencyPercent once. Do not silently include hosting, APIs, subscriptions,
licenses, maintenance, taxes, app-store fees, or other recurring costs; identify them as
included, excluded, or unknown in calculationNotes.

The project cost must be numeric and reconcile with the sum of task prices plus the
single application-calculated contingency. Do not confuse an unknown market rate with
an impossible project fixed-price estimate.

Do not silently include taxes, hosting, AI/API usage, subscriptions,
licenses, maintenance, app-store fees, domains, or third-party services.
Identify them as included, excluded, or unknown where relevant.

The contingencyPercent field is a planning assumption, not proof that
contingency has been applied correctly. Explain its treatment in
calculationNotes and ensure it is not applied twice.

AI-generated arithmetic is untrusted until independently recalculated
and validated by application code.

==================================================
9. CALENDAR TIMELINE AND CRITICAL PATH
======================================

Estimate elapsed calendar duration separately from total person-hours.

Account for:

* Task dependencies and blocking decisions.
* Work that can safely proceed in parallel.
* Actual team availability and role constraints.
* Technical uncertainty and external dependencies.
* Reviews, integration, testing, and defect resolution.
* Client feedback, approvals, and delivery readiness.
* Deployment preparation, release validation, and handover.
* Reasonable schedule contingency.

Do not calculate calendar duration by simply dividing total effort by
the number of team members.

Identify critical-path activities and decisions that may delay delivery.

Delivery-phase durations must be compatible with the proposed schedule.
Do not simply add every phase duration when phases are expected to overlap.
Explain material parallel-work assumptions.

Use wider timeline ranges when scope, staffing, integration, or client
availability is uncertain.

If a defensible timeline cannot be estimated, use null where supported
by the schema. If the schema requires numeric values, revise the schema
in application code before claiming that unknown timelines are represented
correctly.

==================================================
10. BUDGET AND DEADLINE FEASIBILITY
===================================

Compare the estimated project cost and timeline with actual client-provided
constraints.

Do not invent a budget, deadline, or client preference.

For budget feasibility:

* Compare the available budget with a defensible comparable cost estimate.
* If the budget or cost estimate is unavailable, use null.
* Do not declare the budget feasible solely because the client has not
  provided a budget.

For deadline feasibility:

* Compare the requested deadline with the estimated calendar timeline.
* If the deadline or defensible timeline is unavailable, use null.
* Explain major schedule dependencies and uncertainties.

If a constraint appears infeasible, explain why and propose realistic
alternatives, such as phased delivery, reduced optional scope, different
staffing, or a revised deadline.

Do not remove essential security, testing, or quality work merely to
fit a budget or deadline.

Clearly label alternatives as proposals requiring client approval.

==================================================
11. SECURITY, PRIVACY, QUALITY, AND OPERATIONS
==============================================

Assess relevant security and operational needs, including:

* Authentication and authorization.
* Input validation and secure error handling.
* Secrets management and access control.
* Protection of sensitive data.
* Appropriate encryption and logging.
* Data retention and deletion considerations.
* Backup, restoration, and disaster recovery.
* Performance, reliability, accessibility, and compatibility.
* Dependency and vulnerability management.
* Monitoring and production incident handling.

Include testing and remediation activities appropriate to the actual scope.

Identify regulatory or legal obligations requiring confirmation or expert
review. Do not claim compliance without adequate evidence.

Consider third-party rate limits, service availability, licenses, pricing
changes, API compatibility, credentials, and vendor lock-in where relevant.

Distinguish development completion from production readiness and launch.

Include documentation, deployment configuration, release validation,
rollback planning, and handover where applicable.

Do not assume that ongoing maintenance, warranty, hosting, source-code
transfer, or unlimited support is included unless the project input confirms it.

==================================================
12. RISK ANALYSIS AND UNCERTAINTY
=================================

Identify material risks involving:

* Scope ambiguity and changing requirements.
* Architecture and technology choices.
* External integrations and vendor dependencies.
* Security, privacy, and data quality.
* Staffing and delivery capacity.
* Budget, schedule, and market-rate uncertainty.
* Client approvals and unavailable inputs.
* Testing, release, and operational readiness.

For each risk, describe its likely impact and a practical mitigation.

Use only the supported impact values: low, medium, or high.

Do not invent probability statistics or claim that risks have been eliminated.

Separate known facts from assumptions and predictions.

Assess effort, cost, and timeline confidence separately in calculationNotes.
Explain why each confidence assessment is appropriate.

Use overallConfidence for the overall reliability of the plan, taking into
account requirements completeness, research quality, estimation uncertainty,
and unresolved dependencies.

==================================================
13. CLIENT QUESTIONS AND ACCEPTANCE
===================================

Ask concise, actionable clarification questions that could materially change
the solution, scope, effort, cost, security, or timeline.

Prioritize questions by decision impact. Avoid repeating information already
confirmed in the supplied input.

Identify the decisions required before a provisional estimate can become
a more reliable estimate.

Do not claim that the client approved scope, budget, timeline, architecture,
terms, or commercial conditions unless the input confirms explicit approval.

Do not treat viewing or generating an estimate as acceptance of a contract.

Do not invent legal terms, agreement dates, or approval records.

==================================================
14. REPLANNING AND CHANGE TRACEABILITY
======================================

When PLANNING MODE is "replan", treat CLIENT FEEDBACK as an explicit change
request that must be acted on, not merely summarized. Treat PREVIOUS PLAN as
the baseline for comparison and the original client input as context.

For every distinct request in clientFeedback:

* Identify the affected requirement, feature, module, task, deliverable,
  constraint, or assumption.
* Apply the requested change to the new plan when feasible and consistent
  with the client's stated intent.
* If a request is ambiguous, unsafe, technically infeasible, or conflicts
  with another confirmed requirement, do not silently ignore it. Explain the
  issue in clarificationQuestions, assumptions, risks, or constraintAssessment.
* If a request cannot fit the stated budget or deadline, propose a clearly
  labeled phased or reduced-scope alternative. Do not pretend the full scope
  fits when it does not.
* Keep unrelated confirmed requirements unless the client explicitly asks to
  remove or replace them.
* Re-estimate affected tasks, dependencies, testing, security, deployment,
  staffing, effort, cost, timeline, and operating costs. Do not just change
  the narrative while leaving the numbers and tasks unchanged.
* Recalculate project totals from the revised task breakdown. Preserve the
  meaning of the original plan fields and use null for unsupported cost data.
* Add a concise, specific before/after explanation to replanningChanges.
  Mention what was added, removed, reduced, deferred, or kept unchanged.
* If the client asks for alternatives, provide a recommended complete option
  and a budget-conscious core option where the schema can represent them;
  otherwise explain the limitation and list the deferred features.

A replan may be requested for feature/scope feedback even when no new budget
or deadline is provided. Do not require budgetMax or deadline to be present.

When mode is "initial", do not invent previous-plan comparisons or claim that
client feedback was applied.

Do not claim to preserve plan versions unless the application actually stores
them. Do not invent previous values or feedback.

If previous-plan data is unavailable, clearly state this limitation.

Do not silently treat a provisional estimate as a final commercial agreement.

==================================================
15. FAILURE HANDLING AND DATA INTEGRITY
=======================================

If research results are missing, disclose the limitation and continue
with a provisional plan when useful.

If project information is incomplete, identify the unknowns instead of
fabricating details.

Do not expose API keys, passwords, access tokens, private credentials,
or unrelated personal information.

Do not claim that research was completed, code was implemented, tests passed,
or deployment succeeded unless supported by actual evidence.

Return only data matching the required JSON structure. Do not add properties
outside the schema.

Do not silently convert unknown values into zero, guessed rates, or invented
dates. Use null for unknown values where the schema permits it.

If the required schema cannot represent an unknown value safely, identify
that as a limitation requiring an application-schema change.

==================================================
16. FINAL OUTPUT CONTRACT
=========================

Return ONLY valid JSON matching the exact schema below.

Do not include Markdown fences, introductory text, explanations outside
the JSON, or trailing commentary.

Use the exact field names and data types defined in the schema.

Use:

* JSON strings for textual values.
* JSON arrays for lists.
* JSON numbers for supported numeric values.
* JSON null for unavailable or unsupported values where permitted.
* Only the enumerated values for confidence, impact, and marketRateStatus.

Ensure all strings are valid JSON strings and all numeric values are valid
JSON numbers. Do not place explanatory text inside numeric fields.

Ensure:

* Minimum values never exceed maximum values.
* Task estimates reconcile with project effort totals.
* Cost assumptions and calculations are internally consistent.
* Contingency is not counted more than once.
* Timeline and delivery phases reflect realistic dependencies.
* Research URLs come only from supplied research results.
* Unknown information is not represented as confirmed fact.
* The final plan remains understandable to a client and actionable for
  a software development team.

REQUIRED JSON SCHEMA:

{
"projectSummary": "string",
"researchFindings": [
{
"finding": "string",
"sourceUrls": ["string"],
"confidence": "high | medium | low"
}
],
"confirmedRequirements": ["string"],
"assumptions": ["string"],
"clarificationQuestions": ["string"],
"recommendedArchitecture": {
"frontend": "string",
"backend": "string",
"database": "string",
"integrations": ["string"],
"reasoning": "string"
},
"modules": [
{
"name": "string",
"purpose": "string",
"tasks": [
{
"name": "string",
"description": "string",
"deliverable": "string",
"roles": ["string"],
"effortHoursMin": 1,
"effortHoursMax": 2,
"dependencies": ["string"],
"risks": ["string"],
"priceMinINR": 1000,
"priceMaxINR": 2000
}
]
}
],
"team": [
{
"role": "string",
"headcount": 1,
"responsibilities": ["string"],
"rateMinINRPerHour": null,
"rateMaxINRPerHour": null,
"rateEvidenceUrls": ["string"]
}
],
"estimate": {
"currency": "INR",
"effortHoursMin": 1,
"effortHoursMax": 2,
"costMinINR": 1000,
"costMaxINR": 2000,
"timelineMinWeeks": 1,
"timelineMaxWeeks": 2,
"contingencyPercent": 15,
"calculationNotes": ["string"],
"marketRateStatus": "verified | partially_verified | unverified"
},
"deliveryPhases": [
{
"name": "string",
"outcome": "string",
"durationWeeksMin": 1,
"durationWeeksMax": 2
}
],
"risks": [
{
"risk": "string",
"impact": "low | medium | high",
"mitigation": "string"
}
],
"optionalLaterFeatures": ["string"],
"constraintAssessment": {
"budgetFeasible": null,
"deadlineFeasible": null,
"explanation": "string",
"suggestedAdjustments": ["string"]
},
"replanningChanges": ["string"],
"overallConfidence": "low | medium | high"
}

The example numbers above illustrate the required numeric types; they are
not recommended estimates for the client's project.

Use JSON null when a cost or rate cannot be responsibly calculated.
Do not place Markdown fences around the JSON.
`;

      const planResponse = await ai.models.generateContent({
        model: "gemini-3.5-flash-lite",
        contents: planningPrompt,
        config: {
          responseMimeType: "application/json",
          temperature: 0.2,
          maxOutputTokens: 12000,
        },
      });

      
        const planText = extractGeneratedText(planResponse);

        console.log("AI PLAN RESPONSE LENGTH:", planText?.length);
        console.log(
          "AI PLAN FINISH REASON:",
          planResponse?.candidates?.[0]?.finishReason
        );
        console.log(
          "AI PLAN USAGE:",
          JSON.stringify(planResponse?.usageMetadata ?? {})
        );
        console.log(
          "AI PLAN RESPONSE START:",
          String(planText ?? "").slice(0, 300)
        );
        console.log(
          "AI PLAN RESPONSE END:",
          String(planText ?? "").slice(-500)
        );

        const plan = parseJsonObject(planText);

      /*
       * Save the result privately under the requesting user's UID.
       * This is a draft plan, not an approved quote or payment instruction.
       */
  // Validate the basic structure of the AI-generated plan.
  if (
    !plan ||
    typeof plan !== "object" ||
    Array.isArray(plan) ||
    !plan.projectSummary ||
    !plan.recommendedArchitecture ||
    !Array.isArray(plan.modules) ||
    !Array.isArray(plan.team) ||
    !plan.estimate ||
    !Array.isArray(plan.deliveryPhases) ||
    !Array.isArray(plan.risks) ||
    !plan.constraintAssessment
  ) {
    throw new HttpsError(
      "internal",
      "The AI generated an incomplete project plan. Please try again."
    );
  }

  // Validate project effort and timeline ranges.
  const {
    effortHoursMin,
    effortHoursMax,
    timelineMinWeeks,
    timelineMaxWeeks,
  } = plan.estimate;

  const validRange = (min, max) =>
    Number.isFinite(min) &&
    Number.isFinite(max) &&
    min >= 0 &&
    max >= min;

  if (
    !validRange(effortHoursMin, effortHoursMax) ||
    !validRange(timelineMinWeeks, timelineMaxWeeks)
  ) {
    throw new HttpsError(
      "internal",
      "The AI generated invalid effort or timeline estimates. Please try again."
    );
  }

  // Validate task effort and task-level fixed-price ranges.
  // Price ranges are pre-contingency; project totals are recalculated below.
  for (const module of plan.modules) {
    if (!module || !Array.isArray(module.tasks)) {
      throw new HttpsError(
        "internal",
        "The AI generated an invalid project module."
      );
    }

    for (const task of module.tasks) {
      if (
        !task ||
        !task.name ||
        !validRange(task.effortHoursMin, task.effortHoursMax) ||
        !validRange(task.priceMinINR, task.priceMaxINR) ||
        task.priceMaxINR <= 0
      ) {
        throw new HttpsError(
          "internal",
          "The AI generated an incomplete task estimate or task price. Please retry; if the problem persists, clarify the project scope."
        );
      }
    }
  }

  // Recalculate total effort from all task estimates.
  let calculatedEffortMin = 0;
  let calculatedEffortMax = 0;

  for (const module of plan.modules) {
    for (const task of module.tasks) {
      calculatedEffortMin += task.effortHoursMin;
      calculatedEffortMax += task.effortHoursMax;
    }
  }

  // Allow a small tolerance for numeric rounding.
  const effortTolerance = 0.01;

  
  if (
    Math.abs(calculatedEffortMin - plan.estimate.effortHoursMin) >
      effortTolerance ||
    Math.abs(calculatedEffortMax - plan.estimate.effortHoursMax) >
      effortTolerance
  ) {
    logger.warn("AI plan effort totals recalculated from task estimates.", {
      calculatedEffortMin,
      calculatedEffortMax,
      reportedEffortMin: plan.estimate.effortHoursMin,
      reportedEffortMax: plan.estimate.effortHoursMax,
    });
  }

  // Task-level estimates are the source of truth for effort and fixed-price.
  plan.estimate.effortHoursMin = calculatedEffortMin;
  plan.estimate.effortHoursMax = calculatedEffortMax;

  let taskPriceMinINR = 0;
  let taskPriceMaxINR = 0;
  for (const module of plan.modules) {
    for (const task of module.tasks) {
      taskPriceMinINR += task.priceMinINR;
      taskPriceMaxINR += task.priceMaxINR;
    }
  }

  // Apply contingency exactly once to the pre-contingency task-price totals.
  const rawContingency = plan.estimate.contingencyPercent;
  const requestedContingency =
    typeof rawContingency === "number"
      ? rawContingency
      : typeof rawContingency === "string" && rawContingency.trim() !== ""
        ? Number(rawContingency)
        : Number.NaN;
  const contingencyPercent =
    Number.isFinite(requestedContingency) &&
    requestedContingency >= 0 &&
    requestedContingency <= 50
      ? requestedContingency
      : 15;

  plan.estimate.contingencyPercent = contingencyPercent;
  plan.estimate.costMinINR = Math.round(
    taskPriceMinINR * (1 + contingencyPercent / 100)
  );
  plan.estimate.costMaxINR = Math.round(
    taskPriceMaxINR * (1 + contingencyPercent / 100)
  );
  plan.estimate.calculationNotes = Array.isArray(plan.estimate.calculationNotes)
    ? plan.estimate.calculationNotes
    : [];
  plan.estimate.calculationNotes.push(
    `Project fixed-price range is calculated by summing task price ranges (INR) and applying ${contingencyPercent}% contingency once. Task prices are provisional planning estimates; market-rate verification status is ${plan.estimate.marketRateStatus || "unverified"}.`
  );


      const planRef = db.collection("aiProjectPlans").doc();


      // Validate team roles and allow unknown market rates.
      for (const member of plan.team) {
        if (
          !member ||
          typeof member.role !== "string" ||
          !member.role.trim() ||
          !Number.isInteger(member.headcount) ||
          member.headcount < 1
        ) {
          throw new HttpsError(
            "internal",
            "The AI generated invalid team information. Please try again."
          );
        }

        const minRate = member.rateMinINRPerHour;
        const maxRate = member.rateMaxINRPerHour;

        const ratesAreUnknown =
          minRate === null && maxRate === null;

        const ratesAreValid =
          validRange(minRate, maxRate) &&
          maxRate > 0;

        if (!ratesAreUnknown && !ratesAreValid) {
          throw new HttpsError(
            "internal",
            "The AI generated invalid hourly rates. Please try again."
          );
        }
      }

      await planRef.set({
        planId: planRef.id,
        ownerUid: request.auth.uid,
        mode,
        projectInput,
        constraints,
        researchQueries: queries,
        sources,
        plan,
        status: "draft",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      logger.info("AI project research and plan generated", {
        planId: planRef.id,
        userId: request.auth.uid,
        mode,
        sourceCount: sources.length,
      });

      return {
        success: true,
        planId: planRef.id,
        mode,
        researchQueries: queries,
        sources,
        plan,
        status: "draft",
      };
    } catch (error) {
      logger.error("AI project research/planning failed", {
        userId: request.auth.uid,
        mode,
        errorName: error?.name,
        message: error?.message,
        stack: error?.stack,
        details: error?.details,
        cause: error?.cause?.message,
      });

      if (error instanceof HttpsError) throw error;

      throw new HttpsError(
        "internal",
        "Unable to research and plan this project. Please try again."
      );
    }
  }
);