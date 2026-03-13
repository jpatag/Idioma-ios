//
//  APIService.swift
//  Idioma
//
//  Service for making API calls to the Firebase backend.
//  Handles all network requests for news, article extraction, and simplification.
//

import Foundation

// MARK: - API Service
class APIService {
    // Singleton instance for easy access throughout the app
    static let shared = APIService()
    
    // ⚠️ IMPORTANT: Replace with your actual Firebase Functions URL
    // Find this in your Firebase Console > Functions > Dashboard
    // It should look like: https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net
    private let baseURL = "https://us-central1-idioma-87bed.cloudfunctions.net"
    
    // Private init for singleton
    private init() {}
    
    // MARK: - Get News Articles
    /// Fetches news articles for a specific country and language
    /// - Parameters:
    ///   - country: Country code (e.g., "es" for Spain)
    ///   - language: Language code (e.g., "es" for Spanish)
    ///   - categories: Array of Idioma category ids (1–14)
    /// - Returns: Array of Article objects
    func getNews(country: String, language: String, categories: [Int] = []) async throws -> [Article] {
        print("\n🗕 [API] getNews called")
        print("📍 Parameters: country=\(country), language=\(language), categories=\(categories)")
        
        // Build the URL with query parameters
        var components = URLComponents(string: "\(baseURL)/getNews")!
        var queryItems = [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "language", value: language)
        ]
        
        if !categories.isEmpty {
            let categoriesStr = categories.map { String($0) }.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "categories", value: categoriesStr))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            print("❌ [API] Invalid URL")
            throw APIError.invalidURL
        }
        
        print("🌐 [API] Request URL: \(url.absoluteString)")
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        print("📦 [API] Response received - Data size: \(data.count) bytes")
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [API] Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("📊 [API] HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [API] HTTP Error: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 [API] Error response body: \(responseString)")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Decode the response
        let decoder = JSONDecoder()
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [API] Raw response (first 500 chars): \(String(responseString.prefix(500)))")
        }
        
        // Try to decode as NewsResponse first (has "results" key)
        if let newsResponse = try? decoder.decode(NewsResponse.self, from: data) {
            print("✅ [API] Successfully decoded NewsResponse with \(newsResponse.results.count) articles")
            newsResponse.results.forEach { article in
                print("   📰 Article: \(article.title ?? "No title")")
            }
            return newsResponse.results
        }
        
        // Fallback: try to decode direct array
        if let articles = try? decoder.decode([Article].self, from: data) {
            print("✅ [API] Successfully decoded article array with \(articles.count) articles")
            return articles
        }
        
        print("❌ [API] Failed to decode response as NewsResponse or [Article]")
        throw APIError.decodingError
    }
    
    // MARK: - Extract Article Content
    /// Extracts and cleans article content from a URL
    /// - Parameter url: The article URL to extract content from
    /// - Returns: ArticleContent with cleaned HTML and metadata
    func extractArticle(url: String) async throws -> ArticleContent {
        print("\n🔵 [API] extractArticle called")
        print("📍 URL: \(url)")
        
        var components = URLComponents(string: "\(baseURL)/extractArticle")!
        components.queryItems = [
            URLQueryItem(name: "url", value: url)
        ]
        
        guard let requestURL = components.url else {
            print("❌ [API] Invalid URL")
            throw APIError.invalidURL
        }
        
        print("🌐 [API] Request URL: \(requestURL.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: requestURL)
        
        print("📦 [API] Response received - Data size: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [API] Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("📊 [API] HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [API] HTTP Error: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 [API] Error response: \(responseString)")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let content = try decoder.decode(ArticleContent.self, from: data)
        print("✅ [API] Successfully extracted article: \(content.title ?? "No title")")
        return content
    }
    
    // MARK: - Simplify Article
    /// Simplifies article content for a specific CEFR level
    /// - Parameters:
    ///   - url: The article URL (must have been extracted first)
    ///   - level: CEFR level (A2, B1, B2, C1)
    ///   - language: Target language code (e.g., "es" for Spanish) to keep article in original language
    /// - Returns: SimplifiedArticle with adapted content
    func simplifyArticle(url: String, level: CEFRLevel, language: String? = nil) async throws -> SimplifiedArticle {
        print("\n🔵 [API] simplifyArticle called")
        print("📍 URL: \(url), Level: \(level.rawValue), Language: \(language ?? "not specified")")
        
        var components = URLComponents(string: "\(baseURL)/simplifyArticle")!
        var queryItems = [
            URLQueryItem(name: "url", value: url),
            URLQueryItem(name: "level", value: level.rawValue),
            URLQueryItem(name: "stream", value: "false") // Non-streaming for simplicity
        ]
        
        // Add language parameter if provided to keep article in original language
        if let language = language {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        components.queryItems = queryItems
        
        guard let requestURL = components.url else {
            print("❌ [API] Invalid URL")
            throw APIError.invalidURL
        }
        
        print("🌐 [API] Request URL: \(requestURL.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: requestURL)
        
        print("📦 [API] Response received - Data size: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [API] Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("📊 [API] HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [API] HTTP Error: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 [API] Error response: \(responseString)")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let simplified = try decoder.decode(SimplifiedArticle.self, from: data)
        print("✅ [API] Successfully simplified article")
        return simplified
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "Server error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
