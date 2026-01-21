//
//  User.swift
//  Idioma
//
//  User model for storing user preferences and profile data.
//

import Foundation

// MARK: - User
struct User: Codable {
    var id: String
    var email: String
    var displayName: String
    var profileImageUrl: String?
    
    // Language preferences
    var nativeLanguage: String      // e.g., "en" for English
    var targetLanguage: String      // e.g., "es" for Spanish
    var preferredLevel: String      // CEFR level: A2, B1, B2, C1
    
    // App preferences
    var notificationsEnabled: Bool
    var darkModeEnabled: Bool
    
    // Default user for new accounts
    static var defaultUser: User {
        User(
            id: "",
            email: "",
            displayName: "New User",
            profileImageUrl: nil,
            nativeLanguage: "en",
            targetLanguage: "es",
            preferredLevel: "B1",
            notificationsEnabled: true,
            darkModeEnabled: false
        )
    }
}
