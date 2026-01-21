//
//  IdiomaApp.swift
//  Idioma
//
//  Main entry point for the Idioma iOS application.
//  This file sets up the app and determines the initial view based on auth state.
//

import SwiftUI

@main
struct IdiomaApp: App {
    // StateObject keeps the AuthService alive for the entire app lifecycle
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            // Show different views based on authentication state
            if authService.isAuthenticated {
                // User is logged in - show main app
                if authService.hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(authService)
                } else {
                    // First time user - show language selection
                    LanguageSelectionView()
                        .environmentObject(authService)
                }
            } else {
                // User not logged in - show login screen
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}
