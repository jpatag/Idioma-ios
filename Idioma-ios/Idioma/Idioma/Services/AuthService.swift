//
//  AuthService.swift
//  Idioma
//
//  Authentication service using Firebase Auth + Google Sign-In.
//

import Foundation
import Combine
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

// MARK: - Auth Service
final class AuthService: ObservableObject {
    // Published properties that update the UI
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasCompletedOnboarding: Bool = false
    
    // Firebase Auth listener
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // UserDefaults for preferences
    private let defaults = UserDefaults.standard
    
    // Preference keys
    private enum Keys {
        static let nativeLanguage = "nativeLanguage"
        static let targetLanguage = "targetLanguage"
        static let preferredLevel = "preferredLevel"
        static let notificationsEnabled = "notificationsEnabled"
        static let darkModeEnabled = "darkModeEnabled"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
    
    // Computed preferences properties
    var nativeLanguage: String {
        get { defaults.string(forKey: Keys.nativeLanguage) ?? "en" }
        set { defaults.set(newValue, forKey: Keys.nativeLanguage) }
    }
    
    var targetLanguage: String {
        get { defaults.string(forKey: Keys.targetLanguage) ?? "es" }
        set { defaults.set(newValue, forKey: Keys.targetLanguage) }
    }
    
    var preferredLevel: String {
        get { defaults.string(forKey: Keys.preferredLevel) ?? "B1" }
        set { defaults.set(newValue, forKey: Keys.preferredLevel) }
    }
    
    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }
    
    var darkModeEnabled: Bool {
        get { defaults.bool(forKey: Keys.darkModeEnabled) }
        set { defaults.set(newValue, forKey: Keys.darkModeEnabled) }
    }
    
    init() {
        // Listen for Firebase auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let firebaseUser = firebaseUser {
                    // User is signed in
                    self.currentUser = User(
                        id: firebaseUser.uid,
                        email: firebaseUser.email ?? "",
                        displayName: firebaseUser.displayName ?? "User",
                        profileImageUrl: firebaseUser.photoURL?.absoluteString,
                        nativeLanguage: self.nativeLanguage,
                        targetLanguage: self.targetLanguage,
                        preferredLevel: self.preferredLevel,
                        notificationsEnabled: self.notificationsEnabled,
                        darkModeEnabled: self.darkModeEnabled
                    )
                    self.isAuthenticated = true
                    self.hasCompletedOnboarding = self.defaults.bool(forKey: Keys.hasCompletedOnboarding)
                } else {
                    // User is signed out
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
                self.isLoading = false
            }
        }
    }
    
    deinit {
        // Remove listener when AuthService is deallocated
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Sign In with Google
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        // Get the client ID from Firebase
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase not configured properly"
            isLoading = false
            return
        }
        
        // Create Google Sign-In configuration
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Cannot find root view controller"
            isLoading = false
            return
        }
        
        // Start Google Sign-In flow
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to get Google credentials"
                    self.isLoading = false
                }
                return
            }
            
            // Create Firebase credential from Google token
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            // Sign in to Firebase with Google credential
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    // Success is handled by authStateListener
                }
            }
        }
    }
    
    // MARK: - Sign In with Email
    func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            isLoading = false
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                // Success is handled by authStateListener
            }
        }
    }
    
    // MARK: - Sign Up with Email
    func signUpWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            isLoading = false
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] _, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                // Success is handled by authStateListener
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            // State change handled by authStateListener
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Complete Onboarding
    func completeOnboarding(targetLanguage: String) {
        self.targetLanguage = targetLanguage
        defaults.set(true, forKey: Keys.hasCompletedOnboarding)
        hasCompletedOnboarding = true
        currentUser?.targetLanguage = targetLanguage
    }
    
    // MARK: - Update Preferences
    func updatePreferences(nativeLanguage: String? = nil, targetLanguage: String? = nil, level: String? = nil) {
        if let native = nativeLanguage {
            self.nativeLanguage = native
            currentUser?.nativeLanguage = native
        }
        if let target = targetLanguage {
            self.targetLanguage = target
            currentUser?.targetLanguage = target
        }
        if let level = level {
            self.preferredLevel = level
            currentUser?.preferredLevel = level
        }
        objectWillChange.send()
    }
    
    // MARK: - Get Firebase ID Token (for API calls)
    func getIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notSignedIn
        }
        return try await user.getIDToken()
    }
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError {
    case notSignedIn
    case invalidCredential
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "User is not signed in"
        case .invalidCredential:
            return "Invalid credentials"
        }
    }
}
