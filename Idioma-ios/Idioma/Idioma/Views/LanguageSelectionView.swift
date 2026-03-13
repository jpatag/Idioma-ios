//
//  LanguageSelectionView.swift
//  Idioma
//
//  Language selection screen for onboarding.
//  Users choose their target language for learning.
//

import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject var authService: AuthService
    
    // State
    @State private var searchText: String = ""
    @State private var selectedRegion: String = "Popular"
    @State private var selectedLanguage: Language?
    @State private var navigateToCategories: Bool = false
    
    // Theme colors
    let primaryColor = Color(red: 244/255, green: 114/255, blue: 182/255) // #F472B6
    let backgroundColor = Color(red: 255/255, green: 247/255, blue: 249/255) // #FFF7F9
    
    // Filtered languages based on search and region
    var filteredLanguages: [Language] {
        var languages = Language.languages(for: selectedRegion)
        
        if !searchText.isEmpty {
            languages = languages.filter { language in
                language.name.localizedCaseInsensitiveContains(searchText) ||
                language.nativeName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return languages
    }
    
    var body: some View {
        NavigationStack {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: {
                        // Go back to login
                        authService.signOut()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 48, height: 48)
                    }
                    
                    Spacer()
                    
                    Text("What language do you want to learn?")
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    
                    // Spacer for alignment
                    Color.clear
                        .frame(width: 48, height: 48)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                
                // MARK: - Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search for a language...", text: $searchText)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // MARK: - Region Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Language.regions, id: \.self) { region in
                            RegionPill(
                                title: region,
                                isSelected: selectedRegion == region,
                                primaryColor: primaryColor
                            ) {
                                selectedRegion = region
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                // MARK: - Language List
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredLanguages) { language in
                            LanguageRow(
                                language: language,
                                isSelected: selectedLanguage?.id == language.id,
                                primaryColor: primaryColor
                            ) {
                                selectedLanguage = language
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Space for button
                }
                
                Spacer()
            }
            
            // MARK: - Continue Button
            VStack {
                Spacer()
                
                Button(action: {
                    if selectedLanguage != nil {
                        navigateToCategories = true
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedLanguage != nil ? primaryColor : Color.gray)
                        .cornerRadius(28)
                }
                .disabled(selectedLanguage == nil)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            backgroundColor.opacity(0),
                            backgroundColor
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .allowsHitTesting(false)
                )
            }
        }
        .navigationDestination(isPresented: $navigateToCategories) {
            if let language = selectedLanguage {
                CategorySelectionView(targetLanguage: language.id)
                    .environmentObject(authService)
                    .navigationBarBackButtonHidden(true)
            }
        }
        } // NavigationStack
    }
}

// MARK: - Region Filter Pill
struct RegionPill: View {
    let title: String
    let isSelected: Bool
    let primaryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? primaryColor.opacity(0.8) : Color.white)
                .cornerRadius(20)
        }
    }
}

// MARK: - Language Row
struct LanguageRow: View {
    let language: Language
    let isSelected: Bool
    let primaryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Flag emoji as avatar
                Text(language.flagEmoji)
                    .font(.system(size: 36))
                    .frame(width: 48, height: 48)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                
                // Language names
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(language.nativeName)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Selection indicator
                Circle()
                    .stroke(isSelected ? primaryColor : Color.gray.opacity(0.3), lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? primaryColor : Color.clear)
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .padding(8)
            .background(isSelected ? primaryColor.opacity(0.1) : Color.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
#Preview {
    LanguageSelectionView()
        .environmentObject(AuthService())
}
