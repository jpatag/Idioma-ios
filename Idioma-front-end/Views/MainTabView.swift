//
//  MainTabView.swift
//  Idioma
//
//  Main tab navigation for the app.
//  Contains Articles, Saved, and Profile tabs.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    
    // Selected tab state
    @State private var selectedTab: Tab = .articles
    
    // Theme colors
    let primaryColor = Color(red: 244/255, green: 114/255, blue: 182/255)
    let backgroundColor = Color(red: 255/255, green: 247/255, blue: 250/255)
    
    enum Tab {
        case articles
        case saved
        case profile
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .articles:
                    HomeView()
                case .saved:
                    SavedArticlesView()
                case .profile:
                    SettingsView()
                }
            }
            
            // Custom Tab Bar
            CustomTabBar(
                selectedTab: $selectedTab,
                primaryColor: primaryColor,
                backgroundColor: backgroundColor
            )
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    let primaryColor: Color
    let backgroundColor: Color
    
    var body: some View {
        HStack {
            // Articles Tab
            TabBarButton(
                icon: "doc.text",
                title: "Articles",
                isSelected: selectedTab == .articles,
                primaryColor: primaryColor
            ) {
                selectedTab = .articles
            }
            
            Spacer()
            
            // Saved Tab
            TabBarButton(
                icon: "bookmark",
                title: "Saved",
                isSelected: selectedTab == .saved,
                primaryColor: primaryColor
            ) {
                selectedTab = .saved
            }
            
            Spacer()
            
            // Profile Tab
            TabBarButton(
                icon: "person",
                title: "Profile",
                isSelected: selectedTab == .profile,
                primaryColor: primaryColor
            ) {
                selectedTab = .profile
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
        .background(
            backgroundColor.opacity(0.9)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .fill(Color.pink.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let primaryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? primaryColor : .secondary)
        }
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
