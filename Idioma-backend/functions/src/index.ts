/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */
import axios from "axios";
import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({path: path.join(__dirname, "../../.env"), debug: true}); // Use absolute path resolution with debug

// Debug logging
console.log("Raw NEWS_API_KEY from process.env:", process.env.NEWS_API_KEY);
console.log("All env vars starting with NEWS:", Object.keys(process.env).filter(key => key.startsWith('NEWS')));

const newsAPIKey = process.env.NEWS_API_KEY;
logger.info("Loaded NEWS_API_KEY:", newsAPIKey ? "[SET]" : "[NOT SET]");
// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

export const helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase!");
});

export const anotherFunction = onRequest((request, response) => {
  logger.info("Another function logs!", {structuredData: true});
  response.send("Hello from another Firebase function!");
});

export const checkCache = onRequest(async (request, response) => {
  logger.info("Checking cache");
  
});

export const getNews = onRequest(async (request, response) => {
  logger.info("Fetching news with parameters:", {
    country: request.query.country,
    language: request.query.language,
  });
  logger.info("Loaded NEWS_API_KEY:", newsAPIKey ? "[SET]" : "[NOT SET]");


  try {
    // Get country and language from query parameters
    const country = request.query.country as string;
    const language = request.query.language as string;

    if (!country && !language) {
      response.status(400).json({
        error: "Both 'country' and 'language' parameters are required"
      });
      return;
    }

    if (!newsAPIKey) {
      response.status(500).json({
        error: "API key not configured"
      });
      return;
    }

    // Make request to newsdata.io API
    const apiResponse = await axios.get("https://newsdata.io/api/1/news", {
      params: {
        apikey: newsAPIKey,
        country: country,
        language: language,
      }
    });

    logger.info(`News fetched for country: ${country}, language: ${language}`);
    response.json(apiResponse.data);

  } catch (error) {
    logger.error("Error fetching news:", error);
    response.status(500).json({
      error: "Failed to fetch news",
      details: error instanceof Error ? error.message : "Unknown error"
    });
  }
});
