//
//  SavedArticlesView.swift
//  Idioma
//
//  Placeholder view for saved/bookmarked articles.
//  TODO: Implement article bookmarking with Firestore or local storage.
//

import SwiftUI

struct SavedArticlesView: View {
    // Theme colors
    let primaryColor = Color(red: 244/255, green: 114/255, blue: 182/255)
    let backgroundColor = Color(red: 255/255, green: 247/255, blue: 250/255)
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Placeholder icon
                Image(systemName: "bookmark")
                    .font(.system(size: 64))
                    .foregroundColor(.gray.opacity(0.5))
                
                // Title
                Text("Saved Articles")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Description
                Text("Articles you bookmark will appear here.\nTap the bookmark icon on any article to save it.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SavedArticlesView()
}
