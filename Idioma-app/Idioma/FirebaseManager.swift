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


class FirebaseManager: ObservableObject {
    @Published var user: User?
    private var cancellables = Set<AnyCancellable>()
    private let auth = Auth.auth()

    init() {
        // Listen for authentication state changes from Firebase
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            self?.user = user
        }
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

    /// Signs in the user anonymously and fetches news articles.
    func fetchNews(completion: @escaping (Result<[NewsArticle], Error>) -> Void) {
        // 1. Ensure user is signed in (anonymously for this test)
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

            // 2. Get the Firebase ID token
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
                
                // 3. Call the getNews function via its HTTP trigger
                self?.callGetNewsFunction(token: token, completion: completion)
            }
        }
    }

    private func callGetNewsFunction(token: String, completion: @escaping (Result<[NewsArticle], Error>) -> Void) {
        // NOTE: The project ID 'idioma-87bed' is hardcoded here.
        // In a real app, this would be configured dynamically.
        guard let url = URL(string: "http://127.0.0.1:5001/idioma-87bed/us-central1/getNews?country=us&language=en") else {
            completion(.failure(NSError(domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // 4. Add the token to the Authorization header
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
                // 5. Decode the JSON response
                let apiResponse = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(apiResponse.results))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
