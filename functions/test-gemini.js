require("dotenv").config();

const { GoogleGenAI } = require("@google/genai");

async function main() {
console.log("STEP 1: Starting test");

try {
console.log("STEP 2: Checking API key");
console.log("API key loaded:", Boolean(process.env.GEMINI_API_KEY));

console.log("STEP 3: Checking SDK");
console.log("GoogleGenAI type:", typeof GoogleGenAI);

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

console.log("STEP 4: SDK initialized");
console.log("generateContent type:", typeof ai.models.generateContent);

console.log("STEP 5: Sending request");

const response = await ai.models.generateContent({
  model: "gemini-3.5-flash-lite",
  contents: "Reply with exactly: AI working",
});

console.log("STEP 6: Request succeeded");
console.log("Response:", response.text);

} catch (error) {
console.error("FAILED:", error);
console.error("STACK:", error.stack);
}
}

main().catch(console.error);
