import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import Combine

// A simple struct to represent a news article, matching the backend response.
struct NewsArticle: Decodable, Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let description: String?

    private enum CodingKeys: String, CodingKey {
        case title, link, description
    }
}

// A struct for the top-level API response
struct NewsAPIResponse: Decodable {
    let status: String
    let totalResults: Int
    let results: [NewsArticle]
}

// A struct for extracted article content
struct ExtractedArticle: Decodable {
    let title: String
    let content: String
    let byline: String?
    let siteName: String?
    let excerpt: String?
    let textContent: String
}

// A struct for simplified article content
struct SimplifiedArticle: Decodable {
    let original: String
    let simplified: String
    let language: String
}


class FirebaseManager: ObservableObject {
    @Published var user: User?
    @Published var selectedLanguage: String?
    private var cancellables = Set<AnyCancellable>()
    private let auth = Auth.auth()

    init() {
        // Listen for authentication state changes from Firebase
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            self?.user = user
        }
        
        // Load selected language from UserDefaults
        selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage")
    }
    
    func setLanguage(_ language: String) {
        selectedLanguage = language
        UserDefaults.standard.set(language, forKey: "selectedLanguage")
    }

    /// Initiates the Google Sign-In flow.
    func signInWithGoogle() {
        // 1. Get the client ID from the app's Firebase configuration.
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Error: Firebase client ID not found in GoogleService-Info.plist.")
            return
        }

        // 2. Create a Google Sign-In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // 3. Find the top-most view controller to present the sign-in sheet.
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let topVC = windowScene.windows.first?.rootViewController else {
            print("Error: Could not find the top view controller to present the sign-in sheet.")
            return
        }

        // 4. Start the sign-in flow. This will open the Google Sign-In sheet.
        GIDSignIn.sharedInstance.signIn(withPresenting: topVC) { [weak self] result, error in
            guard error == nil else {
                print("Google Sign-In error: \(error!.localizedDescription)")
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Error: Google Sign-In did not return a valid user or ID token.")
                return
            }

            // 5. Create a Firebase credential with the Google ID token.
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)

            // 6. Sign in to Firebase with the credential.
            self?.auth.signIn(with: credential) { (authResult, error) in
                if let error = error {
                    print("Firebase Sign-In error: \(error.localizedDescription)")
                    return
                }
                print("Successfully signed into Firebase with user: \(authResult?.user.displayName ?? "Unknown")")
            }
        }
    }

    /// Signs the current user out of both Firebase and Google.
    func signOut() {
        // Sign out of Firebase
        do {
            try auth.signOut()
            print("Signed out of Firebase.")
        } catch let signOutError as NSError {
            print("Error signing out of Firebase: %@", signOutError)
        }
        
        // Sign out of Google
        GIDSignIn.sharedInstance.signOut()
        print("Signed out of Google.")
    }

    /// Fetches news articles for a specific language.
    func fetchNewsForLanguage(language: String, completion: @escaping (Result<[NewsArticle], Error>) -> Void) {
        // Map language names to ISO codes for the API
        let languageCode: String
        switch language.lowercased() {
        case "spanish":
            languageCode = "es"
        case "french":
            languageCode = "fr"
        case "japanese":
            languageCode = "ja"
        default:
            languageCode = "en"
        }
        
        // If user is already signed in, use their auth token
        if let user = auth.currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let token = token else {
                    completion(.failure(NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ID token not found."])))
                    return
                }
                
                // Call the getNews function with language parameter
                self?.callGetNewsFunction(token: token, language: languageCode, completion: completion)
            }
        } else {
            // If no user, sign in anonymously first
            auth.signInAnonymously { [weak self] (authResult, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let user = authResult?.user else {
                    completion(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found."])))
                    return
                }
                
                print("Successfully signed in anonymously with UID: \(user.uid)")
                
                user.getIDToken { (token, error) in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard let token = token else {
                        completion(.failure(NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ID token not found."])))
                        return
                    }
                    
                    print("Got ID Token. Ready to call backend.")
                    
                    // Call the getNews function with language parameter
                    self?.callGetNewsFunction(token: token, language: languageCode, completion: completion)
                }
            }
        }
    }

    private func callGetNewsFunction(token: String, language: String, completion: @escaping (Result<[NewsArticle], Error>) -> Void) {
        // Using the deployed cloud function URL
        guard let url = URL(string: "https://getnews-64vohpb5ra-uc.a.run.app?language=\(language)") else {
            completion(.failure(NSError(domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Add the token to the Authorization header
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = "Server returned status \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NetworkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                // Decode the JSON response
                let apiResponse = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(apiResponse.results))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Extracts the main content from an article URL
    func extractArticle(articleUrl: String, completion: @escaping (Result<ExtractedArticle, Error>) -> Void) {
        guard let url = URL(string: "https://extractarticle-64vohpb5ra-uc.a.run.app") else {
            completion(.failure(NSError(domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid extraction URL"])))
            return
        }
        
        // Get the auth token
        auth.currentUser?.getIDToken { (token, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let token = token else {
                completion(.failure(NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ID token not found."])))
                return
            }
            
            // Create request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Create request body
            let body: [String: Any] = ["url": articleUrl]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = "Server returned status \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "NetworkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let extractedArticle = try JSONDecoder().decode(ExtractedArticle.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(extractedArticle))
                    }
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
    }
    
    /// Simplifies an article's content
    func simplifyArticle(content: String, language: String, completion: @escaping (Result<SimplifiedArticle, Error>) -> Void) {
        guard let url = URL(string: "https://simplifyarticle-64vohpb5ra-uc.a.run.app") else {
            completion(.failure(NSError(domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid simplification URL"])))
            return
        }
        
        // Get the auth token
        auth.currentUser?.getIDToken { (token, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let token = token else {
                completion(.failure(NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "ID token not found."])))
                return
            }
            
            // Create request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Create request body
            let body: [String: Any] = ["content": content, "language": language]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = "Server returned status \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "NetworkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let simplifiedArticle = try JSONDecoder().decode(SimplifiedArticle.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(simplifiedArticle))
                    }
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
    }
}
