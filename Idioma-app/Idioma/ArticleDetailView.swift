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
    @State private var showOriginal = false
    
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
                            loadArticleContent()
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
                        
                        Text(showOriginal ? extracted.content : simplified.simplified)
                            .font(.body)
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
                        loadArticleContent()
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
        .onAppear {
            // Automatically load the article when the view appears
            loadArticleContent()
        }
    }
    
    private func loadArticleContent() {
        isLoading = true
        errorMessage = nil
        
        authManager.extractArticle(articleUrl: article.link) { result in
            switch result {
            case .success(let extracted):
                self.extractedArticle = extracted
                
                // Now simplify the extracted content
                self.authManager.simplifyArticle(content: extracted.textContent, language: self.language) { simplifyResult in
                    switch simplifyResult {
                    case .success(let simplified):
                        self.simplifiedArticle = simplified
                        self.isLoading = false
                    case .failure(let error):
                        self.errorMessage = "Failed to simplify article: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
                
            case .failure(let error):
                self.errorMessage = "Failed to extract article: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
