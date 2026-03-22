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
    @State private var streamingText: String = ""
    @State private var errorMessage: String?
    @State private var isBookmarked: Bool = false
    @State private var showingOriginal: Bool = true
    @State private var showQuizSheet: Bool = false
    @State private var showQuizButton: Bool = false
    
    // Theme colors
    let primaryColor = Color(red: 236/255, green: 72/255, blue: 153/255) // #EC4899
    let backgroundColor = Color.white
    
    init(article: Article, selectedLevel: CEFRLevel) {
        self.article = article
        self.selectedLevel = selectedLevel
        _currentLevel = State(initialValue: nil)
    }
    
    /// Whether the quiz entry point should be visible (Spanish articles only)
    private var isSpanishArticle: Bool {
        let code = article.languageCode ?? ""
        return code == "es" || code == "spanish"
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
        .sheet(isPresented: $showQuizSheet) {
            QuizSheetView(
                articleURL: article.link ?? "",
                level: currentLevel ?? selectedLevel,
                language: article.languageName ?? "Spanish",
                categories: article.idiomaCategoryIds ?? []
            )
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
                
                // Quiz button — Spanish articles only, after content loads
                if isSpanishArticle && !isSimplifying {
                    quizButtonSection
                }
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

    private var activeHighlightCategoryIDs: Set<Int> {
        SpanishVocabularyHighlighter.shared.activeCategoryIDs(from: article.idiomaCategoryIds)
    }

    private var highlightLanguageCode: String? {
        article.languageCode ?? authService.targetLanguage
    }

    private var highlightVocabularyLevelIDs: Set<VocabularyLevelID> {
        if let currentLevel {
            return [currentLevel.vocabularyLevelID]
        }

        return Set(VocabularyLevelID.allCases)
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
            CachedImage(url: imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 240)
                    .clipped()
                    .cornerRadius(12)
            } placeholder: {
                Color.clear.frame(height: 240)
            } errorView: {
                Color.clear.frame(height: 240)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    @ViewBuilder
    private var articleContentSection: some View {
        if isSimplifying {
            if streamingText.isEmpty {
                // Waiting for first token from the stream
                HStack {
                    ProgressView()
                    Text("Simplifying for \(currentLevel?.displayName ?? "") level...")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            } else {
                // Show streaming text with formatting (paragraph breaks, headings, bold)
                let fmt = MarkdownFormatter.format(streamingText)
                if let attrStr = try? AttributedString(fmt.attributedString, including: \.uiKit) {
                    Text(attrStr)
                        .lineSpacing(8)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                } else {
                    Text(fmt.plainText)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(8)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                }
            }
        } else if showingOriginal {
            ArticleTextContent(
                htmlContent: articleContent?.textContent ?? article.content ?? article.description ?? "No content available.",
                activeCategoryIDs: activeHighlightCategoryIDs,
                languageCode: highlightLanguageCode,
                vocabularyLevelIDs: highlightVocabularyLevelIDs
            )
            .padding(.horizontal, 16)
        } else {
            ArticleTextContent(
                htmlContent: simplifiedContent?.simplifiedHtml ?? articleContent?.textContent ?? "No content available.",
                activeCategoryIDs: activeHighlightCategoryIDs,
                languageCode: highlightLanguageCode,
                vocabularyLevelIDs: highlightVocabularyLevelIDs
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Quiz Button Section
    private var quizButtonSection: some View {
        Button(action: { showQuizSheet = true }) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                Text("Take Quiz")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [primaryColor, primaryColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .opacity(showQuizButton ? 1 : 0)
        .offset(y: showQuizButton ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showQuizButton = true
            }
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
    
    // MARK: - Simplify for New Level (Streaming)
    private func simplifyForLevel(_ level: CEFRLevel) {
        guard let urlString = article.link else { return }
        
        let articleLanguage = article.languageName ?? article.language ?? authService.targetLanguage
        print("📝 [ArticleDetail] Streaming simplification for level \(level.rawValue) in language: \(articleLanguage)")
        
        isSimplifying = true
        streamingText = ""
        
        Task {
            do {
                var buffer = ""
                var lastFlush = Date()
                
                for try await chunk in APIService.shared.simplifyArticleStreaming(
                    url: urlString,
                    level: level,
                    language: articleLanguage
                ) {
                    buffer += chunk
                    let now = Date()
                    // Flush to UI every 100ms to avoid excessive re-renders
                    if now.timeIntervalSince(lastFlush) >= 0.1 {
                        let text = buffer
                        buffer = ""
                        lastFlush = now
                        await MainActor.run {
                            self.streamingText += text
                        }
                    }
                }
                
                // Flush any remaining buffer
                if !buffer.isEmpty {
                    await MainActor.run {
                        self.streamingText += buffer
                    }
                }
                
                // Streaming complete — build the final SimplifiedArticle so highlighting can kick in
                await MainActor.run {
                    self.simplifiedContent = SimplifiedArticle(
                        originalUrl: urlString,
                        cefrLevel: level.rawValue,
                        title: self.articleContent?.title ?? self.article.title,
                        byline: self.articleContent?.byline,
                        siteName: self.articleContent?.siteName,
                        simplifiedHtml: self.streamingText,
                        leadImageUrl: self.articleContent?.leadImageUrl ?? self.article.image_url,
                        images: self.articleContent?.images,
                        tokensUsed: nil,
                        cacheHit: nil
                    )
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
    let activeCategoryIDs: Set<Int>
    let languageCode: String?
    let vocabularyLevelIDs: Set<VocabularyLevelID>

    @State private var renderedText = AttributedString()

    private var renderKey: String {
        let categoryKey = activeCategoryIDs.sorted().map(String.init).joined(separator: ",")
        let levelKey = vocabularyLevelIDs.map(\.rawValue).sorted().joined(separator: ",")
        return "\(languageCode ?? "")|\(levelKey)|\(categoryKey)|\(htmlContent.hashValue)"
    }

    private var formattedResult: MarkdownFormatter.Result {
        MarkdownFormatter.format(htmlContent)
    }

    private var fallbackText: AttributedString {
        let fmt = formattedResult
        return (try? AttributedString(fmt.attributedString, including: \.uiKit)) ?? AttributedString(fmt.plainText)
    }

    private func rebuildAttributedText() async {
        let fmt = MarkdownFormatter.format(htmlContent)

        // We wait to update `renderedText` until the final string is fully built below.
        // The fallbackText handles immediate display.

        guard !fmt.plainText.isEmpty else {
            renderedText = AttributedString()
            return
        }

        guard SpanishVocabularyHighlighter.shared.shouldHighlight(languageCode: languageCode),
              !vocabularyLevelIDs.isEmpty,
              !activeCategoryIDs.isEmpty else {
            return
        }

        let text = fmt.plainText
        let baseAttrStr = NSAttributedString(attributedString: fmt.attributedString)

        let matches = await Task.detached(priority: .userInitiated) {
            SpanishVocabularyHighlighter.shared.highlightMatches(
                in: text,
                activeCategoryIDs: activeCategoryIDs,
                vocabularyLevelIDs: vocabularyLevelIDs
            )
        }.value

        guard !Task.isCancelled else { return }

        if matches.isEmpty {
            // No matches, just use the base formatting
            if let attr = try? AttributedString(fmt.attributedString, including: \.uiKit) {
                await MainActor.run { self.renderedText = attr }
            } else {
                await MainActor.run { self.renderedText = AttributedString(fmt.plainText) }
            }
            return
        }

        // Apply all matches at once in the background
        let fullyHighlightedAttrStr = await Task.detached(priority: .userInitiated) {
            SpanishVocabularyHighlighter.shared.makeAttributedString(
                formattedBase: baseAttrStr,
                matches: matches
            )
        }.value
        
        guard !Task.isCancelled else { return }

        // Update UI exactly once, without animation to prevent layout thrashing
        await MainActor.run {
            self.renderedText = fullyHighlightedAttrStr
        }
    }

    var body: some View {
        Text(renderedText.characters.isEmpty ? fallbackText : renderedText)
            .lineSpacing(8)
            .foregroundColor(.primary)
            .task(id: renderKey) {
                await rebuildAttributedText()
            }
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
            category: ["technology"],
            idiomaCategoryIds: []
        ),
        selectedLevel: .b1
    )
    .environmentObject(AuthService())
}

