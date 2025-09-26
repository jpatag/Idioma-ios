import SwiftUI

struct ArticleDetailView: View {
    let article: NewsArticle
    let language: String
    @ObservedObject var authManager: FirebaseManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isLoading = false
    @State private var extractedArticle: ExtractedArticle?
    @State private var simplifiedArticle: SimplifiedArticle?
    @State private var errorMessage: String?
    @State private var showOriginal = true // Show original text first by default
    @State private var hasLoadedContent = false // Track if content has been loaded
    @State private var cleanedOriginalText: String = "" // Cache cleaned content
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Article title
                Text(article.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Article link
                Link(destination: URL(string: article.link) ?? URL(string: "https://idioma.app")!) {
                    Text(article.link)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
                
                if isLoading {
                    // Loading indicator
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        Text("Extracting and simplifying content...")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 50)
                } else if let errorMsg = errorMessage {
                    // Error message
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text(errorMsg)
                            .font(.headline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            Task {
                                await loadArticleContent()
                            }
                        }) {
                            Text("Try Again")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 50)
                } else if let extracted = extractedArticle, let simplified = simplifiedArticle {
                    // Toggle between original and simplified
                    Picker("Content", selection: $showOriginal) {
                        Text("Simplified").tag(false)
                        Text("Original").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .id("content-picker") // Add stable ID
                    
                    // Content display
                    VStack(alignment: .leading, spacing: 16) {
                        if let byline = extracted.byline, !byline.isEmpty {
                            Text(byline)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        }
                        
                        if let siteName = extracted.siteName, !siteName.isEmpty {
                            Text("From: \(siteName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        ScrollView {
                            Text(showOriginal ? cleanedOriginalText : simplified.simplified)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxHeight: 400)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 5)
                        )
                        .padding(.horizontal)
                    }
                } else {
                    // Default view before loading
                    Text("Tap the button below to load and simplify this article.")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        Task {
                            await loadArticleContent()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text("Load Article")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.vertical)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.blue)
                .font(.headline)
            }
        )
        .task {
            // Automatically load the article when the view appears
            await loadArticleContent()
        }
    }
    
    @MainActor
    private func loadArticleContent() async {
        // Don't reload if content is already present
        guard extractedArticle == nil && !hasLoadedContent else { return }
        
        isLoading = true
        errorMessage = nil
        hasLoadedContent = true
        
        print("📘 Loading article content for: \(article.title)")

        do {
            // Step 1: Fetch and extract the article content (Firestore-first, then API)
            let extracted = try await authManager.fetchArticleContentAsync(articleId: article.article_id, articleLink: article.link)
            
            // Update UI on main thread
            await MainActor.run {
                self.extractedArticle = extracted
                // Cache the cleaned content to avoid recomputing
                self.cleanedOriginalText = self.cleanedOriginalContent(extracted.content)
            }
            
            // Step 2: Fetch and simplify the content (Firestore-first, then API)
            let simplified = try await authManager.fetchSimplifiedArticleAsync(articleId: article.article_id, articleUrl: article.link, originalContent: extracted.textContent, language: self.language)
            
            // Update UI on main thread
            await MainActor.run {
                self.simplifiedArticle = simplified
            }
            
        } catch {
            // Handle any error from the entire process
            await MainActor.run {
                self.errorMessage = "Failed to load article: \(error.localizedDescription)"
            }
            print("❌ Article loading failed: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            self.isLoading = false
        }
        
        recordArticleAsRead()
    }
    
    private func recordArticleAsRead() {
        // Record that the user has read this article
        // This is used for tracking reading history, achievements, etc.
        print("📘 Recording article as read: \(article.title)")
        
        // Call the method on the authManager to record the read
        authManager.recordArticleRead(
            articleId: article.article_id,
            title: article.title,
            language: language
        )
    }
    
    /// Cleans HTML content for display as plain text
    private func cleanedOriginalContent(_ htmlContent: String) -> String {
        // Use NSAttributedString to parse HTML and extract plain text
        if let data = htmlContent.data(using: .utf8) {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                let cleanText = attributedString.string
                
                // Clean up extra whitespace and newlines
                let trimmed = cleanText
                    .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return trimmed.isEmpty ? htmlContent : trimmed
            }
        }
        
        // Fallback: Simple HTML tag removal
        var cleanText = htmlContent
        
        // Replace common HTML tags with appropriate formatting
        cleanText = cleanText.replacingOccurrences(of: "<br>", with: "\n")
        cleanText = cleanText.replacingOccurrences(of: "<br/>", with: "\n")
        cleanText = cleanText.replacingOccurrences(of: "<br />", with: "\n")
        cleanText = cleanText.replacingOccurrences(of: "</p>", with: "\n\n")
        cleanText = cleanText.replacingOccurrences(of: "</div>", with: "\n")
        
        // Remove all remaining HTML tags
        cleanText = cleanText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Clean up extra whitespace
        cleanText = cleanText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: "\n ", with: "\n", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: " \n", with: "\n", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        
        return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
