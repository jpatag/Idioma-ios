import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @ObservedObject var authManager: FirebaseManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Idioma")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Please sign in to continue.")
                .font(.headline)
                .foregroundColor(.secondary)

            // Google Sign-In Button
            GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .wide, state: .normal)) {
                authManager.signInWithGoogle()
            }
            .padding()
        }
    }
}
