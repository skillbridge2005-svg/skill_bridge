require("dotenv").config();

async function testCloudflareAI() {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
  const apiToken = process.env.CLOUDFLARE_API_TOKEN;

  if (!accountId || !apiToken) {
    console.error(
        "Missing CLOUDFLARE_ACCOUNT_ID or CLOUDFLARE_API_TOKEN in functions/.env",
    );
    process.exitCode = 1;
    return;
  }

  const url =
    `https://api.cloudflare.com/client/v4/accounts/` +
    `${accountId}/ai/run/@cf/black-forest-labs/flux-1-schnell`;

  console.log("Testing Cloudflare Workers AI...");

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        prompt:
          "A polished modern software dashboard UI, " +
          "clean white background, indigo accents, " +
          "professional layout, one complete screen.",
        steps: 4,
      }),
    });

    const contentType = response.headers.get("content-type") || "";

    if (!response.ok) {
      const details = (await response.text()).slice(0, 1200);

      console.error("Cloudflare request failed.");
      console.error("HTTP status:", response.status);
      console.error("Provider details:", details);
      process.exitCode = 1;
      return;
    }

    if (contentType.includes("application/json")) {
      const body = await response.json();
      const image = body?.result?.image ?? body?.image;

      if (body?.success === false || typeof image !== "string") {
        console.error("Request completed but no image was returned.");
        console.error(JSON.stringify(body?.errors ?? body).slice(0, 1200));
        process.exitCode = 1;
        return;
      }

      console.log("SUCCESS: Cloudflare generated an image!");
      console.log("Image data length:", image.length);
      console.log("Content type:", contentType);
      return;
    }

    if (contentType.startsWith("image/")) {
      const image = await response.arrayBuffer();
      console.log("SUCCESS: Cloudflare generated an image!");
      console.log("Image size:", image.byteLength, "bytes");
      console.log("Content type:", contentType);
      return;
    }

    console.error("Unexpected response content type:", contentType);
    process.exitCode = 1;
  } catch (error) {
    console.error("Connection test failed:", error.message);
    process.exitCode = 1;
  }
}

testCloudflareAI();