//
//  IdiomaApp.swift
//  Idioma
//
//  Created by Jacob Patag on 7/2/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions
import FirebaseFirestore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // --- Connect to local emulators for testing ---
    #if DEBUG
    print("Connecting to local Firebase emulators.")
    Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
    
    let settings = Firestore.firestore().settings
    settings.host = "127.0.0.1:8080"
    settings.isSSLEnabled = false
    settings.isPersistenceEnabled = false // Useful for testing
    Firestore.firestore().settings = settings
    
    Functions.functions().useEmulator(withHost: "127.0.0.1", port: 5001)
    #endif
    
    return true
  }
}

@main
struct IdiomaApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle the URL that caused the app to open
                    // This is crucial for the Google Sign-In redirect
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
