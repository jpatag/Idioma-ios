<div align="center">

<table>
<tr>
<td width="50%" align="center">
<img src="idioma.png" alt="Idioma Logo" width="300"/>
</td>
<td width="50%" align="center">
<img src="demo screenshot.png" alt="Demo Screenshot" width="200"/>
</td>
</tr>
</table>


# 🌍 Idioma

### *Learn Languages Through Real News*

**An AI-powered iOS app that makes authentic news accessible to language learners by simplifying articles to your CEFR level.**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://www.apple.com/ios/)
[![Firebase](https://img.shields.io/badge/Firebase-Cloud-yellow.svg)](https://firebase.google.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-blue.svg)](https://www.typescriptlang.org/)

</div>

---

## 🎯 The Problem

Language learners struggle to find reading material that's both **authentic** and **appropriate for their level**. Native news articles are too advanced for beginners, while textbook exercises lack real-world context and relevance.

## 💡 The Solution

**Idioma** bridges this gap by using AI to simplify real news articles to match your learning level (A2–C1), letting you read about topics you actually care about while building language skills. 

---

## ✨ Features

### 📰 Real News, Your Level & Categories
Browse today's headlines across 10 supported languages and 14 different customizable interest categories. Each article is automatically adapted to your chosen CEFR proficiency level using OpenAI.

### 📚 Vocabulary Highlighting (Spanish)
Spanish learners get automatic color-coded vocabulary highlighting based on the top 1000 most common words, categorized by CEFR level and topic, helping you focus on the words that matter most to your progress.

### 🚀 Instant Streaming & Formatting
Articles are simplified instantly using SSE (Server-Sent Events) streaming, rendering paragraph-by-paragraph with native Markdown formatting for a frictionless reading experience.

### 🔐 Secure & Personal
Sign in with Google to save your language preferences, CEFR level, and favorite categories. Supported by Firebase's secure authentication and scalable Firestore database.

---

## 🛠️ Stack & Architecture

<table>
<tr>
<td align="center" width="50%">

### Frontend (iOS)
**Native SwiftUI application**

🎨 **SwiftUI** - Modern, declarative UI  
📱 **Swift 5.9** - iOS 15.0+  
⚡ **SSE Streaming** - Real-time AI text progression  
✨ **MarkdownFormatter** - In-house Markdown parsing  
🎯 **Firebase SDK** - Auth & real-time DB  

</td>
<td align="center" width="50%">

### Backend (Firebase)
**Serverless Cloud Functions**

☁️ **Firebase Cloud Functions** - TypeScript/Node 22  
🗄️ **Cloud Firestore** - Scalable schema & caching  
🤖 **OpenAI API** - `gpt-5-nano` for context-aware CEFR  
📰 **newsdata.io API** - Real-time article aggregation  
📄 **Mozilla Readability** - Robust HTML extraction  

</td>
</tr>
</table>

### Key Technical Highlights

- **⚡ Performance & Caching**: "Fire-and-forget" caching in Firestore ensures users never wait on DB writes. Aggressive caching of raw HTML and simplified Markdown drastically reduces API costs.
- **🔄 Streaming Engine**: SSE natively supported from Cloud Functions down to the iOS client, buffered and debounced (100ms) to ensure 60fps scrolling while the AI generates text.
- **🧠 Category Balancing**: Smart query mapping balances `newsdata.io`'s standard categories with our 14 custom user categories using localized keyword augmentation ("lossy" vs "strong" categories).
- **🛡️ Quality Extraction**: 3-attempt retry pipeline with `jsdom` and header configuration to extract clean text from paywalled or protected sites.

---

## 🚀 Quick Start

Want to run this project locally? 

### 📱 iOS App
1. Clone the repo: `git clone https://github.com/jpatag/Idioma.git`
2. Open the Xcode project: `open Idioma-ios/Idioma/Idioma.xcodeproj` *(Note: do not open an `Idioma-app` directory)*
3. Ensure you have the `GoogleService-Info.plist` installed for Firebase Auth to work.
4. Press ⌘+R in Xcode to build and run.

### ☁️ Backend (Firebase Emulators)
1. Navigate to the backend directory: `cd Idioma-backend/functions`
2. Install packages: `npm install`
3. Setup environment variables by creating `.env`:
   ```env
   NEWS_API_KEY=your_key_here
   OPENAI_API_KEY=your_key_here
   ```
4. Build and run emulators:
   ```bash
   npm run build
   npm run serve
   ```
*(Starts Functions on `:5001`, Firestore on `:8080`, and Auth on `:9099`)*

---

## 📅 Project Status & Roadmap

**Current Phase:** Phase 2 (MVP Frontend Integration)
- ✅ Google Authentication (3-gate onboarding)
- ✅ Real-time news aggregation & custom category interleaving
- ✅ Contextual AI article simplification (Markdown + Streaming)
- ✅ Spanish Vocabulary Highlighter

**Upcoming Priorities:**
- ⏳ Offline caching layer
- ⏳ In-line vocabulary lookup using the iOS Dictionary API
- ⏳ Flashcards generation and Text-to-Speech
- ⏳ Wikipedia search integrations

---

## 🙏 Acknowledgments

Built using these excellent technologies and services:
- **[newsdata.io](https://newsdata.io/)** - News aggregation
- **[OpenAI](https://openai.com/)** - Language models
- **[Firebase](https://firebase.google.com/)** - Backend infrastructure
- **[Mozilla Readability](https://github.com/mozilla/readability)** - HTML content extraction

---

<div align="center">

*Made to help millions of language learners access authentic content* 

</div>
