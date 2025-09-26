import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift
import Combine

// A simple struct to represent a news article, matching the backend response.
struct NewsArticle: Decodable, Identifiable {
    // Local UUID for SwiftUI list identification
    let id: UUID = UUID()
    // API response fields
    let article_id: String
    let title: String
    let link: String
    let description: String?
    let creator: [String]?
    let keywords: [String]?
    let content: String?
    let pubDate: String?
    let image_url: String?
    let language: String?
    let country: [String]?
    let category: [String]?
    let source_name: String?
    let source_id: String?
    let source_url: String?
    let source_icon: String?
    let source_priority: Int?
    let pubDateTZ: String?
    let duplicate: Bool?
    let video_url: String?
    
    // Make it conform to Identifiable with UUID while keeping the article_id from the API
    private enum CodingKeys: String, CodingKey {
        case article_id, title, link, description, creator, keywords, content
        case pubDate, image_url, language, country, category, source_name
        case source_id, source_url, source_icon, source_priority
        case pubDateTZ, duplicate, video_url
    }
    
    // Convert from ArticleModel to NewsArticle
    init(from model: ArticleModel) {
        self.article_id = model.article_id
        self.title = model.title
        self.link = model.link
        self.description = model.description
        self.creator = model.creator
        self.keywords = model.keywords
        self.content = model.content
        self.pubDate = model.pubDate
        self.image_url = model.image_url
        self.language = model.language
        self.country = model.country
        self.category = model.category
        self.source_name = model.source_name
        self.source_id = model.source_id
        self.source_url = model.source_url
        self.source_icon = model.source_icon
        self.source_priority = model.source_priority
        self.pubDateTZ = model.pubDateTZ
        self.duplicate = model.duplicate
        self.video_url = model.video_url
    }
    
    // Convenience initializer for fallback articles
    init(title: String, link: String, description: String?) {
        self.article_id = UUID().uuidString
        self.title = title
        self.link = link
        self.description = description
        self.creator = nil
        self.keywords = nil
        self.content = nil
        self.pubDate = nil
        self.image_url = nil
        self.language = nil
        self.country = nil
        self.category = nil
        self.source_name = nil
        self.source_id = nil
        self.source_url = nil
        self.source_icon = nil
        self.source_priority = nil
        self.pubDateTZ = nil
        self.duplicate = nil
        self.video_url = nil
    }
}

// A struct for the top-level API response
struct NewsAPIResponse: Decodable {
    let results: [NewsArticle]
}

// A struct for extracted article content
struct ExtractedArticle: Decodable {
    let title: String
    let content: String
    let byline: String?
    let siteName: String?
    let excerpt: String?
    let textContent: String
    let images: [String]?
    let leadImageUrl: String?

    private enum CodingKeys: String, CodingKey {
        case title, content = "contentHtml", byline, siteName, excerpt, textContent, images, leadImageUrl
    }
    
    // Convert from ArticleContentModel
    init(from model: ArticleContentModel) {
        self.title = model.title
        self.content = model.contentHtml
        self.byline = model.byline
        self.siteName = model.siteName
        self.excerpt = nil
        self.textContent = model.textContent
        self.images = model.images
        self.leadImageUrl = model.leadImageUrl
    }
    
    // Direct initializer with individual parameters
    init(title: String, content: String, byline: String?, siteName: String?, excerpt: String?, textContent: String, images: [String]?, leadImageUrl: String?) {
        self.title = title
        self.content = content
        self.byline = byline
        self.siteName = siteName
        self.excerpt = excerpt
        self.textContent = textContent
        self.images = images
        self.leadImageUrl = leadImageUrl
    }
}

// A struct for simplified article content
struct SimplifiedArticle: Decodable {
    let original: String
    let simplified: String
    let language: String
    let cefrLevel: String?
    
    // Convert from SimplifiedArticleModel
    init(from model: SimplifiedArticleModel, original: String, language: String) {
        self.original = original
        self.simplified = model.simplifiedHtml
        self.language = language
        self.cefrLevel = model.cefrLevel
    }
    
    // For JSON decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        original = try container.decode(String.self, forKey: .original)
        simplified = try container.decode(String.self, forKey: .simplified)
        language = try container.decode(String.self, forKey: .language)
        cefrLevel = try container.decodeIfPresent(String.self, forKey: .cefrLevel)
    }
    
    enum CodingKeys: String, CodingKey {
        case original, simplified, language, cefrLevel
    }
    
    // Convenience initializer for direct creation (used for fallbacks)
    init(original: String, simplified: String, language: String, cefrLevel: String? = nil) {
        self.original = original
        self.simplified = simplified
        self.language = language
        self.cefrLevel = cefrLevel
    }
}


class FirebaseManager: ObservableObject {
    @Published var user: User?
    @Published var selectedLanguage: String?
    @Published var articles: [NewsArticle] = []
    @Published var isLoadingArticles = false
    
    private var cancellables = Set<AnyCancellable>()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let articleService = ArticleService()
    
    // Debug function to help with troubleshooting
    func printAvailableLanguages() {
        db.collection("articles").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Failed to get languages: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ No article documents found in Firestore")
                return
            }
            
            var languages = Set<String>()
            
            for doc in documents {
                if let language = doc.data()["language"] as? String {
                    languages.insert(language)
                }
            }
            
            print("📚 Available languages in Firestore: \(languages)")
        }
    }

    init() {
        // Listen for authentication state changes from Firebase
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            self?.user = user
            
            // Refresh data when user changes
            if user != nil {
                // Debug: print available languages to help troubleshoot
                self?.printAvailableLanguages()
                
                self?.fetchArticles()
            }
        }
        
        // Load selected language from UserDefaults
        selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage")
        
        // If emulator preference hasn't been set yet, default to false (use production)
        if UserDefaults.standard.object(forKey: "use_firebase_emulator") == nil {
            UserDefaults.standard.set(false, forKey: "use_firebase_emulator")
        }
        
        // Initialize Firestore
        setupFirestore()
    }
    
    private func setupFirestore() {
        // Configure Firestore settings
        let settings = db.settings
        settings.isPersistenceEnabled = true
        db.settings = settings
        
        // Check if using emulator
        if UserDefaults.standard.bool(forKey: "use_firebase_emulator") {
            print("Using Firebase emulator for Firestore")
            db.useEmulator(withHost: "localhost", port: 8080)
        }
    }
    
    func setLanguage(_ language: String) {
        selectedLanguage = language
        UserDefaults.standard.set(language, forKey: "selectedLanguage")
        
        // Clear existing articles to force a refresh
        self.articles = []
        
        // Refresh articles when language changes
        fetchArticles()
    }
    
    /// Sets whether to use Firebase emulator or production services
    /// - Parameter useEmulator: True to use local emulators, false to use production Firebase
    func setUseFirebaseEmulator(_ useEmulator: Bool) {
        UserDefaults.standard.set(useEmulator, forKey: "use_firebase_emulator")
        print("Firebase emulator mode set to: \(useEmulator). Please restart the app for changes to take effect.")
    }
    
    // MARK: - Firestore Article Methods
    
    /// Fetches articles from Firestore based on the current selected language
    func fetchArticles() {
        fetchArticlesForLanguage(language: selectedLanguage)
    }
    
    /// Fetches articles from Firestore for a specific language
    func fetchArticlesForLanguage(language: String?) {
        isLoadingArticles = true
        
        // Map UI language names to appropriate database values
        let dbLanguage: String?
        if let lang = language {
            switch lang {
            case "United States": dbLanguage = "en"
            case "Spain": dbLanguage = "es"
            case "France":  dbLanguage = "fr"
            case "Japan": dbLanguage = "ja"
            default: dbLanguage = lang.lowercased()
            }
            print("🔍 Searching for articles with language: \(dbLanguage ?? "nil") (from UI: \(lang))")
        } else {
            dbLanguage = nil
        }
        
        // First try to get articles from Firestore
        articleService.fetchArticles(language: dbLanguage, limit: 20) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let articleModels):
                // Convert the Firestore models to our app's NewsArticle type
                let articles = articleModels.map { NewsArticle(from: $0) }
                
                // If we got articles from Firestore, use them
                if !articles.isEmpty {
                    DispatchQueue.main.async {
                        self.isLoadingArticles = false
                        self.articles = articles
                        print("✅ Successfully loaded \(articles.count) articles from Firestore")
                    }
                    return
                }
                
                // If we got no articles from Firestore, try the API
                print("⚠️ No articles found in Firestore for \(language ?? "any language"), fetching from API...")
                self.fetchNewsForLanguage(language: language ?? "English") { apiResult in
                    DispatchQueue.main.async {
                        self.isLoadingArticles = false
                        
                        switch apiResult {
                        case .success(let apiArticles):
                            if !apiArticles.isEmpty {
                                self.articles = apiArticles
                                print("✅ Successfully loaded \(apiArticles.count) articles from API")
                            } else {
                                print("⚠️ No articles returned from API either, using fallbacks")
                                let noArticlesError = NSError(domain: "ArticleError", code: -3, userInfo: [NSLocalizedDescriptionKey: "No articles returned from API"]) as Error
                                self.articles = self.provideFallbackArticles(for: language ?? "English", originalError: noArticlesError)
                            }
                        case .failure(let error):
                            print("❌ Failed to fetch articles from API: \(error.localizedDescription)")
                            self.articles = self.provideFallbackArticles(for: language ?? "English", originalError: error)
                        }
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to load articles from Firestore: \(error.localizedDescription)")
                
                // If Firestore fails, try the HTTP API as fallback
                self.fetchNewsForLanguage(language: language ?? "English") { apiResult in
                    DispatchQueue.main.async {
                        self.isLoadingArticles = false
                        
                        switch apiResult {
                        case .success(let apiArticles):
                            self.articles = apiArticles
                        case .failure(let error):
                            print("❌ Failed to fetch articles from API: \(error.localizedDescription)")
                            self.articles = self.provideFallbackArticles(for: language ?? "English", originalError: error)
                        }
                    }
                }
            }
        }
    }
    
    /// Fetches article content directly from Firestore
    /// - Parameters:
    ///   - articleId: The unique ID of the article
    ///   - completion: Completion handler with extracted article result
    func fetchArticleContent(articleId: String, completion: @escaping (Result<ExtractedArticle, Error>) -> Void) {
        articleService.fetchArticleContent(articleId: articleId) { result in
            switch result {
            case .success(let contentModel):
                let extractedArticle = ExtractedArticle(from: contentModel)
                completion(.success(extractedArticle))
                
            case .failure(let error):
                print("❌ Failed to fetch article content from Firestore: \(error.localizedDescription)")
                // Try the HTTP API as fallback
                if let article = self.articles.first(where: { $0.article_id == articleId }) {
                    if let url = URL(string: article.link), !article.link.isEmpty {
                        self.extractArticle(articleUrl: url.absoluteString, completion: completion)
                    } else {
                        // If the article doesn't have a valid link, create a minimal ExtractedArticle
                        let fallbackArticle = ExtractedArticle(
                            title: article.title,
                            content: article.content ?? "No content available",
                            byline: article.creator?.joined(separator: ", "),
                            siteName: article.source_name,
                            excerpt: article.description,
                            textContent: article.content ?? article.description ?? "No content available",
                            images: nil,
                            leadImageUrl: article.image_url
                        )
                        completion(.success(fallbackArticle))
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Fetches simplified article content from Firestore
    /// - Parameters:
    ///   - articleId: The unique ID of the article
    ///   - originalContent: The original article content for fallback
    ///   - language: The language of the article
    ///   - completion: Completion handler with simplified article result
    func fetchSimplifiedArticle(articleId: String, originalContent: String, language: String, completion: @escaping (Result<SimplifiedArticle, Error>) -> Void) {
        articleService.fetchSimplifiedArticle(articleId: articleId) { result in
            switch result {
            case .success(let simplifiedModel):
                let simplifiedArticle = SimplifiedArticle(from: simplifiedModel, original: originalContent, language: language)
                completion(.success(simplifiedArticle))
                
            case .failure(let error):
                print("❌ Failed to fetch simplified article from Firestore: \(error.localizedDescription)")
                // Try the HTTP API as fallback
                self.simplifyArticle(content: originalContent, language: language, completion: completion)
            }
        }
    }

    // MARK: - Async API Methods

    @MainActor
    func fetchArticlesAsync(for language: String?) async {
        self.isLoadingArticles = true
        
        // Map UI language names to appropriate database values
        let dbLanguage: String?
        if let lang = language {
            switch lang {
            case "United States": dbLanguage = "en"
            case "Spain": dbLanguage = "es"
            case "France":  dbLanguage = "fr"
            case "Japan": dbLanguage = "ja"
            default: dbLanguage = lang.lowercased()
            }
            print("🔍 Searching for articles with language: \(dbLanguage ?? "nil") (from UI: \(lang))")
        } else {
            dbLanguage = nil
        }
        
        do {
            // 1. Try Firestore first
            let articleModels = try await withCheckedThrowingContinuation { continuation in
                articleService.fetchArticles(language: dbLanguage, limit: 20) { result in
                    continuation.resume(with: result)
                }
            }
            
            if !articleModels.isEmpty {
                self.articles = articleModels.map { NewsArticle(from: $0) }
                print("✅ Successfully loaded \(self.articles.count) articles from Firestore")
            } else {
                // 2. If Firestore is empty, try the API
                print("⚠️ No articles found in Firestore for \(language ?? "any language"), fetching from API...")
                self.articles = try await fetchNewsForLanguageAsync(language: language ?? "English")
                print("✅ Successfully loaded \(self.articles.count) articles from API")
            }
        } catch {
            // 3. If both fail, provide fallbacks
            print("❌ Failed to load articles: \(error.localizedDescription). Providing fallbacks.")
            self.articles = provideFallbackArticles(for: language ?? "English", originalError: error)
        }
        
        self.isLoadingArticles = false
    }

    func fetchNewsForLanguageAsync(language: String) async throws -> [NewsArticle] {
        return try await withCheckedThrowingContinuation { continuation in
            fetchNewsForLanguage(language: language) { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetchArticleContentAsync(articleId: String, articleLink: String) async throws -> ExtractedArticle {
        // 1. Try to fetch from Firestore first
        return try await withCheckedThrowingContinuation { continuation in
            articleService.fetchArticleContent(articleId: articleId) { result in
                switch result {
                case .success(let contentModel):
                    print("✅ Successfully loaded article content from Firestore")
                    let extractedArticle = ExtractedArticle(from: contentModel)
                    continuation.resume(returning: extractedArticle)
                    
                case .failure(let error):
                    print("⚠️ Failed to fetch article content from Firestore: \(error.localizedDescription)")
                    print("⚠️ Falling back to HTTP API for extraction...")
                    
                    // Fallback to HTTP API extraction
                    self.extractArticle(articleUrl: articleLink) { extractResult in
                        continuation.resume(with: extractResult)
                    }
                }
            }
        }
    }

    func extractArticleAsync(articleUrl: String) async throws -> ExtractedArticle {
        return try await withCheckedThrowingContinuation { continuation in
            extractArticle(articleUrl: articleUrl) { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetchSimplifiedArticleAsync(articleId: String, articleUrl: String, originalContent: String, language: String) async throws -> SimplifiedArticle {
        // 1. Try to fetch from Firestore first, then fallback to HTTP API
        return try await withCheckedThrowingContinuation { continuation in
            articleService.fetchSimplifiedArticle(articleId: articleId) { result in
                switch result {
                case .success(let simplifiedModel):
                    print("✅ Successfully loaded simplified article from Firestore")
                    let simplifiedArticle = SimplifiedArticle(from: simplifiedModel, original: originalContent, language: language)
                    continuation.resume(returning: simplifiedArticle)
                    
                case .failure(let error):
                    print("⚠️ Failed to fetch simplified article from Firestore: \(error.localizedDescription)")
                    print("⚠️ Falling back to HTTP API for simplification...")
                    
                    // Fallback to HTTP API for simplification using URL
                    self.simplifyArticleFromUrl(articleUrl: articleUrl, language: language, originalContent: originalContent) { simplifyResult in
                        continuation.resume(with: simplifyResult)
                    }
                }
            }
        }
    }

    func simplifyArticleAsync(content: String, language: String) async throws -> SimplifiedArticle {
        return try await withCheckedThrowingContinuation { continuation in
            simplifyArticle(content: content, language: language) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func simplifyArticleFromUrlAsync(articleUrl: String, language: String, originalContent: String) async throws -> SimplifiedArticle {
        return try await withCheckedThrowingContinuation { continuation in
            simplifyArticleFromUrl(articleUrl: articleUrl, language: language, originalContent: originalContent) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Initiates the Google Sign-In flow.
    func signInWithGoogle() {
        // 1. Get the client ID from the app's Firebase configuration.
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Error: Firebase client ID not found in GoogleService-Info.plist.")
            return
        }

        // 2. Create a Google Sign-In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // 3. Find the top-most view controller to present the sign-in sheet.
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let topVC = windowScene.windows.first?.rootViewController else {
            print("Error: Could not find the top view controller to present the sign-in sheet.")
            return
        }

        // 4. Start the sign-in flow. This will open the Google Sign-In sheet.
        GIDSignIn.sharedInstance.signIn(withPresenting: topVC) { [weak self] result, error in
            guard error == nil else {
                print("Google Sign-In error: \(error!.localizedDescription)")
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Error: Google Sign-In did not return a valid user or ID token.")
                return
            }

            // 5. Create a Firebase credential with the Google ID token.
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)

            // 6. Sign in to Firebase with the credential.
            self?.auth.signIn(with: credential) { (authResult, error) in
                if let error = error {
                    print("Firebase Sign-In error: \(error.localizedDescription)")
                    return
                }
                print("Successfully signed into Firebase with user: \(authResult?.user.displayName ?? "Unknown")")
            }
        }
    }

    /// Signs the current user out of both Firebase and Google.
    func signOut() {
        // Sign out of Firebase
        do {
            try auth.signOut()
            print("Signed out of Firebase.")
        } catch let signOutError as NSError {
            print("Error signing out of Firebase: %@", signOutError)
        }
        
        // Sign out of Google
        GIDSignIn.sharedInstance.signOut()
        print("Signed out of Google.")
    }

    /// Fetches news articles for a specific language.
    /// Fetch news articles for a specific language with improved error handling and fallback
    func fetchNewsForLanguage(language: String, completion: @escaping (Result<[NewsArticle], Error>) -> Void) {
        // Map language names to ISO codes for the API
        let languageCode: String
        let countryCode: String
        
        switch language.lowercased() {
        case "spain":
            languageCode = "es"
            countryCode = "es" // Spain
        case "france":
            languageCode = "fr"
            countryCode = "fr" // France
        case "japan":
            languageCode = "ja"
            countryCode = "jp" // Japan
        default: // "United States" or default
            languageCode = "en"
            countryCode = "us" // Default to US
        }
        
        // If user is already signed in, use their auth token
        if let user = auth.currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let error = error {
                    print("❌ Token error: \(error.localizedDescription)")
                    let fallbackArticles = self?.provideFallbackArticles(for: language, originalError: error)
                    completion(.success(fallbackArticles ?? []))
                    return
                }
                
                guard let token = token else {
                    let error = NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ID token not found."])
                    print("❌ Token error: ID token not found")
                    let fallbackArticles = self?.provideFallbackArticles(for: language, originalError: error)
                    completion(.success(fallbackArticles ?? []))
                    return
                }
                
                // Call the getNews function with language and country parameters
                self?.callGetNewsFunction(token: token, language: languageCode, country: countryCode) { result in
                    switch result {
                    case .success(let articles):
                        completion(.success(articles))
                    case .failure(let error):
                        // If API call fails, provide fallback articles
                        let fallbackArticles = self?.provideFallbackArticles(for: language, originalError: error)
                        completion(.success(fallbackArticles ?? []))
                    }
                }
            }
        } else {
            // If no user, sign in anonymously first
            auth.signInAnonymously { [weak self] (authResult, error) in
                if let error = error {
                    print("❌ Anonymous sign-in error: \(error.localizedDescription)")
                    let fallbackArticles = self?.provideFallbackArticles(for: language, originalError: error)
                    completion(.success(fallbackArticles ?? []))
                    return
                }
                
                guard let user = authResult?.user else {
                    let error = NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found."])
                    print("❌ Anonymous sign-in error: User not found")
                    let fallbackArticles = self?.provideFallbackArticles(for: language, originalError: error)
                    completion(.success(fallbackArticles ?? []))
                    return
                }
                
                print("✅ Successfully signed in anonymously with UID: \(user.uid)")
                
                user.getIDToken { [weak self] (token, error) in
                    if let error = error {
                        print("❌ Token error after anonymous sign-in: \(error.localizedDescription)")
                        let fallbackArticles = self?.provideFallbackArticles(for: language, originalError: error)
                        completion(.success(fallbackArticles ?? []))
                        return
                    }
                    
                    guard let token = token else {
                        let error = NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ID token not found."])
                        print("❌ Token error after anonymous sign-in: ID token not found")
                        let fallbackArticles = self?.provideFallbackArticles(for: language, originalError: error)
                        completion(.success(fallbackArticles ?? []))
                        return
                    }
                    
                    print("✅ Got ID Token. Ready to call backend.")
                    
                    // Call the getNews function with language and country parameters
                    self?.callGetNewsFunction(token: token, language: languageCode, country: countryCode) { result in
                        switch result {
                        case .success(let articles):
                            completion(.success(articles))
                        case .failure(let error):
                            // If API call fails, provide fallback articles
                            let fallbackArticles = self?.provideFallbackArticles(for: language, originalError: error)
                            completion(.success(fallbackArticles ?? []))
                        }
                    }
                }
            }
        }
    }
    
    /// Provides fallback articles when the API call fails
    private func provideFallbackArticles(for language: String, originalError: Error, completion: @escaping (Result<[NewsArticle], Error>) -> Void) {
        print("ℹ️ Providing fallback articles due to API error: \(originalError.localizedDescription)")
        
        // Create fallback articles based on language
        var fallbackArticles: [NewsArticle] = []
        
        switch language.lowercased() {
        case "spanish":
            fallbackArticles = [
                NewsArticle(title: "Barcelona anuncia nuevo parque sostenible", 
                           link: "https://www.noticias-barcelona.es/parque-sostenible", 
                           description: "La ciudad de Barcelona ha anunciado la creación de un nuevo parque urbano que utilizará tecnologías sostenibles."),
                NewsArticle(title: "Madrid celebra festival de cine internacional", 
                           link: "https://www.cultura-madrid.es/festival-cine", 
                           description: "El festival de cine de Madrid atrae a directores y actores de todo el mundo este fin de semana.")
            ]
        case "french":
            fallbackArticles = [
                NewsArticle(title: "Paris accueille les Jeux Olympiques 2024", 
                           link: "https://www.actualites-paris.fr/jeux-olympiques", 
                           description: "La capitale française se prépare pour accueillir des milliers d'athlètes du monde entier."),
                NewsArticle(title: "Nouveau record de visiteurs au Louvre", 
                           link: "https://www.culture-france.fr/louvre-visiteurs", 
                           description: "Le musée du Louvre a enregistré un nombre record de visiteurs ce trimestre.")
            ]
        case "japanese":
            fallbackArticles = [
                NewsArticle(title: "東京で新しい技術展示会が開催", 
                           link: "https://www.tech-news.jp/tokyo-expo", 
                           description: "最新のテクノロジーを紹介する展示会が東京で開催され、多くの来場者が訪れています。"),
                NewsArticle(title: "日本の伝統工芸が海外で人気に", 
                           link: "https://www.culture-japan.jp/traditional-crafts", 
                           description: "日本の伝統的な工芸品が海外市場で高い評価を受けています。特に若い世代に注目されています。")
            ]
        default:
            fallbackArticles = [
                NewsArticle(title: "New AI Technology Breakthrough", 
                           link: "https://www.tech-news.com/ai-breakthrough", 
                           description: "Scientists have announced a major breakthrough in artificial intelligence technology."),
                NewsArticle(title: "Global Climate Initiative Launched", 
                           link: "https://www.world-news.com/climate-initiative", 
                           description: "World leaders have launched a new initiative to combat climate change.")
            ]
        }
        
        // Note: If you want to still show the original error in the UI, you can pass it through
        // if let error = originalError {
        //     completion(.failure(error))
        // }
        
        // Or if you prefer to have the app continue working with fallback content:
        completion(.success(fallbackArticles))
    }

    private func provideFallbackArticles(for language: String, originalError: Error) -> [NewsArticle] {
        print("ℹ️ Providing fallback articles due to API error: \(originalError.localizedDescription)")
        
        // Create fallback articles based on language
        var fallbackArticles: [NewsArticle] = []
        
        switch language.lowercased() {
        case "spanish":
            fallbackArticles = [
                NewsArticle(title: "Barcelona anuncia nuevo parque sostenible", 
                           link: "https://www.noticias-barcelona.es/parque-sostenible", 
                           description: "La ciudad de Barcelona ha anunciado la creación de un nuevo parque urbano que utilizará tecnologías sostenibles."),
                NewsArticle(title: "Madrid celebra festival de cine internacional", 
                           link: "https://www.cultura-madrid.es/festival-cine", 
                           description: "El festival de cine de Madrid atrae a directores y actores de todo el mundo este fin de semana.")
            ]
        case "french":
            fallbackArticles = [
                NewsArticle(title: "Paris accueille les Jeux Olympiques 2024", 
                           link: "https://www.actualites-paris.fr/jeux-olympiques", 
                           description: "La capitale française se prépare pour accueillir des milliers d'athlètes du monde entier."),
                NewsArticle(title: "Nouveau record de visiteurs au Louvre", 
                           link: "https://www.culture-france.fr/louvre-visiteurs", 
                           description: "Le musée du Louvre a enregistré un nombre record de visiteurs ce trimestre.")
            ]
        case "japanese":
            fallbackArticles = [
                NewsArticle(title: "東京で新しい技術展示会が開催", 
                           link: "https://www.tech-news.jp/tokyo-expo", 
                           description: "最新のテクノロジーを紹介する展示会が東京で開催され、多くの来場者が訪れています。"),
                NewsArticle(title: "日本の伝統工芸が海外で人気に", 
                           link: "https://www.culture-japan.jp/traditional-crafts", 
                           description: "日本の伝統的な工芸品が海外市場で高い評価を受けています。特に若い世代に注目されています。")
            ]
        default:
            fallbackArticles = [
                NewsArticle(title: "New AI Technology Breakthrough", 
                           link: "https://www.tech-news.com/ai-breakthrough", 
                           description: "Scientists have announced a major breakthrough in artificial intelligence technology."),
                NewsArticle(title: "Global Climate Initiative Launched", 
                           link: "https://www.world-news.com/climate-initiative", 
                           description: "World leaders have launched a new initiative to combat climate change.")
            ]
        }
        
        // Note: If you want to still show the original error in the UI, you can pass it through
        // if let error = originalError {
        //     completion(.failure(error))
        // }
        
        // Or if you prefer to have the app continue working with fallback content:
        return fallbackArticles
    }

    private func callGetNewsFunction(token: String, language: String, country: String, completion: @escaping (Result<[NewsArticle], Error>) -> Void) {
        // Using the deployed cloud function URL with both required parameters
        guard let url = URL(string: "https://getnews-64vohpb5ra-uc.a.run.app?language=\(language)&country=\(country)") else {
            completion(.failure(NSError(domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("📘 Fetching news for language: \(language), country: \(country)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Add the token to the Authorization header
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Set a longer timeout for slower connections
        request.timeoutInterval = 30
        
        // Check if we're using Firebase emulator
        let usingEmulator = UserDefaults.standard.bool(forKey: "use_firebase_emulator")
        
        // Add a debugging header to help diagnose issues
        #if DEBUG
        request.setValue(usingEmulator ? "emulator" : "production", forHTTPHeaderField: "X-Idioma-Environment")
        #endif

        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(.failure(NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            print("📘 API response status: \(httpResponse.statusCode)")
            
            // Log response headers in debug mode
            #if DEBUG
            print("📘 Response headers: \(httpResponse.allHeaderFields)")
            #endif
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = "Server returned status \(httpResponse.statusCode)"
                
                // Try to parse error message from response body if available
                if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    print("❌ API error: \(errorMessage)")
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, 
                                               userInfo: [NSLocalizedDescriptionKey: "\(message): \(errorMessage)"])))
                } else {
                    print("❌ API error: \(message)")
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, 
                                               userInfo: [NSLocalizedDescriptionKey: message])))
                }
                return
            }

            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "NetworkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Log received data in debug mode
            #if DEBUG
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📘 Received JSON: \(jsonString)")
            }
            #endif

            do {
                // Decode the JSON response
                let apiResponse = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
                print("✅ Successfully fetched \(apiResponse.results.count) news articles")
                DispatchQueue.main.async {
                    completion(.success(apiResponse.results))
                }
            } catch {
                print("❌ JSON decoding error: \(error.localizedDescription)")
                
                #if DEBUG
                // In debug builds, provide more detailed error information
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("Key not found: \(key.stringValue), \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch: \(type), \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found: \(type), \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                
                // Attempt to decode with a more lenient approach
                do {
                    // Try parsing just the 'results' array directly
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let resultsArray = json["results"] as? [[String: Any]] {
                        print("✅ Falling back to manual parsing: Found \(resultsArray.count) articles")
                    }
                } catch {
                    print("❌ Manual parsing failed: \(error.localizedDescription)")
                }
                #endif
                
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Extracts the main content from an article URL
    func extractArticle(articleUrl: String, completion: @escaping (Result<ExtractedArticle, Error>) -> Void) {
        // Check if we have a valid URL before proceeding
        guard !articleUrl.isEmpty, articleUrl != " " else {
            let error = NSError(domain: "ArticleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Article URL is empty or invalid"])
            print("❌ Error: Empty or invalid article URL")
            
            // Create a fallback article
            let fallbackArticle = ExtractedArticle(
                title: "Untitled",
                content: "<p>Unable to extract article content. The article URL is empty or invalid.</p>",
                byline: nil,
                siteName: nil,
                excerpt: nil,
                textContent: "Unable to extract article content. The article URL is empty or invalid.",
                images: nil,
                leadImageUrl: nil
            )
            completion(.success(fallbackArticle))
            return
        }
        
        guard let url = URL(string: "https://extractarticle-64vohpb5ra-uc.a.run.app") else {
            let error = NSError(domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid extraction URL"])
            print("❌ Error creating URL: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        print("📘 Extracting article from URL: \(articleUrl)")
        
        // Get the auth token
        auth.currentUser?.getIDToken { (token, error) in
            if let error = error {
                print("❌ Token error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let token = token else {
                let error = NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ID token not found."])
                print("❌ Token error: ID token not found")
                completion(.failure(error))
                return
            }
            
            // Create request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Set a longer timeout for article extraction
            request.timeoutInterval = 30
            
            // Create request body
            let body: [String: Any] = ["url": articleUrl]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                print("❌ JSON serialization error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("❌ Network error during extraction: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    print("❌ Invalid response type")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                print("📘 Article extraction status: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = "Server returned status \(httpResponse.statusCode)"
                    
                    // Try to get error details from the response
                    if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        print("❌ Article extraction error: \(errorMessage)")
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, 
                                                      userInfo: [NSLocalizedDescriptionKey: "\(message): \(errorMessage)"])))
                        }
                    } else {
                        print("❌ Article extraction error: \(message)")
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, 
                                                      userInfo: [NSLocalizedDescriptionKey: message])))
                        }
                    }
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    print("❌ No data received")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                do {
                    let extractedArticle = try JSONDecoder().decode(ExtractedArticle.self, from: data)
                    print("✅ Successfully extracted article: \(extractedArticle.title)")
                    DispatchQueue.main.async {
                        completion(.success(extractedArticle))
                    }
                } catch {
                    print("❌ JSON decoding error: \(error.localizedDescription)")
                    if let responseStr = String(data: data, encoding: .utf8) {
                        print("📘 Raw response: \(responseStr.prefix(200))...")
                    }
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
            
            task.resume()
        }
    }
    
    /// Simplifies an article's content
    /// Records that a user has read an article, useful for tracking achievements and reading history
    func recordArticleRead(articleId: String, title: String, language: String, difficulty: String? = nil) {
        // Store reading data in UserDefaults for now (could be moved to Firestore later)
        let defaults = UserDefaults.standard
        
        // Get current reading history or initialize new
        var readArticleIds = defaults.array(forKey: "read_article_ids") as? [String] ?? []
        var readArticlesByLanguage = defaults.dictionary(forKey: "read_articles_by_language") as? [String: [String]] ?? [:]
        var readDates = defaults.array(forKey: "read_dates") as? [String] ?? []
        
        // Format today's date as string for streak tracking
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        // Update the data
        if !readArticleIds.contains(articleId) {
            readArticleIds.append(articleId)
            
            // Update language-specific history
            if var articlesForLanguage = readArticlesByLanguage[language] {
                articlesForLanguage.append(articleId)
                readArticlesByLanguage[language] = articlesForLanguage
            } else {
                readArticlesByLanguage[language] = [articleId]
            }
            
            // Record read date
            if !readDates.contains(today) {
                readDates.append(today)
            }
            
            // Save updated data
            defaults.set(readArticleIds, forKey: "read_article_ids")
            defaults.set(readArticlesByLanguage, forKey: "read_articles_by_language")
            defaults.set(readDates, forKey: "read_dates")
            
            // Log for debugging
            print("✅ Recorded article read: \(title) (\(language))")
            print("📊 User has read \(readArticleIds.count) articles total")
            print("📊 User has read \(readArticlesByLanguage[language]?.count ?? 0) \(language) articles")
            print("📊 User has read articles on \(readDates.count) different days")
        }
    }

    func simplifyArticleFromUrl(articleUrl: String, language: String, originalContent: String, completion: @escaping (Result<SimplifiedArticle, Error>) -> Void) {
        guard let url = URL(string: "https://simplifyarticle-64vohpb5ra-uc.a.run.app") else {
            let error = NSError(domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid simplification URL"])
            print("❌ Error creating URL: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        print("📘 Simplifying article from URL: \(articleUrl) for language: \(language)")
        
        // Get the auth token
        auth.currentUser?.getIDToken { (token, error) in
            if let error = error {
                print("❌ Token error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let token = token else {
                let error = NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ID token not found."])
                print("❌ Token error: ID token not found")
                completion(.failure(error))
                return
            }
            
            // Create request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            // Set a longer timeout for simplification (it might take time)
            request.timeoutInterval = 60
            
            // Map language to proper language code
            let languageCode: String
            switch language.lowercased() {
            case "united states", "english", "en":
                languageCode = "en"
            case "spain", "spanish", "es":
                languageCode = "es"
            case "france", "french", "fr":
                languageCode = "fr"
            case "japan", "japanese", "ja":
                languageCode = "ja"
            default:
                languageCode = language.lowercased()
            }
            
            // Create request body with URL and proper language code
            let body: [String: Any] = ["url": articleUrl, "language": languageCode]
            
            print("📘 Sending simplification request with body: \(body)")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                print("❌ JSON serialization error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("❌ Network error during simplification: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    print("❌ Invalid response type")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                print("📘 Simplification status: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = "Server returned status \(httpResponse.statusCode)"
                    
                    // Try to get error details from the response
                    if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        print("❌ Simplification error: \(errorMessage)")
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, 
                                                      userInfo: [NSLocalizedDescriptionKey: "\(message): \(errorMessage)"])))
                        }
                    } else {
                        print("❌ Simplification error: \(message)")
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, 
                                                      userInfo: [NSLocalizedDescriptionKey: message])))
                        }
                    }
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    print("❌ No data received")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                // First, let's see what we actually received
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("📘 Simplification API raw response: \(responseStr.prefix(500))...")
                }
                
                do {
                    // Try to parse the API response
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📘 Parsed JSON keys: \(Array(jsonResponse.keys))")
                        
                        // Try different possible response formats
                        var simplifiedText: String?
                        var cefrLevel: String?
                        
                        // Format 1: {simplified: "text", cefrLevel: "A2"}
                        if let simplified = jsonResponse["simplified"] as? String {
                            simplifiedText = simplified
                            cefrLevel = jsonResponse["cefrLevel"] as? String
                        }
                        // Format 2: {simplifiedHtml: "text", cefrLevel: "A2"}
                        else if let simplifiedHtml = jsonResponse["simplifiedHtml"] as? String {
                            // Clean up HTML content for better display
                            simplifiedText = self.cleanHtmlContent(simplifiedHtml)
                            cefrLevel = jsonResponse["cefrLevel"] as? String
                        }
                        // Format 3: {content: "text", level: "A2"}
                        else if let simplified = jsonResponse["content"] as? String {
                            simplifiedText = simplified
                            cefrLevel = jsonResponse["level"] as? String
                        }
                        // Format 4: Direct text response
                        else if let simplified = jsonResponse["text"] as? String {
                            simplifiedText = simplified
                        }
                        
                        if let simplifiedText = simplifiedText {
                            // Create SimplifiedArticle with original content
                            let simplifiedArticle = SimplifiedArticle(
                                original: originalContent,
                                simplified: simplifiedText,
                                language: language,
                                cefrLevel: cefrLevel
                            )
                            
                            print("✅ Successfully simplified article content (CEFR: \(cefrLevel ?? "Unknown"))")
                            print("📘 Simplified content preview: \(simplifiedText.prefix(200))...")
                            DispatchQueue.main.async {
                                completion(.success(simplifiedArticle))
                            }
                        } else {
                            print("❌ No recognized simplified text field found in response")
                            print("📘 Available fields: \(jsonResponse.keys)")
                            
                            // As a fallback, return the original content as "simplified"
                            let fallbackArticle = SimplifiedArticle(
                                original: originalContent,
                                simplified: originalContent,
                                language: language,
                                cefrLevel: nil
                            )
                            
                            print("⚠️ Using original content as simplified version (fallback)")
                            DispatchQueue.main.async {
                                completion(.success(fallbackArticle))
                            }
                        }
                    } else {
                        // If it's not JSON, maybe it's plain text?
                        if let responseStr = String(data: data, encoding: .utf8), !responseStr.isEmpty {
                            let simplifiedArticle = SimplifiedArticle(
                                original: originalContent,
                                simplified: responseStr,
                                language: language,
                                cefrLevel: nil
                            )
                            
                            print("✅ Using plain text response as simplified content")
                            DispatchQueue.main.async {
                                completion(.success(simplifiedArticle))
                            }
                        } else {
                            let error = NSError(domain: "ParseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to parse response"])
                            print("❌ Unable to parse response as JSON or text")
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                } catch {
                    print("❌ JSON parsing error: \(error.localizedDescription)")
                    
                    // Try as plain text fallback
                    if let responseStr = String(data: data, encoding: .utf8), !responseStr.isEmpty {
                        let simplifiedArticle = SimplifiedArticle(
                            original: originalContent,
                            simplified: responseStr,
                            language: language,
                            cefrLevel: nil
                        )
                        
                        print("✅ Using response text as simplified content (fallback)")
                        DispatchQueue.main.async {
                            completion(.success(simplifiedArticle))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            }
            
            task.resume()
        }
    }
    
    func simplifyArticle(content: String, language: String, completion: @escaping (Result<SimplifiedArticle, Error>) -> Void) {
        // Create SimplifiedArticle directly with content (fallback implementation)
        let simplifiedArticle = SimplifiedArticle(
            original: content,
            simplified: content, // Same as original if we can't simplify
            language: language,
            cefrLevel: nil
        )
        
        print("⚠️ Using fallback simplification (returning original content)")
        completion(.success(simplifiedArticle))
    }
    
    /// Cleans HTML content by removing tags and formatting for better readability
    private func cleanHtmlContent(_ htmlString: String) -> String {
        // First, try to use NSAttributedString to parse HTML (iOS built-in)
        if let data = htmlString.data(using: .utf8) {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                let cleanText = attributedString.string
                
                // Clean up extra whitespace and newlines
                let trimmed = cleanText
                    .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return trimmed.isEmpty ? htmlString : trimmed
            }
        }
        
        // Fallback: Simple HTML tag removal
        var cleanText = htmlString
        
        // Replace common HTML tags with appropriate formatting
        cleanText = cleanText.replacingOccurrences(of: "<br>", with: "\n")
        cleanText = cleanText.replacingOccurrences(of: "<br/>", with: "\n")
        cleanText = cleanText.replacingOccurrences(of: "<br />", with: "\n")
        cleanText = cleanText.replacingOccurrences(of: "</p>", with: "\n\n")
        cleanText = cleanText.replacingOccurrences(of: "</div>", with: "\n")
        
        // Remove all remaining HTML tags
        cleanText = cleanText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Clean up extra whitespace
        cleanText = cleanText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: "\n ", with: "\n", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: " \n", with: "\n", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        
        return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
