//
//  Article.swift
//  Idioma
//
//  Data models for articles from the backend API.
//  These match the structure returned by getNews and extractArticle endpoints.
//

import Foundation

// MARK: - News API Response
// Response from the getNews endpoint
struct NewsResponse: Codable {
    let results: [Article]
    let nextPage: String?
}

// MARK: - Article
// Represents a news article from the feed
struct Article: Codable, Identifiable {
    // Use article_id from API, or generate UUID if missing
    var id: String { article_id ?? UUID().uuidString }
    
    let article_id: String?
    let title: String?
    let link: String?
    let description: String?
    let content: String?
    let pubDate: String?
    let image_url: String?
    let source_id: String?
    let source_name: String?
    let source_url: String?
    let source_icon: String?
    let language: String?
    let country: [String]?
    let category: [String]?
    
    // Computed property for display-friendly date
    var formattedDate: String {
        guard let pubDate = pubDate else { return "Unknown date" }
        // Simple formatting - just return as-is for now
        // You can enhance this with DateFormatter
        return pubDate
    }
    
    // Computed property for source display
    var sourceDisplay: String {
        return source_name ?? source_id ?? "Unknown source"
    }
}

// MARK: - Article Content
// Full article content from extractArticle endpoint
struct ArticleContent: Codable {
    let url: String
    let title: String?
    let byline: String?
    let siteName: String?
    let contentHtml: String?
    let llmHtml: String?
    let textContent: String?
    let leadImageUrl: String?
    let images: [String]?
}

// MARK: - Simplified Article
// Response from simplifyArticle endpoint
struct SimplifiedArticle: Codable {
    let originalUrl: String
    let cefrLevel: String
    let title: String?
    let byline: String?
    let siteName: String?
    let simplifiedHtml: String?
    let leadImageUrl: String?
    let images: [String]?
    let tokensUsed: Int?
}

// MARK: - CEFR Level
// Language proficiency levels
enum CEFRLevel: String, CaseIterable {
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    
    var displayName: String {
        switch self {
        case .a2: return "Beginner"
        case .b1: return "Intermediate"
        case .b2: return "Upper Intermediate"
        case .c1: return "Advanced"
        }
    }
    
    // Spanish translations for article view
    var spanishName: String {
        switch self {
        case .a2: return "Principiante"
        case .b1: return "Intermedio"
        case .b2: return "Avanzado"
        case .c1: return "Experto"
        }
    }
}
