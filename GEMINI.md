# Idioma — Project Context for Gemini

## Project Overview
Idioma is a language learning iOS app that simplifies news articles using AI. Users select a target language, pick interest categories, read region-specific news, and get articles simplified to CEFR levels (A2–C1) using OpenAI. Spanish articles also get vocabulary highlighting from a bundled word list.

**Stack:** SwiftUI iOS + Firebase (Auth, Firestore, Cloud Functions) + newsdata.io API + OpenAI

> **Note:** README files in `docs/` and `Idioma-ios/` are placeholder documentation. Refer to actual code in `Idioma-backend/functions/src/index.ts` and `Idioma-ios/Idioma/` for implementation details.

---

## Project Structure

```
Idioma-ios/                  # SwiftUI iOS application
  Idioma/
    Idioma.xcodeproj         # Xcode project (open this, NOT Idioma-app)
    Idioma/
      IdiomaApp.swift          # App entry point, Firebase config, 3-gate nav
      Services/
        APIService.swift                   # Network layer
        AuthService.swift                  # Firebase Auth + Google Sign-In + preferences
        SpanishVocabularyHighlighter.swift  # Category-aware vocab highlighting
      Views/
        LoginView.swift              # Google Sign-In + email auth entry point
        LanguageSelectionView.swift  # Onboarding step 1: target language
        CategorySelectionView.swift  # Onboarding step 2: interest categories
        HomeView.swift               # News feed by language + categories
        ArticleDetailView.swift      # Reader with CEFR level selector + vocab highlighting
        MainTabView.swift            # Tab navigation (Home/Saved/Settings)
        SavedArticlesView.swift      # Stub — no backend storage yet
        SettingsView.swift           # Full settings: profile, language, level, categories
      Models/
        Article.swift          # NewsResponse, ArticleContent, SimplifiedArticle, CEFRLevel
        Category.swift         # IdiomaCategory taxonomy — 14 categories with NewsData mapping
        Language.swift         # Language/Country mappings, 10 supported languages
        User.swift             # User model with categories, notifications, darkMode prefs
      Resources/
        SpanishTop1000Words.csv  # Bundled vocab: ~1000 words with category + level columns

Idioma-backend/              # Firebase Cloud Functions (TypeScript)
  functions/
    src/index.ts             # All endpoints: getNews, extractArticle, simplifyArticle
    .env                     # NEWS_API_KEY, OPENAI_API_KEY (gitignored — never commit)
    package.json             # Node 22, dependencies
  firestore.rules            # Security rules (⚠️ expired Aug 2025 — needs update)
  firestore.indexes.json     # Composite index definitions
  firebase.json              # Emulator + deploy config

docs/
  idioma_development_plan.md # 8-phase roadmap with tech stack details
  Idioma FD(Final output).csv  # Feature definition spreadsheet
  Idioma FD-2.xlsx             # Feature definition (Excel)

stitch_idioma_mock_up/       # UI mockup assets
  article_view/              # Article reader mockups
  home_feed/                 # Home feed mockups
  language_selection/         # Language picker mockups
  log_in/                    # Login screen mockups
  settings/                  # Settings screen mockups
```

---

## Key Files

| File | Description |
|------|-------------|
| `Idioma-backend/functions/src/index.ts` | All backend logic |
| `Idioma-ios/Idioma/Idioma/Services/APIService.swift` | iOS networking layer |
| `Idioma-ios/Idioma/Idioma/Services/AuthService.swift` | Auth + preferences + vocab preloading |
| `Idioma-ios/Idioma/Idioma/Services/SpanishVocabularyHighlighter.swift` | Vocabulary highlighting service |
| `Idioma-ios/Idioma/Idioma/Views/ArticleDetailView.swift` | Article reader UI + vocab highlights |
| `Idioma-ios/Idioma/Idioma/Views/SettingsView.swift` | Full settings screen |
| `Idioma-ios/Idioma/Idioma/Models/Category.swift` | 14-category taxonomy + NewsData mapping |
| `docs/idioma_development_plan.md` | Complete 8-phase plan |

---

## Development Workflows

### Backend (Firebase Cloud Functions)
```bash
cd Idioma-backend/functions
npm install
npm run build                      # TypeScript → lib/index.js
npm run serve                      # Start local emulators
firebase deploy --only functions   # Deploy to production
```

**Emulator ports:** Functions `:5001`, Firestore `:8080`, Auth `:9099`, UI `:4001`

**Environment setup:**
- Create `Idioma-backend/functions/.env` with `NEWS_API_KEY=<key>` and `OPENAI_API_KEY=<key>`
- Path resolution: `dotenv.config({path: path.join(__dirname, "../.env")})` (from compiled `lib/` to `functions/.env`)
- Firebase project ID: `idioma-87bed`

### iOS Development
- **Open:** `Idioma-ios/Idioma/Idioma.xcodeproj` in Xcode (not `Idioma-app` — that path is outdated)
- **Dependencies:** Firebase iOS SDK (SPM), GoogleSignIn-iOS (SPM) — see `Package.resolved`
- **Info.plist:** Must add `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` to URL Schemes
- **API base URL:** `APIService.baseURL` → `https://us-central1-idioma-87bed.cloudfunctions.net`

---

## Data Flow

### News Fetching (`getNews`)
1. User selects language + categories → `APIService.getNews(country: "es", language: "es", categories: [1,4,6])`
2. Backend builds a `categoriesKey` from sorted category IDs for cache lookup
3. Checks Firestore `articles` collection (24hr TTL, keyed by country+language+categoriesKey)
4. If not cached:
   - **No categories**: fetches general news from newsdata.io
   - **Strong-mapping categories** (1-8, 10-11, 13): single combined API call using NewsData category names
   - **Lossy categories** (9, 12, 14): separate API calls with keyword augmentation queries
   - Deduplicates by `article_id`, then round-robin interleaves via `balanceFeed()` for category balance
5. Each article annotated with `idiomaCategoryIds` array
6. iOS decodes `NewsResponse.results` → `[Article]`

### Article Simplification (2-step pipeline)
1. **Extract:** `APIService.extractArticle(url:)` → backend uses `jsdom` + `@mozilla/readability`
   - 3-attempt retry with 2s delays and browser headers to avoid bot detection
   - HTML fetched as `arraybuffer` with `contentType` header for proper encoding detection
   - Returns `ArticleContent`: `contentHtml`, `llmHtml` (AI-cleaned), `textContent`, `images[]`
   - Cached in `articleContent` (7-day TTL)

2. **Simplify:** `APIService.simplifyArticle(url:, level:, language:)` → backend calls OpenAI
   - Fetches cached article content, sends `llmHtml` with CEFR-level system prompt
   - **CRITICAL:** Always pass `language` param — prompts explicitly say "keep in target language" to prevent English translation
   - **Format:** Output is strictly constrained to Markdown (`##` headings, `**bold**`, paragraphs). No HTML.
   - Model: `gpt-5-nano` (custom model name — not standard `gpt-4`/`gpt-3.5-turbo`)
   - `max_completion_tokens: 16000`
   - Cached in `simplifiedArticles` (24hr TTL, keyed by `url+level+language`). Includes `outputFormat: "markdown"` to isolate from legacy HTML caches.
   - **Performance:** Cache writes (`articleContent` & `simplifiedArticles`) use "fire-and-forget" promises (no `await`) to eliminate latency overhead for the user.
   - Supports SSE streaming (`stream=true`) natively. iOS client buffers and debounces stream updates (100ms) and uses `MarkdownFormatter` to display formatted paragraphs progressively without scroll lag.

### Vocabulary Highlighting (Spanish only)
1. `SpanishVocabularyHighlighter` loads `SpanishTop1000Words.csv` on app launch (preloaded when target language is Spanish)
2. CSV contains words with `categoryId` (1–14) and `VocabularyLevelID` (L1/L2/L3)
3. CEFR levels map to vocab levels: A2→L1, B1→L2, B2/C1→L3
4. When viewing a simplified article, plain text is matched against active categories + current level
5. Matches build an array of `VocabularyMatch` objects containing the `NSRange` and category color
6. The `MarkdownFormatter` builds an `NSMutableAttributedString` preserving headings/bold/paragraphs, and `makeAttributedString(formattedBase:matches:)` applies the vocab highlight colors *on top* of the formatting
7. Category ID 15 is "always on" (highlighted with `systemGray5`)

---

## Category System

### 14 App-Defined Categories (`IdiomaCategory`)

| ID | Name | NewsData Category | Lossy? |
|----|------|-------------------|--------|
| 1 | Politics & Government | politics | No |
| 2 | Economy & Finance | business | No |
| 3 | Arts & Entertainment | entertainment | No |
| 4 | Sports | sports | No |
| 5 | Business & Labor | business | No |
| 6 | Science & Tech | technology | No |
| 7 | Education | education | No |
| 8 | Crime, Law & Justice | crime | No |
| 9 | History & Religion | other | **Yes** — keyword-augmented |
| 10 | Environment & Nature | environment | No |
| 11 | Health & Wellness | health | No |
| 12 | Social Issues & Society | domestic | **Yes** — keyword-augmented |
| 13 | Lifestyle & Travel | lifestyle | No |
| 14 | Weather & Disaster | breaking | **Yes** — keyword-augmented |

- Max 5 categories selectable per user (`IdiomaCategory.maxSelection`)
- Categories stored in UserDefaults as `[Int]` via `AuthService.selectedCategories`
- Backend `CATEGORY_MAP` mirrors this taxonomy with keyword queries for lossy categories

---

## API Endpoints

| Endpoint | Purpose | Cache TTL |
|----------|---------|-----------|
| `GET /getNews` | Fetch headlines for country/language/categories | 24 hours |
| `GET /extractArticle` | Parse article HTML into clean content | 7 days |
| `GET /simplifyArticle` | Generate CEFR-simplified version | 24 hours |

### `GET /getNews`
```
Query:    ?country=es&language=es&categories=1,4,6
Response: {results: Article[], nextPage?: string}
Notes:    - categories param is optional (omit for general news)
          - category IDs must be 1-14, max 5
          - articles include idiomaCategoryIds field
          - newsdata.io returns full language names ("spanish"); Article.languageCode maps to ISO codes
```

### `GET /extractArticle`
```
Query:    ?url=<article_url>
Response: {url, title, byline, siteName, contentHtml, llmHtml, textContent, leadImageUrl, images[], timestamp}
Retry:    3 attempts, 2s delay each
Encoding: HTML fetched as arraybuffer, content-type header used for charset detection
```

### `GET /simplifyArticle`
```
Query:    ?url=<url>&level=B1&language=Spanish&stream=false
Levels:   A2, B1, B2, C1
Response: {originalUrl, cefrLevel, language, title, byline, siteName, simplifiedHtml, leadImageUrl, images[], tokensUsed, timestamp}
Streaming: stream=true returns SSE: data: {content, done, totalTokens?}\n\n
```

**Auth note:** Auth is currently disabled — `verifyFirebaseIdToken` middleware is commented out in `index.ts`. The function signature exists but is commented out (lines 44–54).

### Error Response Format
All endpoints: `{error: string, details?: string}`

| Code | Cause |
|------|-------|
| 400 | Missing/invalid parameters (including invalid category IDs or >5 categories) |
| 403 | Bot detection (Cloudflare block) |
| 404 | Article not found (call `extractArticle` first) |
| 422 | Readability parse failure (paywall, JS-only, invalid HTML) |
| 500 | API key missing, network error, OpenAI failure |

---

## Code Conventions

### Backend (TypeScript Cloud Functions)

```typescript
// Always use axios — never native fetch
import axios, {isAxiosError} from "axios";
const {data, status} = await axios.get(url, {params, headers, timeout: 30000});

// Firestore caching pattern
const cutoff = Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));
const cached = await db.collection("articles")
  .where("country", "==", country)
  .where("timestamp", ">", cutoff)
  .orderBy("timestamp", "desc")
  .limit(1).get();
if (!cached.empty) return cached.docs[0].data();

// Fire-and-forget write pattern for performance (don't await 'set' operations in hot paths)
db.collection("articleContent").doc(docId).set(docData).catch((e) => logger.error("Write failed", e));

// Structured logging
import * as logger from "firebase-functions/logger";
logger.info("Fetching news", {country, language});
logger.error("Error", {url, error: error.message});

// Consistent error responses
response.status(500).json({
  error: "Failed to simplify article",
  details: error instanceof Error ? error.message : "Unknown error"
});

// Document size monitoring (Firestore 1MB limit)
const bytes = Buffer.byteLength(JSON.stringify(docData), "utf8");
logger.info("Firestore doc size", {bytes, kb: (bytes / 1024).toFixed(2)});

// Axios error details logging
if (isAxiosError(error)) {
  logger.error("Axios error details", {
    url, status: error.response?.status,
    data: typeof error.response?.data === "string" ?
      error.response.data.substring(0, 500) + "..." : error.response?.data,
  });
}
```

```typescript
// OpenAI — always use gpt-5-nano (custom model)
const completion = await getOpenAI().chat.completions.create({
  model: "gpt-5-nano",
  messages: [{role: "system", content: systemPrompt}, {role: "user", content: userPrompt}],
  max_completion_tokens: 16000,
  stream: false,
});

// Streaming
for await (const chunk of stream) {
  const content = chunk.choices[0]?.delta?.content || "";
  response.write(`data: ${JSON.stringify({content, done: false})}\n\n`);
}
response.write(`data: ${JSON.stringify({done: true, totalTokens})}\n\n`);
response.end();
```

```typescript
// Readability extraction
import {JSDOM} from "jsdom";
import {Readability} from "@mozilla/readability";

const dom = new JSDOM(htmlBuffer, {url, contentType});
const article = new Readability(dom.window.document).parse();
if (!article) {
  response.status(422).json({error: "Failed to parse article content"});
  return;
}
```

```typescript
// Category-filtered news fetching (hybrid pipeline)
const CATEGORY_MAP: Record<number, CategoryMapping> = {
  1: {newsDataCategory: "politics", isLossy: false},
  // ...
  9: {newsDataCategory: "other", isLossy: true,
    keywords: "religion OR church OR mosque OR temple OR faith OR archaeology..."},
};

// Strong categories → single combined API call
// Lossy categories → separate calls with keyword augmentation
// Then deduplicate + round-robin balanceFeed()
```

### iOS (SwiftUI)

**`AuthService` — single source of truth (passed as `@EnvironmentObject`):**
```swift
// IdiomaApp.swift
@StateObject private var authService = AuthService()

// Child views
struct HomeView: View {
    @EnvironmentObject var authService: AuthService
}

// AuthService publishes:
@Published var isAuthenticated: Bool
@Published var currentUser: User?
@Published var isLoading: Bool
@Published var errorMessage: String?
@Published var hasCompletedOnboarding: Bool

// AuthService computed preferences (UserDefaults-backed):
var nativeLanguage: String      // default "en"
var targetLanguage: String      // default "es" — triggers vocab preload on set
var preferredLevel: String      // default "B1"
var selectedCategories: [Int]   // default []
var notificationsEnabled: Bool
var darkModeEnabled: Bool
var hasSelectedCategories: Bool  // computed from selectedCategories

// Debug bypass (DEBUG builds only):
static let skipAuth = true  // Set to false to test real auth
// Calls bypassLogin() which creates mock user "debug@idioma.dev"
```

**`AuthService` methods:**
```swift
func signInWithGoogle()                    // Google Sign-In flow
func signInWithEmail(email:, password:)    // Email/password login
func signUpWithEmail(email:, password:)    // Email/password registration
func signOut()
func saveTargetLanguage(_ language:)       // Onboarding step 1
func completeOnboarding(targetLanguage:, categories:)  // Finishes onboarding
func completeCategorySelection(categories:)             // Existing user missing categories
func updatePreferences(nativeLanguage:?, targetLanguage:?, level:?, categories:?)  // Settings changes
func getIDToken() async throws -> String   // For authenticated API calls
```

**`APIService` — singleton:**
```swift
class APIService {
    static let shared = APIService()
    private let baseURL = "https://us-central1-idioma-87bed.cloudfunctions.net"

    func getNews(country: String, language: String, categories: [Int]) async throws -> [Article]
    func extractArticle(url: String) async throws -> ArticleContent
    func simplifyArticle(url: String, level: String, language: String, stream: Bool) async throws -> SimplifiedArticle
}
```

**Navigation:** `NavigationView` + `NavigationLink` (not `NavigationStack` — supporting older iOS)
- Exception: `SettingsView` picker sheets use `NavigationStack` internally

**Async pattern:** `Task { try await APIService.shared.getNews(...) }` in `.onAppear`

**Auth flow (3-gate):**
```
LoginView
  → (isAuthenticated)
    LanguageSelectionView
      → (hasCompletedOnboarding)
        CategorySelectionView (isExistingUserFlow: true)
          → (hasSelectedCategories)
            MainTabView
```

**Common UI patterns:**
```swift
// Loading state
if isLoading { ProgressView().scaleEffect(1.2) }

// Error state
if let error = errorMessage {
    VStack {
        Image(systemName: "exclamationmark.triangle")
        Text(error).foregroundColor(.secondary)
        Button("Try Again") { retry() }
    }
}

// CEFR level picker
Picker("Level", selection: $currentLevel) {
    ForEach(CEFRLevel.allCases) { level in
        Text(level.displayName).tag(level)
    }
}

// Category grid (used in CategorySelectionView + SettingsView)
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
    ForEach(IdiomaCategory.all) { category in
        CategoryCell(category: category, isSelected: ..., isDisabled: ..., primaryColor: ...) {
            toggleCategory(category.id)
        }
    }
}
```

**Vocabulary highlighting in ArticleDetailView:**
```swift
// Check if highlighting should be active
SpanishVocabularyHighlighter.shared.shouldHighlight(languageCode: article.languageCode)

// Get matches for current categories + CEFR level
let matches = SpanishVocabularyHighlighter.shared.highlightMatches(
    in: plainText,
    activeCategoryIDs: highlighter.activeCategoryIDs(from: article.idiomaCategoryIds),
    vocabularyLevelIDs: [currentLevel.vocabularyLevelID]
)

// Convert to attributed string with colored highlights
let attributed = SpanishVocabularyHighlighter.shared.makeAttributedString(text: plainText, matches: matches)
```

---

## Data Models

### `User` (UserDefaults-backed preferences)
```swift
struct User: Codable {
    var id, email, displayName: String
    var profileImageUrl: String?
    var nativeLanguage: String          // "en"
    var targetLanguage: String          // "es"
    var preferredLevel: String          // "B1"
    var selectedCategories: [Int]       // [1, 4, 6]
    var notificationsEnabled: Bool
    var darkModeEnabled: Bool
}
```

### `Article` (from `getNews`)
```swift
struct Article: Codable, Identifiable {
    let article_id, title, link, description, content: String?
    let image_url, source_id, source_name, language: String?
    let country, category: [String]?
    let idiomaCategoryIds: [Int]?      // Mapped Idioma category IDs

    var primaryCategoryName: String?    // Display name from IdiomaCategory
    var languageCode: String?           // Maps "spanish" → "es"
    var languageName: String?           // Maps "es" → "Spanish"
}
```

### `CEFRLevel`
```swift
enum CEFRLevel: String, CaseIterable {
    case a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1"
    var displayName: String     // "Beginner", "Intermediate", "Advanced", "Advanced"
    var spanishName: String     // "Principiante", "Intermedio", "Avanzado", "Experto"
    var vocabularyLevelID: VocabularyLevelID  // A2→.l1, B1→.l2, B2/C1→.l3
}
```

### `VocabularyLevelID` / `VocabularyMatch`
```swift
enum VocabularyLevelID: String, CaseIterable { case l1 = "L1", l2 = "L2", l3 = "L3" }
struct VocabularyMatch: Equatable { let range: NSRange; let categoryId: Int }
```

---

## Known Issues & Gotchas

### Backend
- **Firestore 1MB limit:** All endpoints log doc size before writing. Watch for large `llmHtml` or many images.
- **Bot detection:** Some sites return 403. `extractArticle` checks for "Access Denied"/"Cloudflare" in HTML.
- **Readability failures:** `reader.parse()` returning `null` → 422. Indicates paywall or JS-required content.
- **Language drift:** `simplifyArticle` prompt has a "CRITICAL LANGUAGE REQUIREMENT" block — don't remove it.
- **OpenAI model name:** `gpt-5-nano` is a custom model name. Do not replace with standard model names.
- **⚠️ Firestore rules expired:** `firestore.rules` has a `request.time < timestamp.date(2025, 8, 14)` rule that has passed. The wildcard write rule is now denied. Auth-gated rules for `articles`, `simplifiedArticles`, and `articleContent` collections still work for authenticated users.
- **Composite Indexes Required:** Filtering cached simplified articles by `outputFormat` and ordering by `timestamp` requires a Firestore composite index.
- **Lossy category fetches:** Each lossy category makes a separate newsdata.io API call. With 3 lossy categories selected, that's 4 total API calls per uncached request.

### iOS
- **No local persistence yet:** No Core Data or caching layer. All data is fetched live.
- **Debug auth bypass:** `AuthService.skipAuth = true` in DEBUG builds — set to `false` to test real Google Sign-In.
- **`AsyncImage` failures:** Silent `.empty` state — consider adding a placeholder.
- **URL Schemes:** Google Sign-In requires `REVERSED_CLIENT_ID` in `Info.plist` URL Types.
- **`SavedArticlesView`:** View exists but has no backend storage yet.
- **Old pattern warning:** `ContentView.swift`/`FirebaseManager.swift` pattern is not in the current codebase.
- **Vocabulary highlighting is Spanish-only:** `shouldHighlight()` checks for language code "es" or "spanish". Other languages have no vocab highlighting.
- **Settings toggles are local-only:** Notifications and dark mode toggles in `SettingsView` update UserDefaults but have no backend or system integration yet.

---

## Development Roadmap

**Current phase:** Phase 2 (MVP Frontend Integration) — auth, news, extraction, simplification, categories, and vocabulary highlighting working.

| Phase | Focus |
|-------|-------|
| 3 | Complexity scoring, improved level toggle UX, dashboard tiles |
| 4 | In-line vocabulary lookup (iOS Dictionary API), flashcards (Core Data), TTS (AVSpeechSynthesizer) |
| 5 | Wikipedia search integration, contextual quiz generation |

**Known gaps:**
- No local persistence / offline caching (planned Phase 4)
- No bookmarking backend (`SavedArticlesView` is a stub)
- Push notifications / WidgetKit not started
- Firebase Analytics + Sentry configured but not instrumented
- Firestore security rules need updating (expired Aug 2025)
- Vocabulary highlighting only supports Spanish
- Notifications / dark mode toggles are UI-only
