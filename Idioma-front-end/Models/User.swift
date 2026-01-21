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

// MARK: - User Preferences (stored locally)
class UserPreferences: ObservableObject {
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let nativeLanguage = "nativeLanguage"
        static let targetLanguage = "targetLanguage"
        static let preferredLevel = "preferredLevel"
        static let notificationsEnabled = "notificationsEnabled"
        static let darkModeEnabled = "darkModeEnabled"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
    
    @Published var nativeLanguage: String {
        didSet { defaults.set(nativeLanguage, forKey: Keys.nativeLanguage) }
    }
    
    @Published var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }
    
    @Published var preferredLevel: String {
        didSet { defaults.set(preferredLevel, forKey: Keys.preferredLevel) }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    
    @Published var darkModeEnabled: Bool {
        didSet { defaults.set(darkModeEnabled, forKey: Keys.darkModeEnabled) }
    }
    
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }
    
    init() {
        // Load saved preferences or use defaults
        self.nativeLanguage = defaults.string(forKey: Keys.nativeLanguage) ?? "en"
        self.targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "es"
        self.preferredLevel = defaults.string(forKey: Keys.preferredLevel) ?? "B1"
        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        self.darkModeEnabled = defaults.bool(forKey: Keys.darkModeEnabled)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
}
