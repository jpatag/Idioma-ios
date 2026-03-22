//
//  HomeView.swift
//  Idioma
//
//  Main article feed showing news articles for the selected language.
//  Users can filter by language and difficulty level.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    
    // State for articles and loading
    @State private var articles: [Article] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    // Filter state
    @State private var selectedLanguage: String = "es"
    @State private var selectedLevel: CEFRLevel = .b1
    
    // Theme colors
    let primaryColor = Color(red: 244/255, green: 114/255, blue: 182/255)
    let backgroundColor = Color(red: 255/255, green: 247/255, blue: 250/255)
    
    // Available languages for quick filter
    let languageFilters = [
        ("es", "🇪🇸 Spanish"),
        ("fr", "🇫🇷 French"),
        ("de", "🇩🇪 German"),
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Header
                    HStack {
                        Image(systemName: "character.book.closed.fill")
                            .font(.title)
                            .foregroundColor(primaryColor)
                        
                        Spacer()
                        
                        Text("Today's Articles")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            // TODO: Implement search
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    // MARK: - Language Filter Pills
                    HStack(spacing: 8) {
                        Spacer()
                        ForEach(languageFilters, id: \.0) { code, name in
                            LanguageFilterPill(
                                name: name,
                                isSelected: selectedLanguage == code,
                                primaryColor: primaryColor
                            ) {
                                selectedLanguage = code
                                loadArticles()
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    // MARK: - Articles List
                    if isLoading {
                        Spacer()
                        ProgressView("Loading articles...")
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                loadArticles()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        Spacer()
                    } else if articles.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "newspaper")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No articles found")
                                .foregroundColor(.secondary)
                            Button("Refresh") {
                                loadArticles()
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(articles) { article in
                                    NavigationLink(destination: ArticleDetailView(article: article, selectedLevel: selectedLevel)) {
                                        ArticleCard(article: article, primaryColor: primaryColor)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Load articles when view appears
            if articles.isEmpty {
                selectedLanguage = authService.targetLanguage
                if let level = CEFRLevel(rawValue: authService.preferredLevel) {
                    selectedLevel = level
                }
                loadArticles()
            }
        }
    }
    
    // MARK: - Load Articles
    private func loadArticles() {
        print("\n🏠 [HomeView] loadArticles started")
        print("📍 Language: \(selectedLanguage), Level: \(selectedLevel.rawValue)")
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let country = Country.defaultCountry(for: selectedLanguage)
                print("🌍 [HomeView] Country resolved: \(country)")
                
                let fetchedArticles = try await APIService.shared.getNews(
                    country: country,
                    language: selectedLanguage,
                    categories: authService.selectedCategories
                )
                
                print("✅ [HomeView] Received \(fetchedArticles.count) articles")
                
                await MainActor.run {
                    self.articles = fetchedArticles
                    self.isLoading = false
                    print("🎯 [HomeView] UI updated with \(fetchedArticles.count) articles")
                }
            } catch {
                print("❌ [HomeView] Error loading articles: \(error)")
                print("📝 [HomeView] Error details: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("🎯 [HomeView] UI updated with error message")
                }
            }
        }
    }
}

// MARK: - Language Filter Pill
struct LanguageFilterPill: View {
    let name: String
    let isSelected: Bool
    let primaryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? primaryColor.opacity(0.2) : Color.pink.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - Difficulty Filter Pill
struct DifficultyPill: View {
    let level: CEFRLevel
    let isSelected: Bool
    let primaryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(level.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? primaryColor.opacity(0.2) : Color.pink.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - Article Card
struct ArticleCard: View {
    let article: Article
    let primaryColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Article image
            AsyncImage(url: URL(string: article.image_url ?? "")) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            ProgressView()
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fill)
                }
            }
            .clipped()
            
            // Article content
            VStack(alignment: .leading, spacing: 8) {
                // Source and date
                Text("\(article.sourceDisplay) - \(article.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Title
                Text(article.title ?? "Untitled")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Description
                if let description = article.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Bottom row
                HStack {
                    // Category badge
                    if let categoryName = article.primaryCategoryName {
                        Text(categoryName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.pink.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    // Read button
                    Text("Read Article")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(primaryColor)
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environmentObject(AuthService())
}
