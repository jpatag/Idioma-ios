//
//  LoginView.swift
//  Idioma
//
//  Login screen with Google Sign-In and email/password options.
//  Based on the Stitch mockup design.
//

import SwiftUI

struct LoginView: View {
    // Access the auth service from environment
    @EnvironmentObject var authService: AuthService
    
    // Form state
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    
    // Theme colors (matching the Stitch design)
    let primaryColor = Color(red: 244/255, green: 63/255, blue: 94/255) // #f43f5e
    let backgroundColor = Color(red: 255/255, green: 241/255, blue: 242/255) // #fff1f2
    
    var body: some View {
        ZStack {
            // Background color
            backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Logo & Welcome
                    VStack(spacing: 8) {
                        // App icon
                        Image(systemName: "character.book.closed.fill")
                            .font(.system(size: 48))
                            .foregroundColor(primaryColor)
                            .padding(.top, 48)
                        
                        // App name
                        Text("Idioma")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(red: 31/255, green: 17/255, blue: 21/255))
                        
                        // Welcome message
                        Text("Welcome Back!")
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 24)
                    
                    // MARK: - Google Sign In Button
                    Button(action: {
                        authService.signInWithGoogle()
                    }) {
                        HStack(spacing: 12) {
                            // Google "G" icon placeholder
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Log in with Google")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(primaryColor)
                        .cornerRadius(24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // MARK: - Divider
                    HStack {
                        Rectangle()
                            .fill(Color.pink.opacity(0.2))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.pink.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // MARK: - Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color(red: 31/255, green: 17/255, blue: 21/255))
                        
                        TextField("Enter your email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // MARK: - Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color(red: 31/255, green: 17/255, blue: 21/255))
                        
                        HStack {
                            if showPassword {
                                TextField("Enter your password", text: $password)
                            } else {
                                SecureField("Enter your password", text: $password)
                            }
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // MARK: - Forgot Password
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            // TODO: Implement forgot password
                            print("Forgot password tapped")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 31/255, green: 17/255, blue: 21/255))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // MARK: - Login Button
                    Button(action: {
                        authService.signInWithEmail(email: email, password: password)
                    }) {
                        Text("Log In")
                            .font(.headline)
                            .foregroundColor(primaryColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(primaryColor, lineWidth: 2)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // MARK: - Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.gray)
                        
                        Button("Sign Up") {
                            // TODO: Navigate to sign up
                            print("Sign up tapped")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(primaryColor)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 24)
                    
                    // MARK: - Error Message
                    if let error = authService.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                }
            }
            
            // MARK: - Loading Overlay
            if authService.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    LoginView()
        .environmentObject(AuthService())
}
