# Idioma iOS App

A language learning app that presents news articles in your target language, simplified to your reading level using AI.

## � Firebase & Google Sign-In Setup

### Step 1: Add Firebase SDK

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Click **Add Package**
4. Select these libraries:
   - ✅ `FirebaseAuth`
   - ✅ `FirebaseCore`
5. Click **Add Package**

### Step 2: Add Google Sign-In SDK

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter URL: `https://github.com/google/GoogleSignIn-iOS`
3. Click **Add Package**
4. Select:
   - ✅ `GoogleSignIn`
5. Click **Add Package**

### Step 3: Add GoogleService-Info.plist

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (idioma-87bed)
3. Click the iOS app (or add one if needed)
4. Download `GoogleService-Info.plist`
5. Drag it into your Xcode project (same level as `IdiomaApp.swift`)
6. ✅ Check "Copy items if needed"
7. ✅ Check your app target

### Step 4: Add URL Scheme for Google Sign-In

1. Open `GoogleService-Info.plist` in Xcode
2. Find `REVERSED_CLIENT_ID` value (looks like `com.googleusercontent.apps.123456...`)
3. Go to your **Target** → **Info** → **URL Types**
4. Click **+** to add new URL Type
5. Paste the `REVERSED_CLIENT_ID` value into **URL Schemes**

### Step 5: Build & Run

1. Clean build: **⌘⇧K**
2. Build: **⌘B**
3. Run: **⌘R**

---

## �📱 Project Structure

```
Idioma-ios/
├── Idioma/
│   ├── IdiomaApp.swift          # App entry point
│   ├── Models/
│   │   ├── Article.swift        # Article data models
│   │   ├── Language.swift       # Supported languages
│   │   └── User.swift           # User & preferences
│   ├── Services/
│   │   ├── APIService.swift     # Backend API calls
│   │   └── AuthService.swift    # Authentication
│   └── Views/
│       ├── LoginView.swift              # Login screen
│       ├── LanguageSelectionView.swift  # Onboarding
│       ├── HomeView.swift               # Article feed
│       ├── ArticleDetailView.swift      # Article reader
│       ├── SavedArticlesView.swift      # Bookmarks
│       ├── SettingsView.swift           # Settings
│       └── MainTabView.swift            # Tab navigation
```

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ target
- Your Firebase backend deployed

### Setup Instructions

1. **Create Xcode Project**
   - Open Xcode → File → New → Project
   - Select "App" under iOS
   - Product Name: `Idioma`
   - Interface: SwiftUI
   - Language: Swift
   - Save to `Idioma-ios` folder

2. **Add Source Files**
   - Copy all files from this folder into your Xcode project
   - Ensure folder structure matches (Models, Views, Services)
   - Add files to your target in Xcode

3. **Update API URL**
   - Open `Services/APIService.swift`
   - Replace `baseURL` with your Firebase Functions URL:
   ```swift
   private let baseURL = "https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net"
   ```

4. **Run the App**
   - Select a simulator (iPhone 15 Pro recommended)
   - Press ⌘R to build and run

## 📋 Features Overview

### ✅ Implemented Features

| Feature | Description | Backend Endpoint |
|---------|-------------|------------------|
| **Login** | Mock Google Sign-In & email/password | - |
| **Language Selection** | Choose target language for learning | - |
| **Article Feed** | Browse news articles by language | `getNews` |
| **Language Filters** | Switch between Spanish, French, German | `getNews` |
| **Difficulty Filters** | Filter by Beginner/Intermediate/Advanced | - |
| **Article Detail** | Read full article with images | `extractArticle` |
| **CEFR Level Selector** | Toggle difficulty (A2/B1/B2) | `simplifyArticle` |
| **Settings** | User profile & preferences | - |
| **Tab Navigation** | Articles, Saved, Profile tabs | - |

### 🚧 Placeholder Features (To Implement)

| Feature | How to Implement |
|---------|------------------|
| **Real Google Sign-In** | Add Firebase Auth SDK & GoogleSignIn SDK |
| **Saved Articles** | Store bookmarks in Firestore or Core Data |
| **Translate All** | Add translation API (Google Translate / DeepL) |
| **Listen (TTS)** | Use `AVSpeechSynthesizer` |
| **Push Notifications** | Add Firebase Cloud Messaging |
| **Dark Mode** | Connect to `colorScheme` environment |
| **Vocabulary Highlights** | Parse HTML for word definitions |

## 🎨 Design Notes

The UI follows the Stitch mockup design with:

- **Primary Color**: Pink (#F472B6 / #EC4899)
- **Background**: Light pink (#FFF7FA)
- **Font**: System font (Work Sans from mockup not included)
- **Icons**: SF Symbols (Material icons adapted)

## 📂 File Descriptions

### Models

**Article.swift**
- `Article`: News article from the feed
- `ArticleContent`: Extracted article HTML
- `SimplifiedArticle`: AI-simplified content
- `CEFRLevel`: Language proficiency levels (A2-C1)

**Language.swift**
- `Language`: Supported languages with flags
- `Country`: Country codes for news API

**User.swift**
- `User`: User profile data
- `UserPreferences`: Stored settings (UserDefaults)

### Services

**APIService.swift**
- `getNews()`: Fetch articles by country/language
- `extractArticle()`: Get full article content
- `simplifyArticle()`: Simplify for CEFR level

**AuthService.swift**
- `signInWithGoogle()`: Mock Google login
- `signInWithEmail()`: Mock email login
- `signOut()`: Clear user session
- `completeOnboarding()`: Finish language selection

### Views

**LoginView.swift**
- Google Sign-In button
- Email/password form
- Password visibility toggle

**LanguageSelectionView.swift**
- Search bar
- Region filter pills
- Language list with selection

**HomeView.swift**
- Language filter chips
- Difficulty filter buttons
- Article cards with images

**ArticleDetailView.swift**
- Back/bookmark header
- CEFR level selector
- Article content
- Translate/Listen buttons

**SettingsView.swift**
- Profile section
- Language preferences
- App settings toggles
- Logout button

**MainTabView.swift**
- Custom tab bar
- Articles/Saved/Profile tabs

## 🔧 Customization

### Adding a New Language

1. Open `Models/Language.swift`
2. Add to `allLanguages` array:
```swift
Language(id: "nl", name: "Dutch", nativeName: "Nederlands", flagEmoji: "🇳🇱", region: "Europe")
```

3. Add country mapping in `Country.defaultCountry()`:
```swift
case "nl": return "nl"  // Netherlands
```

### Changing Theme Colors

Update the color constants in each view:
```swift
let primaryColor = Color(red: R/255, green: G/255, blue: B/255)
let backgroundColor = Color(red: R/255, green: G/255, blue: B/255)
```

Or create a `Theme.swift` file for centralized colors.

### Adding Firebase Auth

1. Add Firebase SDK via Swift Package Manager:
   - Xcode → File → Add Package Dependencies
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Select: `FirebaseAuth`, `FirebaseFirestore`

2. Add `GoogleService-Info.plist` from Firebase Console

3. Update `AuthService.swift`:
```swift
import FirebaseAuth

func signInWithGoogle() {
    // Use GIDSignIn and link with Firebase
}
```

## 🐛 Troubleshooting

### "Invalid URL" Error
- Check that `baseURL` in `APIService.swift` is correct
- Ensure your Firebase Functions are deployed

### Articles Not Loading
- Verify your NEWS_API_KEY is set in backend `.env`
- Check Firebase Functions logs for errors

### Build Errors
- Ensure iOS deployment target is 17.0+
- Clean build folder: ⌘⇧K

## 📝 Notes

- Authentication is mocked - replace with Firebase Auth for production
- Images use `AsyncImage` which requires iOS 15+
- UserDefaults used for simple persistence
- No third-party dependencies required (except Firebase for production)

## 📄 License

This project is part of the Idioma language learning app.
