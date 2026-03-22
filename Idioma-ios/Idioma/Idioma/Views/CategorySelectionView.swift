//
//  CategorySelectionView.swift
//  Idioma
//
//  Category selection screen for onboarding (step 2, after language selection).
//  Users choose up to 5 interest categories from the 14 app-defined categories.
//

import SwiftUI

struct CategorySelectionView: View {
    @EnvironmentObject var authService: AuthService

    /// The target language chosen in the previous onboarding step.
    let targetLanguage: String

    /// When true this view is shown to an existing user who is missing categories
    /// (not during the initial onboarding flow).
    var isExistingUserFlow: Bool = false

    @State private var selectedIds: Set<Int> = []

    // Theme colors (match LanguageSelectionView)
    let primaryColor = Color(red: 244/255, green: 114/255, blue: 182/255)
    let backgroundColor = Color(red: 255/255, green: 247/255, blue: 249/255)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    // Back button only during onboarding (not for existing-user gate)
                    if !isExistingUserFlow {
                        Button(action: { /* handled by NavigationStack pop */ }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 48, height: 48)
                        }
                    } else {
                        Color.clear.frame(width: 48, height: 48)
                    }

                    Spacer()

                    Text("What topics interest you?")
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Spacer()

                    Color.clear.frame(width: 48, height: 48)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // Subtitle
                Text("Choose up to \(IdiomaCategory.maxSelection) categories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                // Selection counter
                Text("\(selectedIds.count) / \(IdiomaCategory.maxSelection) selected")
                    .font(.caption)
                    .foregroundColor(selectedIds.count == IdiomaCategory.maxSelection ? primaryColor : .secondary)
                    .padding(.top, 4)

                // MARK: - Category Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(IdiomaCategory.all) { category in
                            CategoryCell(
                                category: category,
                                isSelected: selectedIds.contains(category.id),
                                isDisabled: !selectedIds.contains(category.id) && selectedIds.count >= IdiomaCategory.maxSelection,
                                primaryColor: primaryColor
                            ) {
                                toggleCategory(category.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100) // Space for button
                }

                Spacer()
            }

            // MARK: - Continue Button
            VStack {
                Spacer()

                Button(action: confirmSelection) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedIds.isEmpty ? Color.gray : primaryColor)
                        .cornerRadius(28)
                }
                .disabled(selectedIds.isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [backgroundColor.opacity(0), backgroundColor]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .allowsHitTesting(false)
                )
            }
        }
    }

    // MARK: - Helpers

    private func toggleCategory(_ id: Int) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else if selectedIds.count < IdiomaCategory.maxSelection {
            selectedIds.insert(id)
        }
    }

    private func confirmSelection() {
        let sortedIds = selectedIds.sorted()
        if isExistingUserFlow {
            authService.completeCategorySelection(categories: sortedIds)
        } else {
            authService.completeOnboarding(targetLanguage: targetLanguage, categories: sortedIds)
        }
    }
}

// MARK: - Category Cell
struct CategoryCell: View {
    let category: IdiomaCategory
    let isSelected: Bool
    let isDisabled: Bool
    let primaryColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(category.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? primaryColor : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? primaryColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .disabled(isDisabled)
    }
}

// MARK: - Preview
#Preview {
    CategorySelectionView(targetLanguage: "es")
        .environmentObject(AuthService())
}
