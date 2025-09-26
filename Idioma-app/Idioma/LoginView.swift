import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @ObservedObject var authManager: FirebaseManager
    @State private var isAnimating = false
    @State private var displayText = ""
    @State private var currentIndex = 0
    @State private var isDeleting = false
    @State private var languageIndex = 0
    
    // Welcome messages in different languages
    let welcomeMessages = [
        "Welcome to Idioma",
        "Bienvenido a Idioma",
        "Bienvenue à Idioma", 
        "Willkommen bei Idioma",
        "Benvenuto a Idioma",
        "Idioma へようこそ"
    ]
    
    // Animation timer
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                Spacer()
                
                // App icon/logo
                Image(systemName: "globe")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding()
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear { isAnimating = true }
                
                // Welcome text
                VStack(spacing: 12) {
                    Text(displayText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .frame(height: 40) // Fixed height to prevent layout shifts
                        .onReceive(timer) { _ in
                            animateText()
                        }
                        .onAppear {
                            displayText = ""
                        }
                    
                    Text("Learn languages through simplified news articles")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Google Sign-In Button
                GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .wide, state: .normal)) {
                    authManager.signInWithGoogle()
                }
                .frame(width: 280, height: 50)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                
                // Developer options section
                #if DEBUG
                VStack(alignment: .center) {
                    Text("Developer Options")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    
                    HStack {
                        Text("Use Firebase Emulator")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Toggle("", isOn: Binding<Bool>(
                            get: { UserDefaults.standard.bool(forKey: "use_firebase_emulator") },
                            set: { newValue in
                                authManager.setUseFirebaseEmulator(newValue)
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    .padding(.horizontal, 40)
                    
                    Text("Restart app after changing this setting")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.bottom, 5)
                }
                .padding(.bottom, 20)
                #endif
            }
            .padding()
        }
    }
    
    // Text animation function
    private func animateText() {
        let currentMessage = welcomeMessages[languageIndex]
        
        if !isDeleting {
            // Typing animation
            if currentIndex < currentMessage.count {
                displayText += String(currentMessage[currentMessage.index(currentMessage.startIndex, offsetBy: currentIndex)])
                currentIndex += 1
            } else {
                // Once typing is complete, wait a moment before starting to delete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isDeleting = true
                }
            }
        } else {
            // Deleting animation
            if displayText.count > 0 {
                displayText.removeLast()
                currentIndex -= 1
            } else {
                isDeleting = false
                // Move to the next language
                languageIndex = (languageIndex + 1) % welcomeMessages.count
                currentIndex = 0
            }
        }
    }
}
