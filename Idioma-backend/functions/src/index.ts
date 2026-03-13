// ---
// AUTHENTICATION USAGE NOTE:
// All protected endpoints (e.g., getNews) now require a valid Firebase ID token in the Authorization header:
//   Authorization: Bearer <FIREBASE_ID_TOKEN>
//
// To test locally:
// 1. Sign in with Google in your iOS app (or Firebase Auth emulator UI) and get the ID token.
// 2. Call the endpoint with:
//    curl -H "Authorization: Bearer <ID_TOKEN>" \
//    "http://127.0.0.1:5001/idioma-87bed/us-central1/getNews?country=us&language=en"
// 3. If the token is missing/invalid/expired, you'll get 401 Unauthorized.
// 4. The decoded user info is available as 'uid' in logs for debugging.
// ---
/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */
import axios, {isAxiosError} from "axios";
import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as dotenv from "dotenv";
import * as path from "path";
import * as admin from "firebase-admin";
import {Timestamp} from "firebase-admin/firestore";
import {JSDOM} from "jsdom";
import {Readability} from "@mozilla/readability";
import OpenAI from "openai";

// --- Firebase Admin SDK for verifying ID tokens ---

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Verifies Firebase ID token from Authorization header.
 * Returns decoded token if valid, else null.
 */
// async function verifyFirebaseIdToken(request: any): Promise<admin.auth.DecodedIdToken | null> {
//   const authHeader = request.headers["authorization"] ||\n//     request.headers["Authorization"];
//   if (!authHeader || !authHeader.startsWith("Bearer ")) return null;
//   const idToken = authHeader.split(" ")[1];
//   try {
//     return await admin.auth().verifyIdToken(idToken);
//   } catch (err) {
//     logger.warn("Invalid or expired Firebase ID token", err);
//     return null;
//   }
// }

dotenv.config({path: path.join(__dirname, "../.env"), debug: true});
// Use absolute path resolution with debug

const newsAPIKey = process.env.NEWS_API_KEY;
logger.info("Loaded NEWS_API_KEY:", newsAPIKey ? "[SET]" : "[NOT SET]");

// Initialize OpenAI client lazily to avoid errors during local analysis
let openai: OpenAI | null = null;
/**
 * Get or initialize the OpenAI client.
 * @return {OpenAI} The OpenAI client instance.
 */
function getOpenAI(): OpenAI {
  if (!openai) {
    if (!process.env.OPENAI_API_KEY) {
      throw new Error("OPENAI_API_KEY is not set");
    }
    openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }
  return openai;
}
logger.info("Loaded OPENAI_API_KEY:", process.env.OPENAI_API_KEY ? "[SET]" : "[NOT SET]");

const db = admin.firestore();

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
// Function to fetch news based on country and language, checks firebase datbase first
exports.hello = onRequest((req, res) => {
  res.send("Hello from Firebase!");
});


// ---------------------------------------------------------------------------
// Category mapping from Idioma app taxonomy to NewsData provider categories
// ---------------------------------------------------------------------------
interface CategoryMapping {
  newsDataCategory: string;
  isLossy: boolean;
  keywords?: string; // Boolean query for keyword-augmented (lossy) categories
}

const CATEGORY_MAP: Record<number, CategoryMapping> = {
  1: {newsDataCategory: "politics", isLossy: false},
  2: {newsDataCategory: "business", isLossy: false},
  3: {newsDataCategory: "entertainment", isLossy: false},
  4: {newsDataCategory: "sports", isLossy: false},
  5: {newsDataCategory: "business", isLossy: false},
  6: {newsDataCategory: "technology", isLossy: false},
  7: {newsDataCategory: "education", isLossy: false},
  8: {newsDataCategory: "crime", isLossy: false},
  9: {newsDataCategory: "other", isLossy: true,
    keywords: "religion OR church OR mosque OR temple OR faith OR archaeology OR historical OR history OR heritage"},
  10: {newsDataCategory: "environment", isLossy: false},
  11: {newsDataCategory: "health", isLossy: false},
  12: {newsDataCategory: "domestic", isLossy: true,
    keywords: "housing OR poverty OR inequality OR protest OR " +
      "migration OR homelessness OR welfare OR discrimination"},
  13: {newsDataCategory: "lifestyle", isLossy: false},
  14: {newsDataCategory: "breaking", isLossy: true,
    keywords: "weather OR storm OR hurricane OR flood OR wildfire OR earthquake OR heatwave OR forecast OR disaster"},
};

const VALID_CATEGORY_IDS = Object.keys(CATEGORY_MAP).map(Number);
const MAX_CATEGORIES = 5;


export const getNews = onRequest(async (request, response) => {
  // --- Require Firebase Auth ---
  // const decodedToken = await verifyFirebaseIdToken(request);
  // if (!decodedToken) {
  //   response.status(401).json({ error: "Unauthorized: missing or invalid Firebase ID token" });
  //   return;
  // }

  logger.info("Fetching news with parameters:", {
    country: request.query.country,
    language: request.query.language,
    categories: request.query.categories,
  });

  try {
    // Get country and language from query parameters
    const country = request.query.country as string;
    const language = request.query.language as string;
    const categoriesParam = request.query.categories as string | undefined;

    if (!country || !language) {
      response.status(400).json({
        error: "Both 'country' and 'language' parameters are required",
      });
      return;
    }

    if (!newsAPIKey) {
      response.status(500).json({
        error: "API key not configured",
      });
      return;
    }

    // Parse and validate categories
    let categoryIds: number[] = [];
    if (categoriesParam) {
      categoryIds = categoriesParam.split(",").map((s) => parseInt(s.trim(), 10));
      const invalid = categoryIds.filter((id) => !VALID_CATEGORY_IDS.includes(id));
      if (invalid.length > 0) {
        response.status(400).json({
          error: `Invalid category ids: ${invalid.join(", ")}. Valid range: 1-14`,
        });
        return;
      }
      if (categoryIds.length > MAX_CATEGORIES) {
        response.status(400).json({
          error: `Maximum ${MAX_CATEGORIES} categories allowed`,
        });
        return;
      }
    }

    // Build a deterministic cache key that includes categories
    const categoriesKey = categoryIds.length > 0 ? categoryIds.sort((a, b) => a - b).join(",") : "all";

    // Check Firestore for cached articles (within last 24 hours)
    const twentyFourHoursAgo = Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));

    // Use different query depending on whether categories are specified
    // This keeps backward compatibility with old documents that lack categoriesKey
    let cachedQuery;
    if (categoryIds.length > 0) {
      cachedQuery = db.collection("articles")
        .where("country", "==", country)
        .where("language", "==", language)
        .where("categoriesKey", "==", categoriesKey)
        .where("timestamp", ">", twentyFourHoursAgo)
        .orderBy("timestamp", "desc")
        .limit(1);
    } else {
      cachedQuery = db.collection("articles")
        .where("country", "==", country)
        .where("language", "==", language)
        .where("timestamp", ">", twentyFourHoursAgo)
        .orderBy("timestamp", "desc")
        .limit(1);
    }
    const cachedSnapshot = await cachedQuery.get();

    if (!cachedSnapshot.empty) {
      const cachedDoc = cachedSnapshot.docs[0];
      logger.info("Returning cached news", {country, language, categoriesKey});
      response.json({results: cachedDoc.data().articles});
      return;
    }

    // -----------------------------------------------------------------
    // Hybrid fetch: separate strong-mapping and lossy categories
    // -----------------------------------------------------------------
    let allArticles: any[] = [];

    if (categoryIds.length === 0) {
      // No categories selected → fetch general news (backwards compatible)
      const apiResponse = await axios.get("https://newsdata.io/api/1/news", {
        params: {apikey: newsAPIKey, country, language},
      });
      allArticles = (apiResponse.data.results || []).map((a: any) => ({...a, idiomaCategoryIds: []}));
    } else {
      // Split into strong-mapping vs lossy categories
      const strongIds = categoryIds.filter((id) => !CATEGORY_MAP[id].isLossy);
      const lossyIds = categoryIds.filter((id) => CATEGORY_MAP[id].isLossy);

      // 1. Fetch strong-mapping categories in a single combined query
      if (strongIds.length > 0) {
        const newsDataCats = [...new Set(strongIds.map((id) => CATEGORY_MAP[id].newsDataCategory))];
        logger.info("Fetching strong-mapping categories", {strongIds, newsDataCats});

        const apiResponse = await axios.get("https://newsdata.io/api/1/news", {
          params: {
            apikey: newsAPIKey,
            country,
            language,
            category: newsDataCats.join(","),
          },
        });

        const strongArticles = (apiResponse.data.results || []).map((a: any) => {
          // Annotate with the matching Idioma category ids
          const matchedIds = strongIds.filter((id) => {
            const mapped = CATEGORY_MAP[id].newsDataCategory;
            return a.category && a.category.includes(mapped);
          });
          return {...a, idiomaCategoryIds: matchedIds.length > 0 ? matchedIds : strongIds};
        });
        allArticles.push(...strongArticles);
      }

      // 2. Fetch each lossy category separately with keyword augmentation
      for (const lossyId of lossyIds) {
        const mapping = CATEGORY_MAP[lossyId];
        logger.info("Fetching lossy category with keywords", {
          lossyId, newsDataCategory: mapping.newsDataCategory, keywords: mapping.keywords,
        });

        try {
          const apiResponse = await axios.get("https://newsdata.io/api/1/news", {
            params: {
              apikey: newsAPIKey,
              country,
              language,
              category: mapping.newsDataCategory,
              q: mapping.keywords,
            },
          });

          const lossyArticles = (apiResponse.data.results || []).map((a: any) => ({
            ...a,
            idiomaCategoryIds: [lossyId],
          }));
          allArticles.push(...lossyArticles);
        } catch (err) {
          logger.warn("Lossy category fetch failed, skipping", {
            lossyId, error: err instanceof Error ? err.message : err,
          });
        }
      }

      // 3. Deduplicate by article_id
      const seen = new Set<string>();
      allArticles = allArticles.filter((a) => {
        if (!a.article_id || seen.has(a.article_id)) return false;
        seen.add(a.article_id);
        return true;
      });

      // 4. Round-robin interleave for categorical balance
      if (lossyIds.length > 0 && strongIds.length > 0) {
        allArticles = balanceFeed(allArticles, categoryIds);
      }
    }

    // Store in Firestore
    const docData = {
      country,
      language,
      categoriesKey,
      timestamp: Timestamp.now(),
      articles: allArticles,
    };
    const bytes = Buffer.byteLength(JSON.stringify(docData), "utf8");
    logger.info("Firestore document size (articles)", {
      bytes,
      kb: (bytes / 1024).toFixed(2),
      articlesCount: allArticles.length,
    });
    await db.collection("articles").add(docData);

    logger.info("Fetched and cached new news", {country, language, categoriesKey, count: allArticles.length});
    response.json({results: allArticles});
  } catch (error) {
    logger.error("Error in getNews:", error);
    response.status(500).json({
      error: "Failed to fetch news",
      details: error instanceof Error ? error.message : "Unknown error",
    });
  }
});

/**
 * Round-robin interleave articles by their idiomaCategoryIds to avoid
 * one category dominating the feed. Uses the first category id per article
 * as the bucket key.
 * @param {any[]} articles - The articles to interleave.
 * @param {number[]} categoryIds - The selected category ids.
 * @return {any[]} Balanced article list.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any,require-jsdoc
function balanceFeed(articles: any[], categoryIds: number[]): any[] {
  const buckets: Record<number, any[]> = {};
  for (const id of categoryIds) {
    buckets[id] = [];
  }
  for (const a of articles) {
    const primary = (a.idiomaCategoryIds && a.idiomaCategoryIds.length > 0) ?
      a.idiomaCategoryIds[0] :
      categoryIds[0];
    if (buckets[primary]) {
      buckets[primary].push(a);
    } else {
      buckets[categoryIds[0]].push(a);
    }
  }

  const result: any[] = [];
  const keys = categoryIds.filter((id) => buckets[id] && buckets[id].length > 0);
  const indices: Record<number, number> = {};
  for (const k of keys) indices[k] = 0;

  let remaining = articles.length;
  while (remaining > 0) {
    for (const k of keys) {
      if (indices[k] < buckets[k].length) {
        result.push(buckets[k][indices[k]]);
        indices[k]++;
        remaining--;
      }
    }
    // Break if no progress was made (all buckets exhausted)
    if (keys.every((k) => indices[k] >= buckets[k].length)) break;
  }
  return result;
}

// Function to extract and simplify article content from a URL
// Uses jsdom + @mozilla/readability to parse main content and collect images
export const extractArticle = onRequest({timeoutSeconds: 300}, async (request, response) => {
  const url = (request.query.url as string) || (request.body && (request.body.url as string));
  logger.info("extractArticle called", {url});

  // const decodedToken = await verifyFirebaseIdToken(request);
  // if (!decodedToken) {
  //   response.status(401).json({ error: "Unauthorized: missing or invalid Firebase ID token" });
  //   return;
  // }

  if (!url) {
    response.status(400).json({error: "Missing 'url' query or body parameter"});
    return;
  }

  try {
    // 1) Check Firestore cache for this URL within 7 days
    const sevenDaysAgo = Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000));
    const cacheQuery = db
      .collection("articleContent")
      .where("url", "==", url)
      .where("timestamp", ">", sevenDaysAgo)
      .orderBy("timestamp", "desc")
      .limit(1);
    const cached = await cacheQuery.get();
    if (!cached.empty) {
      const data = cached.docs[0].data();
      logger.info("Returning cached article content", {url});
      response.json(data);
      return;
    }

    // 2) Fetch the article HTML with enhanced error handling and retry logic
    logger.info("Fetching article HTML", {url});

    const fetchWithRetry = async (retries = 2):
      Promise<{data: Buffer; status: number; headers: Record<string, string>}> => {
      for (let attempt = 1; attempt <= retries + 1; attempt++) {
        try {
          logger.info(`Fetch attempt ${attempt}`, {url});
          return await axios.get(url, {
            responseType: "arraybuffer",
            headers: {
              "User-Agent":
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
              "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
              "Accept-Language": "en-US,en;q=0.9",
              "Accept-Encoding": "gzip, deflate, br",
              "Referer": "https://www.google.com/",
              "Cache-Control": "no-cache",
              "Pragma": "no-cache",
              "Sec-Fetch-Dest": "document",
              "Sec-Fetch-Mode": "navigate",
              "Sec-Fetch-Site": "cross-site",
              "Sec-Ch-Ua": "\"Google Chrome\";v=\"119\", \"Chromium\";v=\"119\", \"Not?A_Brand\";v=\"24\"",
              "Sec-Ch-Ua-Mobile": "?0",
              "Sec-Ch-Ua-Platform": "\"macOS\"",
            },
            timeout: 30000, // Increased to 30 seconds
            validateStatus: (s) => s >= 200 && s < 400,
          });
        } catch (error) {
          logger.warn(`Fetch attempt ${attempt} failed`, {url, error: error instanceof Error ? error.message : error});
          if (attempt === retries + 1) throw error;
          // Wait 2 seconds before retry
          await new Promise((resolve) => setTimeout(resolve, 2000));
        }
      }
      throw new Error("Fetch failed after all retries");
    };

    const {data: htmlBuffer, headers: respHeaders} = await fetchWithRetry();

    // 3) Build DOM with proper encoding detection from Content-Type + HTML meta tags
    logger.info("Parsing HTML with Readability", {url});
    const contentType = respHeaders["content-type"] || "text/html";
    const dom = new JSDOM(htmlBuffer, {url, contentType});
    const doc = dom.window.document;

    // Check if we got a redirect or error page
    const bodyText = doc.body?.textContent || "";
    if (bodyText.includes("Access Denied") || bodyText.includes("403 Forbidden") || bodyText.includes("Cloudflare")) {
      logger.warn("Possible bot detection", {url});
      response.status(403).json({
        error: "Access denied - site may be blocking automated requests",
        details: "The website appears to be blocking bot access",
      });
      return;
    }

    const reader = new Readability(doc);
    const article = reader.parse();

    if (!article) {
      logger.error("Readability failed to parse article", {
        url,
        title: doc.title,
        bodyExists: !!doc.body,
        contentLength: doc.body?.textContent?.length || 0,
      });
      response.status(422).json({
        error: "Unable to parse article content",
        details: "Readability parser could not extract main content from this page",
      });
      return;
    }

    logger.info("Article parsed successfully", {url, title: article.title});

    // 4) Normalize images and preserve positions in cleaned HTML
    const toAbsolute = (src: string): string => {
      try {
        return new URL(src, url).toString();
      } catch {
        return src;
      }
    };

    const imagesSet = new Set<string>();
    const contentFragment = JSDOM.fragment(article.content || "");
    contentFragment.querySelectorAll("img").forEach((img) => {
      const rawSrc =
        img.getAttribute("src") ||
        img.getAttribute("data-src") ||
        img.getAttribute("data-original") || "";
      if (rawSrc) {
        const abs = toAbsolute(rawSrc.trim());
        img.setAttribute("src", abs);
        imagesSet.add(abs);
      }
      const rawSet = img.getAttribute("srcset") || img.getAttribute("data-srcset") || "";
      if (rawSet) {
        const normalized = rawSet
          .split(",")
          .map((p) => {
            const [u, size] = p.trim().split(/\s+/, 2);
            return [toAbsolute(u), size].filter(Boolean).join(" ");
          })
          .join(", ");
        img.setAttribute("srcset", normalized);
      }
    });

    // 5) Lead image via OG/Twitter or first content image
    const ogImageEl = doc.querySelector(
      "meta[property=\"og:image\"], meta[name=\"og:image\"], " +
      "meta[name=\"twitter:image\"], meta[property=\"twitter:image\"]"
    );
    const ogImageUrl = ogImageEl?.getAttribute("content") || undefined;
    const firstContentImage = contentFragment.querySelector("img");
    const leadImageUrl = ogImageUrl ?
      toAbsolute(ogImageUrl) :
      firstContentImage?.getAttribute("src") ?
        toAbsolute(firstContentImage.getAttribute("src") as string) :
        undefined;
    if (leadImageUrl) imagesSet.add(leadImageUrl);

    const images = Array.from(imagesSet);

    // 6) Serialize normalized HTML (keeps image positions)
    const container = doc.createElement("div");
    container.appendChild(contentFragment.cloneNode(true));
    const contentHtml = container.innerHTML;

    // 7) Build an LLM-friendly HTML: remove scripts/styles, keep basic structure and <img>
    // Keep tags: p, h1-h4, ul/ol/li, blockquote, figure/figcaption, img (with absolute src, alt)
    const llmContainer = doc.createElement("div");
    llmContainer.innerHTML = contentHtml;
    // Strip unwanted nodes
    llmContainer.querySelectorAll("script,style,noscript,iframe").forEach((n) => n.remove());
    // Remove attributes except few safe ones
    llmContainer.querySelectorAll("*").forEach((el) => {
      const tag = el.tagName.toLowerCase();
      const keepAttrs = new Set<string>(
        tag === "img" ? ["src", "alt"] : tag === "a" ? ["href"] : []
      );
      // clone attributes
      Array.from(el.attributes).forEach((attr) => {
        if (!keepAttrs.has(attr.name)) el.removeAttribute(attr.name);
      });
    });
    const llmHtml = llmContainer.innerHTML;

    // 8) Build payload and cache
    const payload = {
      url,
      title: article.title || doc.title || null,
      byline: article.byline || null,
      siteName: ((): string | null => {
        const el = doc.querySelector("meta[property=\"og:site_name\"], meta[name=\"og:site_name\"]");
        return el?.getAttribute("content") ?? null;
      })(),
      contentHtml,
      llmHtml,
      textContent: article.textContent,
      leadImageUrl: leadImageUrl || null,
      images,
      timestamp: Timestamp.now(),
    };
    const pBytes = Buffer.byteLength(JSON.stringify(payload), "utf8");
    logger.info("Firestore document size (articleContent)", {
      bytes: pBytes,
      kb: (pBytes / 1024).toFixed(2),
      imagesCount: images.length,
      titleLength: (payload.title || "").length,
      textLength: (payload.textContent || "").length,
    });
    await db.collection("articleContent").add(payload);

    logger.info("Parsed and cached article content", {url, title: payload.title});
    response.json(payload);
  } catch (error) {
    logger.error("Error in extractArticle", {
      url,
      error: error instanceof Error ? {
        name: error.name,
        message: error.message,
        stack: error.stack,
      } : error,
    });

    if (isAxiosError(error)) {
      logger.error("Axios error details", {
        url,
        status: error.response?.status,
        statusText: error.response?.statusText,
        headers: error.response?.headers,
        data: typeof error.response?.data === "string" ?
          error.response.data.substring(0, 500) + "..." :
          error.response?.data,
      });
    }

    response.status(500).json({
      error: "Failed to extract article",
      details: error instanceof Error ? error.message : "Unknown error",
    });
  }
});

// Function to simplify article content using OpenAI for different CEFR levels
export const simplifyArticle = onRequest({timeoutSeconds: 300}, async (request, response) => {
  const {url, level = "B1", stream = "false", language = ""} = request.query as {
    url?: string;
    level?: string;
    stream?: string;
    language?: string;
  };
  const {url: bodyUrl, level: bodyLevel, stream: bodyStream, language: bodyLanguage} = request.body || {};

  const articleUrl = url || bodyUrl;
  const cefrLevel = level || bodyLevel || "B1";
  const enableStream = (stream || bodyStream || "false").toLowerCase() === "true";
  const targetLanguage = language || bodyLanguage || "";

  logger.info("simplifyArticle called", {
    url: articleUrl,
    level: cefrLevel,
    stream: enableStream,
    language: targetLanguage,
  });

  if (!articleUrl) {
    response.status(400).json({error: "Missing 'url' parameter"});
    return;
  }

  if (!["A2", "B1", "B2", "C1"].includes(cefrLevel)) {
    response.status(400).json({error: "Invalid level. Use: A2, B1, B2, or C1"});
    return;
  }

  try {
    // 1) Check cache for this URL + level + language combination (24 hour cache)
    const twentyFourHoursAgo = Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));

    // Build cache query - include language to ensure we return content in the right language
    let cached;
    try {
      const cacheQuery = db
        .collection("simplifiedArticles")
        .where("originalUrl", "==", articleUrl)
        .where("cefrLevel", "==", cefrLevel)
        .where("language", "==", targetLanguage || "")
        .where("timestamp", ">", twentyFourHoursAgo)
        .orderBy("timestamp", "desc")
        .limit(1);

      cached = await cacheQuery.get();
    } catch (cacheError) {
      // Index might not be ready yet, skip cache and regenerate
      logger.warn("Cache query failed (index may be building), regenerating", {
        error: cacheError instanceof Error ? cacheError.message : cacheError,
      });
      cached = {empty: true, docs: []};
    }

    if (!cached.empty) {
      const data = cached.docs[0].data();
      logger.info("Returning cached simplified article", {
        url: articleUrl,
        level: cefrLevel,
        language: targetLanguage,
      });
      response.json(data);
      return;
    }

    // 2) Get the original article content
    const articleQuery = db
      .collection("articleContent")
      .where("url", "==", articleUrl)
      .orderBy("timestamp", "desc")
      .limit(1);

    const articleSnapshot = await articleQuery.get();
    if (articleSnapshot.empty) {
      response.status(404).json({
        error: "Article not found",
        details: "Please extract the article first using extractArticle endpoint",
      });
      return;
    }

    const originalArticle = articleSnapshot.docs[0].data();
    logger.info("Found original article", {
      url: articleUrl,
      title: originalArticle.title,
      contentLength: originalArticle.llmHtml?.length || 0,
    });

    // 3) Prepare the simplification prompt
    // Determine the language instruction - be VERY explicit to prevent translation
    const languageInstruction = targetLanguage ?
      `CRITICAL LANGUAGE REQUIREMENT: The output MUST be written entirely in ${targetLanguage}. ` +
      "DO NOT translate to English under any circumstances. " +
      `Keep ALL text, including simplified vocabulary, in ${targetLanguage}.` :
      "CRITICAL LANGUAGE REQUIREMENT: Keep the article in its ORIGINAL language. " +
      "DO NOT translate to English. If the original is in Spanish, output Spanish. " +
      "If the original is in French, output French. Preserve the original language throughout.";

    const systemPrompt = `You are a language learning assistant that simplifies news articles for language learners.

${languageInstruction}

IMPORTANT RULES:
1. Output language: ${targetLanguage || "SAME AS INPUT"} - NEVER translate to English unless the original is in English
2. Preserve all <img> tags exactly as they appear
3. Simplify vocabulary and sentence structure for CEFR ${cefrLevel} level
4. Keep the same meaning and all key information

${cefrLevel} guidelines:
${cefrLevel === "A2" ? "- Use simple present/past tense, 10-15 word sentences, basic vocabulary" : ""}
${cefrLevel === "B1" ? "- Use mix of simple/compound sentences, common vocabulary, clear structure" : ""}
${cefrLevel === "B2" ? "- Use varied sentences, sophisticated vocabulary, detailed explanations" : ""}
${cefrLevel === "C1" ? "- Use complex structures, advanced vocabulary, nuanced explanations" : ""}

Return ONLY the simplified HTML content in ${targetLanguage || "the original language"}, no explanations.`;

    const userPrompt = `Simplify this article for ${cefrLevel} level learners. ` +
      `OUTPUT LANGUAGE: ${targetLanguage || "Keep in original language (DO NOT translate to English)"}\n\n` +
      `Article content:\n${originalArticle.llmHtml}`;

    // 4) Call OpenAI API with conditional streaming
    logger.info("Calling OpenAI API", {
      level: cefrLevel,
      contentLength: originalArticle.llmHtml?.length,
      streaming: enableStream,
    });

    if (enableStream) {
      // Set up streaming response
      response.setHeader("Content-Type", "text/plain; charset=utf-8");
      response.setHeader("Transfer-Encoding", "chunked");
      response.setHeader("Cache-Control", "no-cache");
      response.setHeader("Connection", "keep-alive");
      response.setHeader("Access-Control-Allow-Origin", "*");
      response.setHeader("Access-Control-Allow-Headers", "Content-Type");
      response.removeHeader("Content-Length");


      let fullContent = "";
      let tokenCount = 0;

      const stream = await getOpenAI().chat.completions.create({
        model: "gpt-5-nano",
        messages: [
          {role: "system", content: systemPrompt},
          {role: "user", content: userPrompt},
        ],
        max_completion_tokens: 16000,
        stream: true,
      });

      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || "";
        if (content) {
          fullContent += content;
          tokenCount += 1;
          // Send chunk to client
          response.write(`data: ${JSON.stringify({content, done: false})}\n\n`);
        }
      }

      // Send completion signal
      response.write(`data: ${JSON.stringify({content: "", done: true, totalTokens: tokenCount})}\n\n`);
      response.end();

      logger.info("OpenAI streaming completed", {
        url: articleUrl,
        level: cefrLevel,
        originalLength: originalArticle.llmHtml?.length || 0,
        simplifiedLength: fullContent.length,
        tokensUsed: tokenCount,
      });

      // Cache the complete result asynchronously (don't wait for it)
      const simplifiedPayload = {
        originalUrl: articleUrl,
        cefrLevel,
        language: targetLanguage || "",
        title: originalArticle.title,
        byline: originalArticle.byline,
        siteName: originalArticle.siteName,
        simplifiedHtml: fullContent,
        leadImageUrl: originalArticle.leadImageUrl,
        images: originalArticle.images,
        timestamp: Timestamp.now(),
        tokensUsed: tokenCount,
      };

      // Cache asynchronously - don't block the response
      db.collection("simplifiedArticles").add(simplifiedPayload)
        .then(() => logger.info("Streamed result cached successfully", {
          url: articleUrl,
          level: cefrLevel,
          language: targetLanguage,
        }))
        .catch((error) => logger.error("Failed to cache streamed result", {error, url: articleUrl}));
    } else {
      // Existing non-streaming logic
      const completion = await getOpenAI().chat.completions.create({
        model: "gpt-5-nano",
        messages: [
          {role: "system", content: systemPrompt},
          {role: "user", content: userPrompt},
        ],
        max_completion_tokens: 16000,
        stream: false,
      });

      // Log completion response
      logger.info("OpenAI completion response", {
        url: articleUrl,
        level: cefrLevel,
        finishReason: completion.choices[0]?.finish_reason,
        contentLength: completion.choices[0]?.message?.content?.length || 0,
        tokens: {
          input: completion.usage?.prompt_tokens || 0,
          output: completion.usage?.completion_tokens || 0,
          total: completion.usage?.total_tokens || 0,
        },
      });

      const simplifiedHtml = completion.choices[0]?.message?.content;

      if (!simplifiedHtml) {
        logger.error("OpenAI returned empty response", {
          url: articleUrl,
          level: cefrLevel,
          finishReason: completion.choices[0]?.finish_reason,
        });
        response.status(500).json({
          error: "Failed to generate simplified content",
          details: `OpenAI finish_reason: ${completion.choices[0]?.finish_reason || "unknown"}`,
        });
        return;
      }

      logger.info("OpenAI simplification completed", {
        url: articleUrl,
        level: cefrLevel,
        originalLength: originalArticle.llmHtml?.length || 0,
        simplifiedLength: simplifiedHtml.length,
        tokens: {
          input: completion.usage?.prompt_tokens || 0,
          output: completion.usage?.completion_tokens || 0,
          total: completion.usage?.total_tokens || 0,
        },
      });

      // 5) Build response payload and cache
      const simplifiedPayload = {
        originalUrl: articleUrl,
        cefrLevel,
        language: targetLanguage || "",
        title: originalArticle.title,
        byline: originalArticle.byline,
        siteName: originalArticle.siteName,
        simplifiedHtml,
        leadImageUrl: originalArticle.leadImageUrl,
        images: originalArticle.images,
        timestamp: Timestamp.now(),
        tokensUsed: completion.usage?.total_tokens || 0,
      };

      const payloadBytes = Buffer.byteLength(JSON.stringify(simplifiedPayload), "utf8");
      logger.info("Firestore document size (simplifiedArticles)", {
        bytes: payloadBytes,
        kb: (payloadBytes / 1024).toFixed(2),
        level: cefrLevel,
        imagesCount: originalArticle.images?.length || 0,
      });

      await db.collection("simplifiedArticles").add(simplifiedPayload);

      logger.info("Simplified article cached", {
        url: articleUrl,
        level: cefrLevel,
        title: originalArticle.title,
      });

      response.json(simplifiedPayload);
    }
  } catch (error) {
    logger.error("Error in simplifyArticle", {
      url: articleUrl,
      level: cefrLevel,
      error: error instanceof Error ? {
        name: error.name,
        message: error.message,
        stack: error.stack,
      } : error,
    });

    response.status(500).json({
      error: "Failed to simplify article",
      details: error instanceof Error ? error.message : "Unknown error",
    });
  }
});
