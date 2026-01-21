//
//  IdiomaApp.swift
//  Idioma
//
//  Main entry point for the Idioma iOS application.
//  This file sets up the app and determines the initial view based on auth state.
//

import SwiftUI
import FirebaseCore

// App Delegate for Firebase configuration
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct IdiomaApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
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
