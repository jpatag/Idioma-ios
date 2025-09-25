import SwiftUI

struct HomeView: View {
    @ObservedObject var authManager: FirebaseManager

    var body: some View {
        VStack(spacing: 30) {
            if let user = authManager.user {
                Text("Welcome,")
                    .font(.largeTitle)
                
                Text(user.displayName ?? "User")
                    .font(.system(size: 40, weight: .bold))
                
                Text(user.email ?? "No email")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                authManager.signOut()
            }) {
                Text("Sign Out")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
}
