//
//  ArticleDetailView.swift
//  Idioma
//
//  Full article view with CEFR level selector and reading features.
//  Displays simplified content from the backend API.
//

import SwiftUI

struct ArticleDetailView: View {
    // Article data
    let article: Article
    let selectedLevel: CEFRLevel
    
    // Environment
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    // State
    @State private var currentLevel: CEFRLevel?
    @State private var articleContent: ArticleContent?
    @State private var simplifiedContent: SimplifiedArticle?
    @State private var isLoading: Bool = true
    @State private var isSimplifying: Bool = false
    @State private var errorMessage: String?
    @State private var isBookmarked: Bool = false
    @State private var showingOriginal: Bool = true
    
    // Theme colors
    let primaryColor = Color(red: 236/255, green: 72/255, blue: 153/255) // #EC4899
    let backgroundColor = Color.white
    
    init(article: Article, selectedLevel: CEFRLevel) {
        self.article = article
        self.selectedLevel = selectedLevel
        _currentLevel = State(initialValue: nil)
    }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                headerView
                contentView
            }
            bottomActionBar
        }
        .navigationBarHidden(true)
        .onAppear {
            loadArticle()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 48, height: 48)
            }
            Spacer()
            Button(action: { isBookmarked.toggle() }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .foregroundColor(isBookmarked ? primaryColor : .primary)
                    .frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            Spacer()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.2)
                Text("Loading article...").foregroundColor(.secondary)
            }
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            errorView(error: error)
            Spacer()
        } else {
            articleScrollView
        }
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { loadArticle() }
                .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Article Scroll View
    private var articleScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                articleTitleSection
                levelSelectorSection
                leadImageSection
                articleContentSection
            }
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - Article Title Section
    private var articleTitleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayTitle)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            Text("\(article.sourceDisplay) - \(article.formattedDate)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
        }
    }
    
    private var displayTitle: String {
        if showingOriginal {
            return articleContent?.title ?? article.title ?? "Untitled"
        } else {
            return simplifiedContent?.title ?? articleContent?.title ?? article.title ?? "Untitled"
        }
    }
    
    // MARK: - Level Selector Section
    private var levelSelectorSection: some View {
        LevelSelectorOptional(
            currentLevel: $currentLevel,
            primaryColor: primaryColor,
            onChange: { newLevel in
                showingOriginal = false
                simplifyForLevel(newLevel)
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Lead Image Section
    @ViewBuilder
    private var leadImageSection: some View {
        let imageUrl = simplifiedContent?.leadImageUrl ?? articleContent?.leadImageUrl ?? article.image_url
        if let imageUrl = imageUrl {
            AsyncImage(url: URL(string: imageUrl)) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 240)
                        .clipped()
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Article Content Section
    @ViewBuilder
    private var articleContentSection: some View {
        if isSimplifying {
            HStack {
                ProgressView()
                Text("Simplifying for \(currentLevel?.displayName ?? "") level...")
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
        } else if showingOriginal {
            ArticleTextContent(
                htmlContent: articleContent?.textContent ?? article.content ?? article.description ?? "No content available.",
                primaryColor: primaryColor
            )
            .padding(.horizontal, 16)
        } else {
            ArticleTextContent(
                htmlContent: simplifiedContent?.simplifiedHtml ?? articleContent?.textContent ?? "No content available.",
                primaryColor: primaryColor
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                actionButton(icon: "character.book.closed", title: "Translate") {
                    print("Translate tapped")
                }
                actionButton(icon: "speaker.wave.2", title: "Listen") {
                    print("Listen tapped")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.pink.opacity(0.1).cornerRadius(32))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(primaryColor)
            .cornerRadius(24)
        }
    }
    
    // MARK: - Load Article Content
    private func loadArticle() {
        guard let urlString = article.link else {
            errorMessage = "No article URL available"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("📝 [ArticleDetail] Loading original article")
        
        Task {
            do {
                // Only extract the article content - don't simplify yet
                let content = try await APIService.shared.extractArticle(url: urlString)
                
                await MainActor.run {
                    self.articleContent = content
                    self.showingOriginal = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Simplify for New Level
    private func simplifyForLevel(_ level: CEFRLevel) {
        guard let urlString = article.link else { return }
        
        // Get the article's language name for simplification (use full name for better AI understanding)
        let articleLanguage = article.languageName ?? article.language ?? authService.targetLanguage
        print("📝 [ArticleDetail] Simplifying article for level \(level.rawValue) in language: \(articleLanguage)")
        
        isSimplifying = true
        
        Task {
            do {
                let simplified = try await APIService.shared.simplifyArticle(
                    url: urlString,
                    level: level,
                    language: articleLanguage
                )
                
                await MainActor.run {
                    self.simplifiedContent = simplified
                    self.isSimplifying = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSimplifying = false
                }
            }
        }
    }
}

// MARK: - Level Selector (Optional - supports no selection)
struct LevelSelectorOptional: View {
    @Binding var currentLevel: CEFRLevel?
    let primaryColor: Color
    let onChange: (CEFRLevel) -> Void
    
    let levels: [CEFRLevel] = [.a2, .b1, .b2]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(levels, id: \.self) { level in
                Button(action: {
                    if currentLevel != level {
                        currentLevel = level
                        onChange(level)
                    }
                }) {
                    Text(level.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(currentLevel == level ? primaryColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            currentLevel == level ?
                            Color.white : Color.clear
                        )
                        .cornerRadius(8)
                        .shadow(
                            color: currentLevel == level ? .black.opacity(0.1) : .clear,
                            radius: 2
                        )
                }
            }
        }
        .padding(4)
        .background(Color.pink.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Article Text Content
struct ArticleTextContent: View {
    let htmlContent: String
    let primaryColor: Color
    
    // Convert HTML to plain text (simple implementation)
    var plainText: String {
        // Remove HTML tags for simple display
        // In production, use a proper HTML parser or WKWebView
        var text = htmlContent
        
        // Remove common HTML tags
        let patterns = [
            "<[^>]+>",  // HTML tags
            "&nbsp;",   // Non-breaking space
            "&amp;",    // Ampersand
            "&lt;",     // Less than
            "&gt;",     // Greater than
            "&quot;",   // Quote
        ]
        
        for pattern in patterns {
            text = text.replacingOccurrences(
                of: pattern,
                with: pattern == "&nbsp;" ? " " : pattern == "&amp;" ? "&" : "",
                options: .regularExpression
            )
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        Text(plainText)
            .font(.system(.body, design: .serif))
            .lineSpacing(8)
            .foregroundColor(.primary)
    }
}

// MARK: - Preview
#Preview {
    ArticleDetailView(
        article: Article(
            article_id: "1",
            title: "El futuro de la energía renovable",
            link: "https://example.com/article",
            description: "La transición hacia fuentes de energía sostenibles es uno de los desafíos más cruciales de nuestro tiempo.",
            content: nil,
            pubDate: "2024-01-15",
            image_url: nil,
            source_id: "bbc",
            source_name: "BBC News",
            source_url: nil,
            source_icon: nil,
            language: "es",
            country: ["es"],
            category: ["technology"]
        ),
        selectedLevel: .b1
    )
    .environmentObject(AuthService())
}
