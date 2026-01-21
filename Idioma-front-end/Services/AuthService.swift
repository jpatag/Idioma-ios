//
//  AuthService.swift
//  Idioma
//
//  Authentication service for handling user login/logout.
//  Currently uses a simple mock implementation.
//  Replace with Firebase Auth for production.
//

import Foundation
import SwiftUI

// MARK: - Auth Service
class AuthService: ObservableObject {
    // Published properties that update the UI automatically
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasCompletedOnboarding: Bool = false
    
    // User preferences stored locally
    @Published var preferences = UserPreferences()
    
    init() {
        // Check if user was previously logged in
        checkAuthState()
    }
    
    // MARK: - Check Auth State
    /// Checks if user was previously logged in (from UserDefaults)
    private func checkAuthState() {
        // In production, check Firebase Auth state here
        let wasLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if wasLoggedIn {
            // Restore user session
            isAuthenticated = true
            hasCompletedOnboarding = preferences.hasCompletedOnboarding
            
            // Create a mock user for now
            currentUser = User(
                id: "mock-user-id",
                email: UserDefaults.standard.string(forKey: "userEmail") ?? "user@example.com",
                displayName: UserDefaults.standard.string(forKey: "userName") ?? "User",
                profileImageUrl: nil,
                nativeLanguage: preferences.nativeLanguage,
                targetLanguage: preferences.targetLanguage,
                preferredLevel: preferences.preferredLevel,
                notificationsEnabled: preferences.notificationsEnabled,
                darkModeEnabled: preferences.darkModeEnabled
            )
        }
    }
    
    // MARK: - Sign In with Google
    /// Signs in with Google (placeholder - implement with Firebase)
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Mock successful login
            self.currentUser = User(
                id: "google-user-123",
                email: "user@gmail.com",
                displayName: "Google User",
                profileImageUrl: nil,
                nativeLanguage: "en",
                targetLanguage: "es",
                preferredLevel: "B1",
                notificationsEnabled: true,
                darkModeEnabled: false
            )
            
            // Save login state
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            UserDefaults.standard.set(self.currentUser?.email, forKey: "userEmail")
            UserDefaults.standard.set(self.currentUser?.displayName, forKey: "userName")
            
            self.isAuthenticated = true
            self.hasCompletedOnboarding = self.preferences.hasCompletedOnboarding
            self.isLoading = false
        }
        
        // TODO: Replace with actual Firebase Google Sign-In
        // 1. Add Firebase SDK to your project
        // 2. Add GoogleSignIn SDK
        // 3. Configure in GoogleService-Info.plist
        // 4. Use GIDSignIn.sharedInstance.signIn(...)
    }
    
    // MARK: - Sign In with Email
    /// Signs in with email and password (placeholder - implement with Firebase)
    func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        // Basic validation
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            isLoading = false
            return
        }
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Mock successful login
            self.currentUser = User(
                id: "email-user-456",
                email: email,
                displayName: email.components(separatedBy: "@").first ?? "User",
                profileImageUrl: nil,
                nativeLanguage: "en",
                targetLanguage: "es",
                preferredLevel: "B1",
                notificationsEnabled: true,
                darkModeEnabled: false
            )
            
            // Save login state
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            UserDefaults.standard.set(email, forKey: "userEmail")
            UserDefaults.standard.set(self.currentUser?.displayName, forKey: "userName")
            
            self.isAuthenticated = true
            self.hasCompletedOnboarding = self.preferences.hasCompletedOnboarding
            self.isLoading = false
        }
        
        // TODO: Replace with Firebase Auth
        // Auth.auth().signIn(withEmail: email, password: password) { result, error in ... }
    }
    
    // MARK: - Sign Out
    /// Signs out the current user
    func signOut() {
        // Clear user data
        currentUser = nil
        isAuthenticated = false
        
        // Clear stored login state
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userName")
        
        // TODO: Replace with Firebase Auth
        // try? Auth.auth().signOut()
    }
    
    // MARK: - Complete Onboarding
    /// Called when user finishes language selection
    func completeOnboarding(targetLanguage: String) {
        preferences.targetLanguage = targetLanguage
        preferences.hasCompletedOnboarding = true
        hasCompletedOnboarding = true
        
        // Update current user
        currentUser?.targetLanguage = targetLanguage
    }
    
    // MARK: - Update Preferences
    /// Updates user preferences
    func updatePreferences(nativeLanguage: String? = nil, targetLanguage: String? = nil, level: String? = nil) {
        if let native = nativeLanguage {
            preferences.nativeLanguage = native
            currentUser?.nativeLanguage = native
        }
        if let target = targetLanguage {
            preferences.targetLanguage = target
            currentUser?.targetLanguage = target
        }
        if let level = level {
            preferences.preferredLevel = level
            currentUser?.preferredLevel = level
        }
    }
}
