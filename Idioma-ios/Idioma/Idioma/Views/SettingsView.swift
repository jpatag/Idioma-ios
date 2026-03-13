//
//  SettingsView.swift
//  Idioma
//
//  Settings screen for user profile and app preferences.
//  Includes language settings, notifications, and account management.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    // Local state for toggles
    @State private var notificationsEnabled: Bool = true
    @State private var darkModeEnabled: Bool = false
    
    // Sheet states
    @State private var showNativeLanguagePicker: Bool = false
    @State private var showTargetLanguagePicker: Bool = false
    @State private var showLevelPicker: Bool = false
    @State private var showCategoryPicker: Bool = false
    
    // Theme colors
    let primaryColor = Color(red: 236/255, green: 72/255, blue: 153/255)
    let backgroundColor = Color(red: 255/255, green: 247/255, blue: 250/255)
    let iconBackgroundColor = Color(red: 252/255, green: 231/255, blue: 243/255)
    
    private var categorySubtitle: String {
        let ids = authService.selectedCategories
        if ids.isEmpty { return "None selected" }
        let names = ids.compactMap { IdiomaCategory.category(for: $0)?.name }
        return names.joined(separator: ", ")
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 48, height: 48)
                        }
                        
                        Spacer()
                        
                        Text("Settings")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Color.clear
                            .frame(width: 48, height: 48)
                    }
                    .padding(.horizontal, 8)
                    
                    // MARK: - Profile Section
                    VStack(spacing: 12) {
                        // Profile image
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor.opacity(0.5), primaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(authService.currentUser?.displayName.prefix(1).uppercased() ?? "U")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        // Name
                        Text(authService.currentUser?.displayName ?? "User")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Email
                        Text(authService.currentUser?.email ?? "user@example.com")
                            .font(.subheadline)
                            .foregroundColor(primaryColor)
                    }
                    .padding(.top, 8)
                    
                    // MARK: - Language Preferences Section
                    SettingsSection(title: "LANGUAGE PREFERENCES") {
                        // Native Language
                        SettingsRow(
                            icon: "globe",
                            title: "Native Language",
                            subtitle: Language.allLanguages.first { $0.id == authService.nativeLanguage }?.name ?? "English",
                            iconBackgroundColor: iconBackgroundColor
                        ) {
                            showNativeLanguagePicker = true
                        }
                        
                        Divider()
                            .padding(.leading, 72)
                        
                        // Target Language
                        SettingsRow(
                            icon: "character.book.closed",
                            title: "Target Language",
                            subtitle: Language.allLanguages.first { $0.id == authService.targetLanguage }?.name ?? "Spanish",
                            iconBackgroundColor: iconBackgroundColor
                        ) {
                            showTargetLanguagePicker = true
                        }
                        
                        Divider()
                            .padding(.leading, 72)
                        
                        // Difficulty Level
                        SettingsRow(
                            icon: "chart.bar",
                            title: "Difficulty Level",
                            subtitle: CEFRLevel(rawValue: authService.preferredLevel)?.displayName ?? "Intermediate",
                            iconBackgroundColor: iconBackgroundColor
                        ) {
                            showLevelPicker = true
                        }
                        
                        Divider()
                            .padding(.leading, 72)
                        
                        // Interest Categories
                        SettingsRow(
                            icon: "square.grid.2x2",
                            title: "Interest Categories",
                            subtitle: categorySubtitle,
                            iconBackgroundColor: iconBackgroundColor
                        ) {
                            showCategoryPicker = true
                        }
                    }
                    
                    // MARK: - Account & App Section
                    SettingsSection(title: "ACCOUNT & APP") {
                        // Edit Profile
                        SettingsRow(
                            icon: "person",
                            title: "Edit Profile",
                            subtitle: nil,
                            iconBackgroundColor: iconBackgroundColor
                        ) {
                            // TODO: Navigate to edit profile
                        }
                        
                        Divider()
                            .padding(.leading, 72)
                        
                        // Notifications Toggle
                        SettingsToggleRow(
                            icon: "bell",
                            title: "Notifications",
                            isOn: $notificationsEnabled,
                            iconBackgroundColor: iconBackgroundColor,
                            primaryColor: primaryColor
                        )
                        
                        Divider()
                            .padding(.leading, 72)
                        
                        // Dark Mode Toggle
                        SettingsToggleRow(
                            icon: "moon",
                            title: "Dark Mode",
                            isOn: $darkModeEnabled,
                            iconBackgroundColor: iconBackgroundColor,
                            primaryColor: primaryColor
                        )
                    }
                    
                    // MARK: - Support Section
                    SettingsSection(title: "SUPPORT") {
                        SettingsRow(
                            icon: "questionmark.circle",
                            title: "Help & Support",
                            subtitle: nil,
                            iconBackgroundColor: iconBackgroundColor
                        ) {
                            // TODO: Open help/support
                        }
                    }
                    
                    // MARK: - Logout Button
                    Button(action: {
                        authService.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(primaryColor)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Space for tab bar
                }
            }
        }
        .navigationBarHidden(true)
        // MARK: - Sheets
        .sheet(isPresented: $showNativeLanguagePicker) {
            LanguagePickerSheet(
                title: "Select Native Language",
                selectedLanguage: authService.nativeLanguage,
                primaryColor: primaryColor
            ) { language in
                authService.updatePreferences(nativeLanguage: language.id)
            }
        }
        .sheet(isPresented: $showTargetLanguagePicker) {
            LanguagePickerSheet(
                title: "Select Target Language",
                selectedLanguage: authService.targetLanguage,
                primaryColor: primaryColor
            ) { language in
                authService.updatePreferences(targetLanguage: language.id)
            }
        }
        .sheet(isPresented: $showLevelPicker) {
            LevelPickerSheet(
                selectedLevel: authService.preferredLevel,
                primaryColor: primaryColor
            ) { level in
                authService.updatePreferences(level: level.rawValue)
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                selectedCategories: authService.selectedCategories,
                primaryColor: primaryColor
            ) { categories in
                authService.updatePreferences(categories: categories)
            }
        }
        .onAppear {
            notificationsEnabled = authService.notificationsEnabled
            darkModeEnabled = authService.darkModeEnabled
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let iconBackgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 48, height: 48)
                    .background(iconBackgroundColor)
                    .cornerRadius(10)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let iconBackgroundColor: Color
    let primaryColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primary)
                .frame(width: 48, height: 48)
                .background(iconBackgroundColor)
                .cornerRadius(10)
            
            // Title
            Text(title)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .tint(primaryColor)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Language Picker Sheet
struct LanguagePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let title: String
    let selectedLanguage: String
    let primaryColor: Color
    let onSelect: (Language) -> Void
    
    var body: some View {
        NavigationStack {
            List(Language.allLanguages) { language in
                Button(action: {
                    onSelect(language)
                    dismiss()
                }) {
                    HStack {
                        Text(language.flagEmoji)
                            .font(.title)
                        
                        VStack(alignment: .leading) {
                            Text(language.name)
                                .foregroundColor(.primary)
                            Text(language.nativeName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if language.id == selectedLanguage {
                            Image(systemName: "checkmark")
                                .foregroundColor(primaryColor)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Level Picker Sheet
struct LevelPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let selectedLevel: String
    let primaryColor: Color
    let onSelect: (CEFRLevel) -> Void
    
    var body: some View {
        NavigationStack {
            List(CEFRLevel.allCases, id: \.self) { level in
                Button(action: {
                    onSelect(level)
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(level.displayName)
                                .foregroundColor(.primary)
                            Text("CEFR \(level.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if level.rawValue == selectedLevel {
                            Image(systemName: "checkmark")
                                .foregroundColor(primaryColor)
                        }
                    }
                }
            }
            .navigationTitle("Select Difficulty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Category Picker Sheet
struct CategoryPickerSheet: View {
    @Environment(\.dismiss) var dismiss

    let selectedCategories: [Int]
    let primaryColor: Color
    let onSelect: ([Int]) -> Void

    @State private var selectedIds: Set<Int> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(IdiomaCategory.all) { category in
                        CategoryCell(
                            category: category,
                            isSelected: selectedIds.contains(category.id),
                            isDisabled: !selectedIds.contains(category.id) && selectedIds.count >= IdiomaCategory.maxSelection,
                            primaryColor: primaryColor
                        ) {
                            if selectedIds.contains(category.id) {
                                selectedIds.remove(category.id)
                            } else if selectedIds.count < IdiomaCategory.maxSelection {
                                selectedIds.insert(category.id)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Interest Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSelect(selectedIds.sorted())
                        dismiss()
                    }
                    .disabled(selectedIds.isEmpty)
                }
            }
        }
        .onAppear {
            selectedIds = Set(selectedCategories)
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(AuthService())
}
