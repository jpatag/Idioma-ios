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
    /// - Returns: Array of Article objects
    func getNews(country: String, language: String) async throws -> [Article] {
        // Build the URL with query parameters
        var components = URLComponents(string: "\(baseURL)/getNews")!
        components.queryItems = [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "language", value: language)
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Decode the response
        let decoder = JSONDecoder()
        
        // Try to decode as NewsResponse first (has "results" key)
        if let newsResponse = try? decoder.decode(NewsResponse.self, from: data) {
            return newsResponse.results
        }
        
        // Fallback: try to decode direct array
        if let articles = try? decoder.decode([Article].self, from: data) {
            return articles
        }
        
        throw APIError.decodingError
    }
    
    // MARK: - Extract Article Content
    /// Extracts and cleans article content from a URL
    /// - Parameter url: The article URL to extract content from
    /// - Returns: ArticleContent with cleaned HTML and metadata
    func extractArticle(url: String) async throws -> ArticleContent {
        var components = URLComponents(string: "\(baseURL)/extractArticle")!
        components.queryItems = [
            URLQueryItem(name: "url", value: url)
        ]
        
        guard let requestURL = components.url else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: requestURL)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ArticleContent.self, from: data)
    }
    
    // MARK: - Simplify Article
    /// Simplifies article content for a specific CEFR level
    /// - Parameters:
    ///   - url: The article URL (must have been extracted first)
    ///   - level: CEFR level (A2, B1, B2, C1)
    /// - Returns: SimplifiedArticle with adapted content
    func simplifyArticle(url: String, level: CEFRLevel) async throws -> SimplifiedArticle {
        var components = URLComponents(string: "\(baseURL)/simplifyArticle")!
        components.queryItems = [
            URLQueryItem(name: "url", value: url),
            URLQueryItem(name: "level", value: level.rawValue),
            URLQueryItem(name: "stream", value: "false") // Non-streaming for simplicity
        ]
        
        guard let requestURL = components.url else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: requestURL)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(SimplifiedArticle.self, from: data)
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
