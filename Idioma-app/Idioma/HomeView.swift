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
    
    // Example articles for each language
    private var exampleArticles: [ExampleArticle] {
        switch language {
        case "Spanish":
            return [
                ExampleArticle(id: "1", title: "Barcelona anuncia nuevo parque sostenible", description: "La ciudad de Barcelona ha anunciado la creación de un nuevo parque urbano que utilizará tecnologías sostenibles.", link: "www.noticias-barcelona.es/parque-sostenible"),
                ExampleArticle(id: "2", title: "Madrid celebra festival de cine internacional", description: "El festival de cine de Madrid atrae a directores y actores de todo el mundo este fin de semana.", link: "www.cultura-madrid.es/festival-cine"),
                ExampleArticle(id: "3", title: "La selección española prepara el mundial", description: "El equipo nacional intensifica sus entrenamientos para el próximo mundial de fútbol.", link: "www.deportes.es/mundial-preparacion"),
                ExampleArticle(id: "4", title: "Nueva exposición en el Museo del Prado", description: "El Museo del Prado inaugura una exposición de arte renacentista con obras nunca antes vistas en España.", link: "www.cultura-madrid.es/prado-exposicion"),
                ExampleArticle(id: "5", title: "Científicos españoles descubren nueva especie marina", description: "Un equipo de biólogos marinos ha identificado una nueva especie de coral en las costas del Mediterráneo.", link: "www.ciencia.es/descubrimiento-marino"),
                ExampleArticle(id: "6", title: "España lidera iniciativa de energía renovable", description: "El gobierno español presenta un ambicioso plan para aumentar la producción de energía solar y eólica en los próximos cinco años.", link: "www.energia-verde.es/plan-nacional")
            ]
        case "French":
            return [
                ExampleArticle(id: "1", title: "Paris accueille les Jeux Olympiques 2024", description: "La capitale française se prépare pour accueillir des milliers d'athlètes du monde entier.", link: "www.actualites-paris.fr/jeux-olympiques"),
                ExampleArticle(id: "2", title: "Nouveau record de visiteurs au Louvre", description: "Le musée du Louvre a enregistré un nombre record de visiteurs ce trimestre.", link: "www.culture-france.fr/louvre-visiteurs"),
                ExampleArticle(id: "3", title: "Les vignerons français face au changement climatique", description: "Les producteurs de vin adaptent leurs pratiques face aux défis du réchauffement global.", link: "www.agriculture-fr.com/vignerons-climat"),
                ExampleArticle(id: "4", title: "La Tour Eiffel se transforme pour les célébrations", description: "Une nouvelle installation lumineuse va transformer le monument emblématique pour les festivités nationales.", link: "www.paris-attractions.fr/tour-eiffel-lumiere"),
                ExampleArticle(id: "5", title: "Les écoles françaises adoptent un nouveau programme numérique", description: "Le ministère de l'Éducation introduit des tablettes dans les écoles primaires dans tout le pays.", link: "www.education.fr/programme-numerique"),
                ExampleArticle(id: "6", title: "La cuisine française reconnue patrimoine mondial", description: "L'UNESCO ajoute la gastronomie française à sa liste de patrimoines culturels immatériels.", link: "www.gastronomie.fr/unesco-patrimoine")
            ]
        case "Japanese":
            return [
                ExampleArticle(id: "1", title: "東京で新しい技術展示会が開催", description: "最新のテクノロジーを紹介する展示会が東京で開催され、多くの来場者が訪れています。", link: "www.tech-news.jp/tokyo-expo"),
                ExampleArticle(id: "2", title: "日本の伝統工芸が海外で人気に", description: "日本の伝統的な工芸品が海外市場で高い評価を受けています。特に若い世代に注目されています。", link: "www.culture-japan.jp/traditional-crafts"),
                ExampleArticle(id: "3", title: "桜の季節が早まる傾向、気候変動の影響か", description: "日本各地で桜の開花が例年より早まっており、専門家は気候変動との関連を指摘しています。", link: "www.environment.jp/sakura-climate"),
                ExampleArticle(id: "4", title: "新しい高速鉄道路線が計画中", description: "東京と大阪を結ぶ新しい高速鉄道の計画が発表され、移動時間が大幅に短縮される見込みです。", link: "www.transport.jp/new-train"),
                ExampleArticle(id: "5", title: "日本の大学が国際ランキングで上昇", description: "複数の日本の大学が世界大学ランキングで順位を上げ、国際的な評価が高まっています。", link: "www.education.jp/university-ranking"),
                ExampleArticle(id: "6", title: "和食の健康効果に関する新研究", description: "伝統的な日本食の摂取と長寿の関係について、新しい研究結果が発表されました。", link: "www.health-studies.jp/japanese-diet")
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
                    Text("Latest Articles")
                        .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    
                    // Scrollable article list - expanded to use more space
                    List {
                        ForEach(exampleArticles) { article in
                            ArticleRowView(article: article, color: color)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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

// Reusable article row view - more compact design
struct ArticleRowView: View {
    let article: ExampleArticle
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(article.title)
                .font(.headline)
                .foregroundColor(.black)
            
            Text(article.description)
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
                Button(action: {
                    // This would navigate to the article detail view in a real app
                }) {
                    HStack(spacing: 4) {
                        Text("Read")
                            .fontWeight(.medium)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
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

