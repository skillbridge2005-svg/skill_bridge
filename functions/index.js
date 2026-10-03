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

setGlobalOptions({
  maxInstances: 10,
});

initializeApp();

const db = getFirestore();

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

/*
|--------------------------------------------------------------------------
| Helper: Get Project Payment Amount
|--------------------------------------------------------------------------
|
| The payment amount is controlled by Firestore instead of trusting
| the amount sent from Flutter.
|
| Supported fields:
|   1. budget
|   2. amount
|   3. projectAmount
|
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
  /*
   * Check Firebase authentication
   */
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to create a payment order."
    );
  }

  const { projectId } = request.data || {};

  /*
   * Validate project ID
   */
  if (!projectId || typeof projectId !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "A valid project ID is required."
    );
  }

  const clientId = request.auth.uid;

  try {
    /*
     * Get project from Firestore
     */
    const projectReference = db
      .collection("projects")
      .doc(projectId);

    const projectSnapshot =
      await projectReference.get();

    /*
     * Check project exists
     */
    if (!projectSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "The SkillBridge project was not found."
      );
    }

    const projectData =
      projectSnapshot.data();

    /*
     * Check project belongs to logged-in client
     */
    if (projectData.clientId !== clientId) {
      throw new HttpsError(
        "permission-denied",
        "You are not authorized to make a payment for this project."
      );
    }

    /*
     * Get payment amount from Firestore
     */
    const projectAmount =
      getProjectAmount(projectData);

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

    /*
     * Convert rupees to paise
     */
    const amountInPaise =
      Math.round(projectAmount * 100);

    if (
      !Number.isSafeInteger(amountInPaise) ||
      amountInPaise <= 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The project payment amount is invalid."
      );
    }

    /*
     * Check whether project is already paid
     */
    if (projectData.paymentStatus === "paid") {
      throw new HttpsError(
        "failed-precondition",
        "This project has already been paid."
      );
    }

    /*
     * Create Razorpay order
     */
    const order =
      await razorpay.orders.create({
        amount: amountInPaise,
        currency: "INR",

        receipt:
          `skillbridge_${projectId}_${Date.now()}`,

        notes: {
          projectId: projectId,
          clientId: clientId,
        },
      });

    logger.info(
      "Razorpay order created",
      {
        orderId: order.id,
        projectId: projectId,
        clientId: clientId,
        amount: projectAmount,
      }
    );

    return {
      success: true,
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: process.env.RAZORPAY_KEY_ID,
    };
  } catch (error) {
    logger.error(
      "Razorpay order creation failed",
      error
    );

    /*
     * Preserve intentional Firebase errors
     */
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

exports.verifyRazorpayPayment = onCall(
  async (request) => {
    /*
     * Check Firebase authentication
     */
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in to verify a payment."
      );
    }

    /*
     * Read payment information
     */
    const {
      razorpayOrderId,
      razorpayPaymentId,
      razorpaySignature,
    } = request.data || {};

    /*
     * Validate input
     */
    if (
      typeof razorpayOrderId !== "string" ||
      !razorpayOrderId ||

      typeof razorpayPaymentId !== "string" ||
      !razorpayPaymentId ||

      typeof razorpaySignature !== "string" ||
      !/^[a-fA-F0-9]{64}$/.test(
        razorpaySignature
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Payment verification data is incomplete."
      );
    }

    const clientId =
      request.auth.uid;

    const paymentReference = db
      .collection("payments")
      .doc(razorpayPaymentId);

    try {
      /*
       * Make sure Razorpay secret exists
       */
      const keySecret =
        process.env.RAZORPAY_KEY_SECRET;

      if (!keySecret) {
        throw new HttpsError(
          "internal",
          "Payment verification is not configured."
        );
      }

      /*
       * ---------------------------------------------------------------
       * 1. Verify Razorpay signature
       * ---------------------------------------------------------------
       */

      const generatedSignature =
        crypto
          .createHmac(
            "sha256",
            keySecret
          )
          .update(
            `${razorpayOrderId}|${razorpayPaymentId}`
          )
          .digest("hex");

      const isValid =
        crypto.timingSafeEqual(
          Buffer.from(
            generatedSignature,
            "hex"
          ),
          Buffer.from(
            razorpaySignature,
            "hex"
          )
        );

      if (!isValid) {
        logger.warn(
          "Invalid Razorpay payment signature",
          {
            orderId: razorpayOrderId,
            paymentId:
              razorpayPaymentId,
            userId: clientId,
          }
        );

        throw new HttpsError(
          "permission-denied",
          "Payment verification failed."
        );
      }

      /*
       * ---------------------------------------------------------------
       * 2. Check duplicate payment
       * ---------------------------------------------------------------
       */

      const existingPayment =
        await paymentReference.get();

      if (existingPayment.exists) {
        const existingData =
          existingPayment.data();

        const matchesVerifiedPayment =
          existingData.paymentId ===
            razorpayPaymentId &&

          existingData.orderId ===
            razorpayOrderId &&

          existingData.clientId ===
            clientId &&

          existingData.status ===
            "verified" &&

          typeof existingData.projectId ===
            "string";

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
          paymentId:
            razorpayPaymentId,
          orderId:
            razorpayOrderId,
          projectId:
            existingData.projectId,
        };
      }

      /*
       * ---------------------------------------------------------------
       * 3. Fetch Razorpay order
       * ---------------------------------------------------------------
       */

      const order =
        await razorpay.orders.fetch(
          razorpayOrderId
        );

      /*
       * ---------------------------------------------------------------
       * 4. Check order ownership
       * ---------------------------------------------------------------
       */

      if (
        !order.notes ||
        order.notes.clientId !== clientId
      ) {
        logger.warn(
          "Razorpay order does not belong to caller",
          {
            orderId:
              razorpayOrderId,
            userId: clientId,
          }
        );

        throw new HttpsError(
          "permission-denied",
          "This payment order does not belong to you."
        );
      }

      /*
       * ---------------------------------------------------------------
       * 5. Get project ID from Razorpay order
       * ---------------------------------------------------------------
       */

      const projectId =
        order.notes.projectId;

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
       * ---------------------------------------------------------------
       * 6. Validate order amount and currency
       * ---------------------------------------------------------------
       */

      if (
        !Number.isSafeInteger(
          order.amount
        ) ||
        order.amount <= 0 ||
        order.currency !== "INR"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The payment order has an invalid amount or currency."
        );
      }

      /*
       * ---------------------------------------------------------------
       * 7. Fetch actual Razorpay payment
       * ---------------------------------------------------------------
       */

      const payment =
        await razorpay.payments.fetch(
          razorpayPaymentId
        );

      /*
       * ---------------------------------------------------------------
       * 8. Verify payment belongs to order
       * ---------------------------------------------------------------
       */

      if (
        payment.order_id !==
        razorpayOrderId
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Payment does not belong to the specified order."
        );
      }

      /*
       * ---------------------------------------------------------------
       * 9. Verify payment is captured
       * ---------------------------------------------------------------
       */

      if (
        payment.status !==
        "captured"
      ) {
        throw new HttpsError(
          "failed-precondition",
          `Payment is not captured. Current status: ${payment.status}`
        );
      }

      /*
       * ---------------------------------------------------------------
       * 10. Verify payment amount
       * ---------------------------------------------------------------
       */

      if (
        payment.amount !==
        order.amount
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Payment amount does not match the order amount."
        );
      }

      /*
       * ---------------------------------------------------------------
       * 11. Verify currency
       * ---------------------------------------------------------------
       */

      if (
        payment.currency !==
        order.currency
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Payment currency does not match the order currency."
        );
      }

      /*
       * Convert paise to rupees
       */
      const verifiedAmount =
        order.amount / 100;

      /*
       * ---------------------------------------------------------------
       * 12. Get project
       * ---------------------------------------------------------------
       */

      const projectReference =
        db.collection("projects")
          .doc(projectId);

      /*
       * ---------------------------------------------------------------
       * 13. Atomic Firestore transaction
       * ---------------------------------------------------------------
       */

      await db.runTransaction(
        async (transaction) => {
          const [
            existingPayment,
            projectSnapshot,
          ] = await Promise.all([
            transaction.get(
              paymentReference
            ),

            transaction.get(
              projectReference
            ),
          ]);

          /*
           * Project must exist
           */
          if (!projectSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "The SkillBridge project was not found."
            );
          }

          const projectData =
            projectSnapshot.data();

          /*
           * Project must belong to client
           */
          if (
            projectData.clientId !==
            clientId
          ) {
            throw new HttpsError(
              "permission-denied",
              "You are not authorized to pay for this project."
            );
          }

          /*
           * Check the project's actual amount
           */
          const projectAmount =
            getProjectAmount(
              projectData
            );

          if (
            projectAmount === null
          ) {
            throw new HttpsError(
              "failed-precondition",
              "The project does not have a valid payment amount."
            );
          }

          const expectedAmountInPaise =
            Math.round(
              projectAmount * 100
            );

          /*
           * Payment must equal project amount
           */
          if (
            expectedAmountInPaise !==
            order.amount
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Payment amount does not match the project amount."
            );
          }

          /*
           * Check duplicate payment
           */
          if (existingPayment.exists) {
            const existingData =
              existingPayment.data();

            const matchesVerifiedPayment =
              existingData.paymentId ===
                razorpayPaymentId &&

              existingData.orderId ===
                razorpayOrderId &&

              existingData.projectId ===
                projectId &&

              existingData.clientId ===
                clientId &&

              existingData.amount ===
                verifiedAmount &&

              existingData.amountInPaise ===
                order.amount &&

              existingData.currency ===
                order.currency &&

              existingData.status ===
                "verified";

            if (
              !matchesVerifiedPayment
            ) {
              throw new HttpsError(
                "already-exists",
                "A conflicting payment record already exists."
              );
            }
          } else {
            /*
             * Create payment record
             */
            transaction.create(
              paymentReference,
              {
                paymentId:
                  razorpayPaymentId,

                orderId:
                  razorpayOrderId,

                projectId:
                  projectId,

                clientId:
                  clientId,

                amount:
                  verifiedAmount,

                amountInPaise:
                  order.amount,

                currency:
                  order.currency,

                status:
                  "verified",

                createdAt:
                  FieldValue.serverTimestamp(),
              }
            );
          }

          /*
           * Mark project as paid
           */
          if (
            projectData.paymentStatus !==
            "paid"
          ) {
            transaction.update(
              projectReference,
              {
                paymentStatus:
                  "paid",

                paymentId:
                  razorpayPaymentId,

                paidAmount:
                  verifiedAmount,

                paidAt:
                  FieldValue.serverTimestamp(),
              }
            );
          }
        }
      );

      /*
       * ---------------------------------------------------------------
       * Payment successfully verified
       * ---------------------------------------------------------------
       */

      logger.info(
        "Payment verified and saved",
        {
          paymentId:
            razorpayPaymentId,

          orderId:
            razorpayOrderId,

          projectId:
            projectId,

          clientId:
            clientId,

          amount:
            verifiedAmount,
        }
      );

      return {
        success: true,
        verified: true,

        paymentId:
          razorpayPaymentId,

        orderId:
          razorpayOrderId,

        projectId:
          projectId,

        amount:
          verifiedAmount,

        currency:
          order.currency,
      };
    } catch (error) {
      logger.error(
        "Payment verification failed",
        error
      );

      /*
       * Preserve Firebase errors
       */
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Unable to verify and save payment."
      );
    }
  }
);