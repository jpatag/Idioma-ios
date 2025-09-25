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
import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { JSDOM } from "jsdom";
import { Readability } from "@mozilla/readability";
import OpenAI from 'openai';

dotenv.config({path: path.join(__dirname, "../../.env"), debug: true}); // Use absolute path resolution with debug

const newsAPIKey = process.env.NEWS_API_KEY;
logger.info("Loaded NEWS_API_KEY:", newsAPIKey ? "[SET]" : "[NOT SET]");

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});
logger.info("Loaded OPENAI_API_KEY:", process.env.OPENAI_API_KEY ? "[SET]" : "[NOT SET]");

admin.initializeApp();
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

    if (!country || !language) {
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

    // Check Firestore for cached articles (within last 24 hours)
    const twentyFourHoursAgo = Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));
    const cachedQuery = db.collection('articles')
      .where('country', '==', country)
      .where('language', '==', language)
      .where('timestamp', '>', twentyFourHoursAgo)
      .orderBy('timestamp', 'desc')
      .limit(1);
    const cachedSnapshot = await cachedQuery.get();

    if (!cachedSnapshot.empty) {
      const cachedDoc = cachedSnapshot.docs[0];
      logger.info(`Returning cached news for country: ${country}, language: ${language}`);
      response.json({ results: cachedDoc.data().articles });
      return;
    }

    // No cache found: Fetch from NewsAPI
    const apiResponse = await axios.get("https://newsdata.io/api/1/news", {
      params: {
        apikey: newsAPIKey,
        country: country,
        language: language,
      }
    });

    // Store in Firestore
    const docData = {
      country,
      language,
      timestamp: Timestamp.now(),
      articles: apiResponse.data.results || [],
      nextPage: apiResponse.data.nextPage,
    };
    const bytes = Buffer.byteLength(JSON.stringify(docData), "utf8");
    logger.info("Firestore document size (articles)", {
      bytes,
      kb: (bytes / 1024).toFixed(2),
      articlesCount: docData.articles.length,
    });
    await db.collection('articles').add(docData);

    logger.info(`Fetched and cached new news for country: ${country}, language: ${language}`);
    response.json(apiResponse.data);

  } catch (error) {
    logger.error("Error in getNews:", error);
    response.status(500).json({
      error: "Failed to fetch news",
      details: error instanceof Error ? error.message : "Unknown error"
    });
  }
});

// Function to extract and simplify article content from a URL
// Uses jsdom + @mozilla/readability to parse main content and collect images
export const extractArticle = onRequest(async (request, response) => {
  const url = (request.query.url as string) || (request.body && (request.body.url as string));
  logger.info("extractArticle called", { url });

  if (!url) {
    response.status(400).json({ error: "Missing 'url' query or body parameter" });
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
      logger.info("Returning cached article content", { url });
      response.json(data);
      return;
    }

    // 2) Fetch the article HTML with enhanced error handling and retry logic
    logger.info("Fetching article HTML", { url });
    
    const fetchWithRetry = async (retries = 2): Promise<any> => {
      for (let attempt = 1; attempt <= retries + 1; attempt++) {
        try {
          logger.info(`Fetch attempt ${attempt}`, { url });
          return await axios.get(url, {
            responseType: "text",
            headers: {
              "User-Agent":
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
              Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
              "Accept-Language": "en-US,en;q=0.9",
              "Accept-Encoding": "gzip, deflate, br",
              "Referer": "https://www.google.com/",
              "Cache-Control": "no-cache",
              "Pragma": "no-cache",
              "Sec-Fetch-Dest": "document",
              "Sec-Fetch-Mode": "navigate",
              "Sec-Fetch-Site": "cross-site",
              "Sec-Ch-Ua": '"Google Chrome";v="119", "Chromium";v="119", "Not?A_Brand";v="24"',
              "Sec-Ch-Ua-Mobile": "?0",
              "Sec-Ch-Ua-Platform": '"macOS"'
            },
            timeout: 30000, // Increased to 30 seconds
            validateStatus: (s) => s >= 200 && s < 400,
          });
        } catch (error) {
          logger.warn(`Fetch attempt ${attempt} failed`, { url, error: error instanceof Error ? error.message : error });
          if (attempt === retries + 1) throw error;
          // Wait 2 seconds before retry
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      }
    };

    const { data: html, status, headers } = await fetchWithRetry();

    logger.info("HTML fetch successful", { 
      url, 
      status, 
      contentType: headers['content-type'],
      htmlLength: html.length,
      hasBody: html.includes('<body'),
      hasScript: html.includes('<script')
    });

    // Check if we got a redirect or error page
    if (html.includes('Access Denied') || html.includes('403 Forbidden') || html.includes('Cloudflare')) {
      logger.warn("Possible bot detection", { url });
      response.status(403).json({ 
        error: "Access denied - site may be blocking automated requests",
        details: "The website appears to be blocking bot access"
      });
      return;
    }

    // 3) Build DOM and extract main content via Readability
    logger.info("Parsing HTML with Readability", { url });
    const dom = new JSDOM(html, { url });
    const doc = dom.window.document;
    
    // Log some basic info about the parsed document
    logger.info("Document parsed", {
      url,
      title: doc.title,
      bodyLength: doc.body?.innerHTML?.length || 0,
      paragraphs: doc.querySelectorAll('p').length,
      images: doc.querySelectorAll('img').length
    });

    const reader = new Readability(doc);
    const article = reader.parse();
    
    if (!article) {
      logger.error("Readability failed to parse article", { 
        url,
        title: doc.title,
        bodyExists: !!doc.body,
        contentLength: doc.body?.textContent?.length || 0
      });
      response.status(422).json({ 
        error: "Unable to parse article content",
        details: "Readability parser could not extract main content from this page"
      });
      return;
    }

    logger.info("Article parsed successfully", {
      url,
      title: article.title,
      contentLength: article.textContent?.length || 0,
      excerpt: article.excerpt
    });

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
      'meta[property="og:image"], meta[name="og:image"], meta[name="twitter:image"], meta[property="twitter:image"]'
    );
    const ogImageUrl = ogImageEl?.getAttribute("content") || undefined;
    const firstContentImage = contentFragment.querySelector("img");
    const leadImageUrl = ogImageUrl
      ? toAbsolute(ogImageUrl)
      : firstContentImage?.getAttribute("src")
        ? toAbsolute(firstContentImage.getAttribute("src") as string)
        : undefined;
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
        const el = doc.querySelector('meta[property="og:site_name"], meta[name="og:site_name"]');
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

    logger.info("Parsed and cached article content", { url, title: payload.title });
    response.json(payload);
  } catch (error) {
    logger.error("Error in extractArticle", { 
      url,
      error: error instanceof Error ? {
        name: error.name,
        message: error.message,
        stack: error.stack
      } : error 
    });
    
    if (axios.isAxiosError(error)) {
      logger.error("Axios error details", {
        url,
        status: error.response?.status,
        statusText: error.response?.statusText,
        headers: error.response?.headers,
        data: typeof error.response?.data === 'string' 
          ? error.response.data.substring(0, 500) + '...' 
          : error.response?.data
      });
    }

    response.status(500).json({
      error: "Failed to extract article",
      details: error instanceof Error ? error.message : "Unknown error",
    });
  }
});

// Function to simplify article content using OpenAI for different CEFR levels
export const simplifyArticle = onRequest(async (request, response) => {
  const { url, level = 'B1', stream = 'false' } = request.query as { url?: string; level?: string; stream?: string };
  const { url: bodyUrl, level: bodyLevel, stream: bodyStream } = request.body || {};
  
  const articleUrl = url || bodyUrl;
  const cefrLevel = level || bodyLevel || 'B1';
  const enableStream = (stream || bodyStream || 'false').toLowerCase() === 'true';
  
  logger.info("simplifyArticle called", { url: articleUrl, level: cefrLevel, stream: enableStream });

  if (!articleUrl) {
    response.status(400).json({ error: "Missing 'url' parameter" });
    return;
  }

  if (!['A2', 'B1', 'B2', 'C1'].includes(cefrLevel)) {
    response.status(400).json({ error: "Invalid level. Use: A2, B1, B2, or C1" });
    return;
  }

  try {
    // 1) Check cache for this URL + level combination (24 hour cache)
    const twentyFourHoursAgo = Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));
    const cacheQuery = db
      .collection("simplifiedArticles")
      .where("originalUrl", "==", articleUrl)
      .where("cefrLevel", "==", cefrLevel)
      .where("timestamp", ">", twentyFourHoursAgo)
      .orderBy("timestamp", "desc")
      .limit(1);
    
    const cached = await cacheQuery.get();
    if (!cached.empty) {
      const data = cached.docs[0].data();
      logger.info("Returning cached simplified article", { url: articleUrl, level: cefrLevel });
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
        details: "Please extract the article first using extractArticle endpoint"
      });
      return;
    }

    const originalArticle = articleSnapshot.docs[0].data();
    logger.info("Found original article", { 
      url: articleUrl, 
      title: originalArticle.title,
      contentLength: originalArticle.llmHtml?.length || 0
    });

    // 3) Prepare the simplification prompt
    const systemPrompt = `Simplify this news article for CEFR ${cefrLevel} level learners. Preserve all <img> tags exactly.

    ${cefrLevel} guidelines:
    ${cefrLevel === 'A2' ? '- Simple present/past tense, 10-15 word sentences, basic vocabulary' : ''}
    ${cefrLevel === 'B1' ? '- Mix simple/compound sentences, common vocabulary, clear structure' : ''}
    ${cefrLevel === 'B2' ? '- Varied sentences, sophisticated vocabulary, detailed explanations' : ''}
    ${cefrLevel === 'C1' ? '- Complex structures, advanced vocabulary, nuanced explanations' : ''}

    Return only simplified HTML, no explanations.`;

    const userPrompt = `Please simplify this article for ${cefrLevel} level learners. Preserve all <img> tags exactly:

    ${originalArticle.llmHtml}`;

    // 4) Call OpenAI API with conditional streaming
    logger.info("Calling OpenAI API", { level: cefrLevel, contentLength: originalArticle.llmHtml?.length, streaming: enableStream });
    
    if (enableStream) {
      // Set up streaming response
      response.setHeader('Content-Type', 'text/plain; charset=utf-8');
      response.setHeader('Transfer-Encoding', 'chunked');
      response.setHeader('Cache-Control', 'no-cache');
      response.setHeader('Connection', 'keep-alive');
      response.setHeader('Access-Control-Allow-Origin', '*');
      response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
      response.removeHeader('Content-Length');

      
      let fullContent = '';
      let tokenCount = 0;
      
      const stream = await openai.chat.completions.create({
        model: "gpt-5-nano",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ],
        max_completion_tokens: 3000,
        stream: true,
      });

      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || '';
        if (content) {
          fullContent += content;
          tokenCount += 1;
          // Send chunk to client
          response.write(`data: ${JSON.stringify({ content, done: false })}\n\n`);
        }
      }
      
      // Send completion signal
      response.write(`data: ${JSON.stringify({ content: '', done: true, totalTokens: tokenCount })}\n\n`);
      response.end();
      
      logger.info("OpenAI streaming completed", {
        url: articleUrl,
        level: cefrLevel,
        originalLength: originalArticle.llmHtml?.length || 0,
        simplifiedLength: fullContent.length,
        tokensUsed: tokenCount
      });
      
      // Cache the complete result asynchronously (don't wait for it)
      const simplifiedPayload = {
        originalUrl: articleUrl,
        cefrLevel,
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
        .then(() => logger.info("Streamed result cached successfully", { url: articleUrl, level: cefrLevel }))
        .catch(error => logger.error("Failed to cache streamed result", { error, url: articleUrl }));
      
    } else {
      // Existing non-streaming logic
      const completion = await openai.chat.completions.create({
        model: "gpt-5-nano",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt }
        ],
        max_completion_tokens: 3000,
        stream: false,
      });

      const simplifiedHtml = completion.choices[0]?.message?.content;
      
      if (!simplifiedHtml) {
        logger.error("OpenAI returned empty response", { url: articleUrl, level: cefrLevel });
        response.status(500).json({ error: "Failed to generate simplified content" });
        return;
      }

      logger.info("OpenAI simplification completed", {
        url: articleUrl,
        level: cefrLevel,
        originalLength: originalArticle.llmHtml?.length || 0,
        simplifiedLength: simplifiedHtml.length,
        tokensUsed: completion.usage?.total_tokens || 0
      });

      // 5) Build response payload and cache
      const simplifiedPayload = {
        originalUrl: articleUrl,
        cefrLevel,
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
        imagesCount: originalArticle.images?.length || 0
      });

      await db.collection("simplifiedArticles").add(simplifiedPayload);
      
      logger.info("Simplified article cached", { 
        url: articleUrl, 
        level: cefrLevel,
        title: originalArticle.title 
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
        stack: error.stack
      } : error
    });

    response.status(500).json({
      error: "Failed to simplify article",
      details: error instanceof Error ? error.message : "Unknown error"
    });
  }
});
