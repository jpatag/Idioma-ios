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
    let idiomaCategoryIds: [Int]?
    
    // Computed property for primary Idioma category display name
    var primaryCategoryName: String? {
        if let ids = idiomaCategoryIds, let first = ids.first,
           let cat = IdiomaCategory.category(for: first) {
            return cat.name
        }
        // Fallback to raw NewsData category if no Idioma id
        return category?.first?.capitalized
    }
    
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
    
    // Map NewsData API language strings to ISO codes
    // NewsData returns full names like "spanish", "french" etc.
    var languageCode: String? {
        guard let lang = language?.lowercased() else { return nil }
        
        let languageMap: [String: String] = [
            "spanish": "es",
            "french": "fr",
            "german": "de",
            "italian": "it",
            "portuguese": "pt",
            "english": "en",
            "chinese": "zh",
            "japanese": "ja",
            "korean": "ko",
            "russian": "ru",
            "arabic": "ar",
            "dutch": "nl",
            "swedish": "sv",
            "norwegian": "no",
            "danish": "da",
            "finnish": "fi",
            "polish": "pl",
            "turkish": "tr",
            "greek": "el",
            "hebrew": "he",
            "hindi": "hi",
            "thai": "th",
            "vietnamese": "vi",
            "indonesian": "id",
            "malay": "ms",
            "tagalog": "tl",
            // If it's already a code (e.g., "es"), return as-is
            "es": "es", "fr": "fr", "de": "de", "it": "it", "pt": "pt",
            "en": "en", "zh": "zh", "ja": "ja", "ko": "ko", "ru": "ru"
        ]
        
        return languageMap[lang] ?? lang
    }
    
    // Get full language name for display and prompts
    var languageName: String? {
        guard let lang = language?.lowercased() else { return nil }
        
        let nameMap: [String: String] = [
            "es": "Spanish", "spanish": "Spanish",
            "fr": "French", "french": "French",
            "de": "German", "german": "German",
            "it": "Italian", "italian": "Italian",
            "pt": "Portuguese", "portuguese": "Portuguese",
            "en": "English", "english": "English",
            "zh": "Chinese", "chinese": "Chinese",
            "ja": "Japanese", "japanese": "Japanese",
            "ko": "Korean", "korean": "Korean",
            "ru": "Russian", "russian": "Russian"
        ]
        
        return nameMap[lang] ?? language?.capitalized
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
    let cacheHit: Bool?
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
    let cacheHit: Bool?
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
        case .b2: return "Advanced"
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

    var vocabularyLevelID: VocabularyLevelID {
        switch self {
        case .a2:
            return .l1
        case .b1:
            return .l2
        case .b2, .c1:
            return .l3
        }
    }
}
