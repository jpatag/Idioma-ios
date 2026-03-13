//
//  Category.swift
//  Idioma
//
//  App-owned category taxonomy for news personalization.
//  These are Idioma's learning categories, mapped to NewsData provider categories.
//

import Foundation

// MARK: - Idioma Category
struct IdiomaCategory: Identifiable, Hashable {
    let id: Int              // Stable numeric id (1–14), used in API requests
    let name: String         // Display name
    let icon: String         // SF Symbol name
    let newsDataCategory: String  // Direct NewsData category mapping
    let isLossy: Bool        // True if NewsData mapping is weak and needs keyword augmentation

    static let maxSelection = 5

    // The 14 app-defined categories in onboarding order
    static let all: [IdiomaCategory] = [
        IdiomaCategory(id: 1,  name: "Politics & Government",   icon: "building.columns",       newsDataCategory: "politics",      isLossy: false),
        IdiomaCategory(id: 2,  name: "Economy & Finance",       icon: "chart.line.uptrend.xyaxis", newsDataCategory: "business",   isLossy: false),
        IdiomaCategory(id: 3,  name: "Arts & Entertainment",    icon: "theatermasks",            newsDataCategory: "entertainment", isLossy: false),
        IdiomaCategory(id: 4,  name: "Sports",                  icon: "sportscourt",             newsDataCategory: "sports",        isLossy: false),
        IdiomaCategory(id: 5,  name: "Business & Labor",        icon: "briefcase",               newsDataCategory: "business",      isLossy: false),
        IdiomaCategory(id: 6,  name: "Science & Tech",          icon: "atom",                    newsDataCategory: "technology",     isLossy: false),
        IdiomaCategory(id: 7,  name: "Education",               icon: "graduationcap",           newsDataCategory: "education",      isLossy: false),
        IdiomaCategory(id: 8,  name: "Crime, Law & Justice",    icon: "scalemass",               newsDataCategory: "crime",          isLossy: false),
        IdiomaCategory(id: 9,  name: "History & Religion",      icon: "book.closed",             newsDataCategory: "other",          isLossy: true),
        IdiomaCategory(id: 10, name: "Environment & Nature",    icon: "leaf",                    newsDataCategory: "environment",    isLossy: false),
        IdiomaCategory(id: 11, name: "Health & Wellness",       icon: "heart",                   newsDataCategory: "health",         isLossy: false),
        IdiomaCategory(id: 12, name: "Social Issues & Society", icon: "person.3",                newsDataCategory: "domestic",       isLossy: true),
        IdiomaCategory(id: 13, name: "Lifestyle & Travel",      icon: "airplane",                newsDataCategory: "lifestyle",      isLossy: false),
        IdiomaCategory(id: 14, name: "Weather & Disaster",      icon: "cloud.bolt.rain",         newsDataCategory: "breaking",       isLossy: true),
    ]

    static func category(for id: Int) -> IdiomaCategory? {
        all.first { $0.id == id }
    }
}
