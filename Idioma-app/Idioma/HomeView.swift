import SwiftUI

struct HomeView: View {
    @ObservedObject var authManager: FirebaseManager
    @State private var selectedLanguage: String?
    
    // Define available languages with more subtle colors
    private let languages = [
        ("Spanish", "🇪🇸", Color.blue),
        ("French", "🇫🇷", Color.blue),
        ("Japanese", "🇯🇵", Color.blue)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clean white background
                Color.white
                    .edgesIgnoringSafeArea(.all)
                
                // Main content
                VStack(spacing: 30) {
                    // Welcome section
                    if let user = authManager.user {
                        VStack(spacing: 8) {
                            Text("Welcome,")
                                .font(.title)
                                .foregroundColor(.gray)
                            
                            Text(user.displayName ?? "Language Learner")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 5)
                            
                            Text("Which language would you like to practice today?")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                        .padding(.top, 30)
                    }
                    
                    // Language selection buttons
                    VStack(spacing: 16) {
                        ForEach(languages, id: \.0) { language, flag, color in
                            NavigationLink(
                                destination: LanguageDetailView(
                                    language: language,
                                    flag: flag,
                                    color: color,
                                    authManager: authManager
                                )
                            ) {
                                LanguageButton(name: language, flag: flag, color: color)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Sign out button
                    Button(action: {
                        authManager.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .padding()
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct LanguageButton: View {
    let name: String
    let flag: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(flag)
                .font(.system(size: 40))
                .padding(.leading, 20)
            
            Text(name)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .padding(.leading, 10)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.trailing, 20)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct LanguageDetailView: View {
    let language: String
    let flag: String
    let color: Color
    @ObservedObject var authManager: FirebaseManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var articles: [NewsArticle] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Backup example articles in case API fails
    private var exampleArticles: [ExampleArticle] {
        switch language {
        case "Spanish":
            return [
                ExampleArticle(id: "1", title: "Barcelona anuncia nuevo parque sostenible", description: "La ciudad de Barcelona ha anunciado la creación de un nuevo parque urbano que utilizará tecnologías sostenibles.", link: "https://www.noticias-barcelona.es/parque-sostenible"),
                ExampleArticle(id: "2", title: "Madrid celebra festival de cine internacional", description: "El festival de cine de Madrid atrae a directores y actores de todo el mundo este fin de semana.", link: "https://www.cultura-madrid.es/festival-cine")
            ]
        case "French":
            return [
                ExampleArticle(id: "1", title: "Paris accueille les Jeux Olympiques 2024", description: "La capitale française se prépare pour accueillir des milliers d'athlètes du monde entier.", link: "https://www.actualites-paris.fr/jeux-olympiques"),
                ExampleArticle(id: "2", title: "Nouveau record de visiteurs au Louvre", description: "Le musée du Louvre a enregistré un nombre record de visiteurs ce trimestre.", link: "https://www.culture-france.fr/louvre-visiteurs")
            ]
        case "Japanese":
            return [
                ExampleArticle(id: "1", title: "東京で新しい技術展示会が開催", description: "最新のテクノロジーを紹介する展示会が東京で開催され、多くの来場者が訪れています。", link: "https://www.tech-news.jp/tokyo-expo"),
                ExampleArticle(id: "2", title: "日本の伝統工芸が海外で人気に", description: "日本の伝統的な工芸品が海外市場で高い評価を受けています。特に若い世代に注目されています。", link: "https://www.culture-japan.jp/traditional-crafts")
            ]
        default:
            return []
        }
    }
    
    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 10) {
                // Language title - more compact design
                HStack(spacing: 12) {
                    Text(flag)
                        .font(.system(size: 42))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome to \(language)!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Explore articles in \(language)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Articles section with title - expanded to use more space
                VStack(alignment: .leading) {
                    HStack {
                        Text("Latest Articles")
                            .font(.headline)
                        
                        Spacer()
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        } else if articles.isEmpty && errorMessage == nil {
                            Button(action: {
                                fetchArticles()
                            }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    
                    if let error = errorMessage {
                        // Error state
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text(error)
                                .font(.headline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                fetchArticles()
                            }) {
                                Text("Try Again")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 5)
                            
                            // Show example articles as fallback
                            Text("Here are some example articles:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.top, 20)
                            
                            List {
                                ForEach(exampleArticles) { article in
                                    ArticleRowView(article: article, color: color, language: language, authManager: authManager)
                                }
                            }
                            .listStyle(.plain)
                            .frame(height: 300)
                        }
                        .padding()
                    } else {
                        // Scrollable article list - expanded to use more space
                        List {
                            if !articles.isEmpty {
                                ForEach(articles) { article in
                                    ArticleRowView(article: article, color: color, language: language, authManager: authManager)
                                }
                            } else if !isLoading {
                                ForEach(exampleArticles) { article in
                                    ArticleRowView(article: article, color: color, language: language, authManager: authManager)
                                }
                            } else {
                                // Loading placeholders
                                ForEach(0..<5, id: \.self) { _ in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(height: 20)
                                                .cornerRadius(4)
                                            
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 40)
                                                .cornerRadius(4)
                                            
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.15))
                                                .frame(height: 15)
                                                .cornerRadius(4)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .redacted(reason: .placeholder)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.top, 5)
                .overlay(
                    // Scroll indicator with animation
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("Scroll for more")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.8))
                    }
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
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
                .foregroundColor(color)
                .font(.headline)
            }
        )
        .onAppear {
            // Save the selected language
            authManager.setLanguage(language)
            
            // Fetch articles when the view appears
            fetchArticles()
        }
    }
    
    private func fetchArticles() {
        isLoading = true
        errorMessage = nil
        
        authManager.fetchNewsForLanguage(language: language) { result in
            isLoading = false
            
            switch result {
            case .success(let newsArticles):
                self.articles = newsArticles
            case .failure(let error):
                self.errorMessage = "Couldn't load articles: \(error.localizedDescription)"
                print("Error fetching articles: \(error)")
            }
        }
    }
}

// Example article model for preview purposes
struct ExampleArticle: Identifiable {
    let id: String
    let title: String
    let description: String
    let link: String
}

// Protocol for article-like objects
protocol ArticleDisplayable {
    var title: String { get }
    var description: String? { get }
    var link: String { get }
}

extension NewsArticle: ArticleDisplayable {}

extension ExampleArticle: ArticleDisplayable {}

// Reusable article row view - more compact design
struct ArticleRowView<T: ArticleDisplayable>: View {
    let article: T
    let color: Color
    let language: String
    let authManager: FirebaseManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(article.title)
                .font(.headline)
                .foregroundColor(.black)
            
            Text(article.description ?? "No description available")
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Text(article.link)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                Spacer()
                
                // More compact read button
                if let newsArticle = article as? NewsArticle {
                    NavigationLink(destination: ArticleDetailView(
                        article: newsArticle,
                        language: language,
                        authManager: authManager
                    )) {
                        HStack(spacing: 4) {
                            Text("Read")
                                .fontWeight(.medium)
                            
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                    }
                } else {
                    Button(action: {
                        // This would navigate to the article detail view in a real app
                    }) {
                        HStack(spacing: 4) {
                            Text("Read")
                                .fontWeight(.medium)
                            
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundColor(.blue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle()) // Makes the whole row tappable
    }
}

