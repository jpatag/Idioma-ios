//
//  Language.swift
//  Idioma
//
//  Model for supported languages in the app.
//  Used in language selection and settings.
//

import Foundation

// MARK: - Language
struct Language: Identifiable, Hashable {
    let id: String           // Language code (e.g., "es", "fr")
    let name: String         // English name (e.g., "Spanish")
    let nativeName: String   // Native name (e.g., "Español")
    let flagEmoji: String    // Flag emoji for display
    let region: String       // Region category for filtering
    
    // Predefined list of supported languages
    static let allLanguages: [Language] = [
        Language(id: "es", name: "Spanish", nativeName: "Español", flagEmoji: "🇪🇸", region: "Europe"),
        Language(id: "fr", name: "French", nativeName: "Français", flagEmoji: "🇫🇷", region: "Europe"),
        Language(id: "de", name: "German", nativeName: "Deutsch", flagEmoji: "🇩🇪", region: "Europe"),
        Language(id: "it", name: "Italian", nativeName: "Italiano", flagEmoji: "🇮🇹", region: "Europe"),
        Language(id: "pt", name: "Portuguese", nativeName: "Português", flagEmoji: "🇵🇹", region: "Europe"),
        Language(id: "ja", name: "Japanese", nativeName: "日本語", flagEmoji: "🇯🇵", region: "Asia"),
        Language(id: "ko", name: "Korean", nativeName: "한국어", flagEmoji: "🇰🇷", region: "Asia"),
        Language(id: "zh", name: "Chinese", nativeName: "中文", flagEmoji: "🇨🇳", region: "Asia"),
        Language(id: "ru", name: "Russian", nativeName: "Русский", flagEmoji: "🇷🇺", region: "Europe"),
        Language(id: "ar", name: "Arabic", nativeName: "العربية", flagEmoji: "🇸🇦", region: "Other"),
    ]
    
    // Popular languages for quick access
    static let popularLanguages: [Language] = [
        allLanguages[0], // Spanish
        allLanguages[1], // French
        allLanguages[2], // German
        allLanguages[5], // Japanese
    ]
    
    // Get languages by region
    static func languages(for region: String) -> [Language] {
        if region == "Popular" {
            return popularLanguages
        } else if region == "All" {
            return allLanguages
        }
        return allLanguages.filter { $0.region == region }
    }
    
    // Available regions
    static let regions = ["Popular", "Europe", "Asia", "All"]
}

// MARK: - Country
// Country codes for news API (maps to language)
struct Country {
    let code: String      // Country code (e.g., "us", "es")
    let name: String      // Country name
    
    // Default countries for each language
    static func defaultCountry(for languageCode: String) -> String {
        switch languageCode {
        case "es": return "es"  // Spain
        case "fr": return "fr"  // France
        case "de": return "de"  // Germany
        case "it": return "it"  // Italy
        case "pt": return "pt"  // Portugal
        case "ja": return "jp"  // Japan
        case "ko": return "kr"  // South Korea
        case "zh": return "cn"  // China
        case "ru": return "ru"  // Russia
        case "ar": return "sa"  // Saudi Arabia
        default: return "us"    // Default to US
        }
    }
}
