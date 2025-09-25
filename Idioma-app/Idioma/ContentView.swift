//
//  ContentView.swift
//  Idioma
//
//  Created by Jacob Patag on 7/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = FirebaseManager()

    var body: some View {
        // This view now acts as a router, showing the correct view
        // based on the user's authentication state.
        if authManager.user != nil {
            HomeView(authManager: authManager)
        } else {
            LoginView(authManager: authManager)
        }
    }
}

#Preview {
    ContentView()
}
