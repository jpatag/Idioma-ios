import Foundation
import Firebase
import FirebaseFirestore

// MARK: - Article Database Models

struct ArticleModel: Identifiable, Codable {
    let id: String
    let article_id: String
    let title: String
    let link: String
    let description: String?
    let creator: [String]?
    let keywords: [String]?
    let content: String?
    let pubDate: String?
    let image_url: String?
    let language: String?
    let country: [String]?
    let category: [String]?
    let source_name: String?
    let source_id: String?
    let source_url: String?
    let source_icon: String?
    let source_priority: Int?
    let pubDateTZ: String?
    let duplicate: Bool?
    let video_url: String?
    
    // AI fields (only available in paid plans)
    let ai_summary: String?
    let ai_content: String?
    let ai_tag: String?
    let ai_org: String?
    let ai_region: String?
    let sentiment: String?
    let sentiment_stats: String?
    
    // For Firestore compatibility
    var documentID: String {
        return article_id
    }
}

// MARK: - Article Content Database Model

struct ArticleContentModel: Identifiable, Codable {
    let id: String
    let title: String
    let url: String
    let byline: String?
    let siteName: String?
    let contentHtml: String
    let llmHtml: String?
    let textContent: String
    let leadImageUrl: String?
    let images: [String]?
    let timestamp: Timestamp
    
    // For Firestore compatibility
    var documentID: String {
        return id
    }
}

// MARK: - Simplified Article Database Model

struct SimplifiedArticleModel: Identifiable, Codable {
    let id: String
    let title: String
    let originalUrl: String
    let byline: String?
    let siteName: String?
    let cefrLevel: String?
    let simplifiedHtml: String
    let leadImageUrl: String?
    let images: [String]?
    let timestamp: Timestamp
    
    // For Firestore compatibility
    var documentID: String {
        return id
    }
}

// MARK: - Firebase Service for Articles

class ArticleService {
    private let db = Firestore.firestore()
    
    // Fetch articles with optional language filter
    func fetchArticles(language: String? = nil, limit: Int = 20, completion: @escaping (Result<[ArticleModel], Error>) -> Void) {
        var query: Query = db.collection("articles")
        
        if let language = language {
            print("📄 Creating query for language: \(language)")
            query = query.whereField("language", isEqualTo: language)
        }
        
        // Add ordering by date if available to get newest articles first
        query = query.order(by: "pubDate", descending: true)
        query = query.limit(to: limit)
        
        print("🔍 Executing Firestore query: articles collection" + (language != nil ? " with language=\(language!)" : ""))
        
        query.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ No documents returned from Firestore articles query")
                completion(.success([]))
                return
            }
            
            print("✅ Firestore returned \(documents.count) articles")
            
            // Debug: show language field values if available
            if !documents.isEmpty {
                let firstFew = documents.prefix(min(3, documents.count))
                for (index, doc) in firstFew.enumerated() {
                    let data = doc.data()
                    let lang = data["language"] as? String ?? "nil"
                    print("📄 Article \(index+1): id=\(doc.documentID), language=\(lang), title=\(data["title"] as? String ?? "untitled")")
                }
            }
            
            do {
                let articles = try documents.compactMap { document -> ArticleModel? in
                    let data = document.data()
                    
                    // Create article from document data
                    return ArticleModel(
                        id: document.documentID,
                        article_id: data["article_id"] as? String ?? document.documentID,
                        title: data["title"] as? String ?? "Untitled",
                        link: data["link"] as? String ?? "",
                        description: data["description"] as? String,
                        creator: data["creator"] as? [String],
                        keywords: data["keywords"] as? [String],
                        content: data["content"] as? String,
                        pubDate: data["pubDate"] as? String,
                        image_url: data["image_url"] as? String,
                        language: data["language"] as? String,
                        country: data["country"] as? [String],
                        category: data["category"] as? [String],
                        source_name: data["source_name"] as? String,
                        source_id: data["source_id"] as? String,
                        source_url: data["source_url"] as? String,
                        source_icon: data["source_icon"] as? String,
                        source_priority: data["source_priority"] as? Int,
                        pubDateTZ: data["pubDateTZ"] as? String,
                        duplicate: data["duplicate"] as? Bool,
                        video_url: data["video_url"] as? String,
                        ai_summary: data["ai_summary"] as? String,
                        ai_content: data["ai_content"] as? String,
                        ai_tag: data["ai_tag"] as? String,
                        ai_org: data["ai_org"] as? String,
                        ai_region: data["ai_region"] as? String,
                        sentiment: data["sentiment"] as? String,
                        sentiment_stats: data["sentiment_stats"] as? String
                    )
                }
                completion(.success(articles))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // Fetch article content by article ID
    func fetchArticleContent(articleId: String, completion: @escaping (Result<ArticleContentModel, Error>) -> Void) {
        db.collection("articleContent").document(articleId).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                completion(.failure(NSError(domain: "FirestoreError", code: -1, 
                                          userInfo: [NSLocalizedDescriptionKey: "Article content not found"])))
                return
            }
            
            do {
                let content = ArticleContentModel(
                    id: document.documentID,
                    title: data["title"] as? String ?? "Untitled",
                    url: data["url"] as? String ?? "",
                    byline: data["byline"] as? String,
                    siteName: data["siteName"] as? String,
                    contentHtml: data["contentHtml"] as? String ?? "",
                    llmHtml: data["llmHtml"] as? String,
                    textContent: data["textContent"] as? String ?? "",
                    leadImageUrl: data["leadImageUrl"] as? String,
                    images: data["images"] as? [String],
                    timestamp: data["timestamp"] as? Timestamp ?? Timestamp()
                )
                completion(.success(content))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // Fetch simplified article by article ID
    func fetchSimplifiedArticle(articleId: String, completion: @escaping (Result<SimplifiedArticleModel, Error>) -> Void) {
        db.collection("simplifiedArticles").document(articleId).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                completion(.failure(NSError(domain: "FirestoreError", code: -1, 
                                          userInfo: [NSLocalizedDescriptionKey: "Simplified article not found"])))
                return
            }
            
            do {
                let simplified = SimplifiedArticleModel(
                    id: document.documentID,
                    title: data["title"] as? String ?? "Untitled",
                    originalUrl: data["originalUrl"] as? String ?? "",
                    byline: data["byline"] as? String,
                    siteName: data["siteName"] as? String,
                    cefrLevel: data["cefrLevel"] as? String,
                    simplifiedHtml: data["simplifiedHtml"] as? String ?? "",
                    leadImageUrl: data["leadImageUrl"] as? String,
                    images: data["images"] as? [String],
                    timestamp: data["timestamp"] as? Timestamp ?? Timestamp()
                )
                completion(.success(simplified))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
