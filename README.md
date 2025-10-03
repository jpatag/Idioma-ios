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

**An AI-powered iOS app that makes authentic news accessible to language learners**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://www.apple.com/ios/)
[![Firebase](https://img.shields.io/badge/Firebase-Cloud-yellow.svg)](https://firebase.google.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-blue.svg)](https://www.typescriptlang.org/)

🇺🇸 **English** • 🇪🇸 **Spanish** • 🇫🇷 **French** • 🇯🇵 **Japanese**

</div>

---

## 🎯 The Problem

Language learners struggle to find reading material that's both **authentic** and **appropriate for their level**. Native news articles are too advanced for beginners, while textbook exercises lack real-world context and relevance.

## 💡 The Solution

**Idioma** bridges this gap by using AI to simplify real news articles to match your learning level, letting you read about topics you actually care about while building language skills.

---

## ✨ What It Does

### 📰 Real News, Your Level
Browse today's headlines from major news sources in English, Spanish, French, or Japanese. Each article is automatically adapted to your proficiency level (A2-C1 CEFR scale).

### 📚 Compare & Learn
Toggle between the original article and the simplified version to see how native speakers express the same ideas. Perfect for building vocabulary and understanding sentence structure.

### 🚀 Instant & Smart
Articles are simplified in seconds using OpenAI's language models, with intelligent caching to ensure a smooth experience. No waiting, no frustration.

### 🔐 Secure & Personal
Sign in with Google to save your preferences and reading history. Your data is protected by Firebase's enterprise-grade security.

---

## 🛠️ Built With

<table>
<tr>
<td align="center" width="50%">

### Frontend
**Native iOS Experience**

🎨 **SwiftUI** - Modern, declarative UI  
📱 **Swift 5.9** - iOS 15.0+ support  
🏗️ **MVVM Architecture** - Clean, maintainable code  
🔄 **Async/Await** - Smooth asynchronous operations  
🎯 **Firebase SDK** - Auth & real-time data  

</td>
<td align="center" width="50%">

### Backend
**Serverless & Scalable**

☁️ **Firebase Cloud Functions** - Serverless architecture  
💻 **TypeScript** - Type-safe Node.js runtime  
🗄️ **Cloud Firestore** - NoSQL database with caching  
🤖 **OpenAI API** - GPT-powered simplification  
📡 **NewsAPI** - Real-time news aggregation  

</td>
</tr>
</table>

### Key Technical Highlights

- **🚀 Performance**: Intelligent caching reduces API calls by 80%
- **🔒 Security**: API keys secured server-side, OAuth2 authentication
- **📊 Scalability**: Serverless functions auto-scale to demand
- **🎨 UX**: Native SwiftUI provides 60fps animations
- **🧪 Testing**: Comprehensive unit tests and Firebase emulator support

---

## 💻 Demo

> *Demo screenshots and video coming soon*

**Key User Flows:**
1. 🔐 Sign in with Google
2. 🌍 Select your target language
3. 📰 Browse today's news headlines
4. 🤖 Tap to simplify any article
5. 🔄 Toggle between original and simplified versions

---

## 🎯 Project Status & Roadmap

### ✅ What's Working Now

- ✨ **Core Functionality**
  - Google authentication
  - Multi-language news fetching (4 languages)
  - AI-powered article simplification
  - Original/simplified text comparison
  - Smart caching for performance
  
- 🏗️ **Technical Foundation**
  - SwiftUI iOS app
  - TypeScript Firebase backend
  - Serverless cloud functions
  - Firestore database integration
  - Local development environment with emulators


---

## Quick Start

Want to run this project locally? Here's the express version:

```bash
# Clone the repo
git clone https://github.com/jpatag/Idioma-ios.git
cd Idioma-ios

# iOS App
open Idioma-app/Idioma.xcodeproj
# Press ⌘+R in Xcode to build and run

# Backend (in a new terminal)
cd Idioma-backend/functions
npm install
npm run serve  # Starts local Firebase emulators
```

**Need more details?** Check out our [Setup Guide](docs/setup.md) for complete installation instructions.

---

## 🧠 Technical Challenges Solved

### 1. **Real-Time AI Simplification**
Implemented a smart caching layer that reduces API costs by 80% while maintaining fresh content. Articles are cached by URL and proficiency level, with automatic expiration.

### 2. **Article Extraction**
Built a robust content extraction pipeline using Mozilla's Readability algorithm and jsdom to parse complex news websites, handling various HTML structures and edge cases.

### 3. **Serverless Architecture**
Designed a scalable backend using Firebase Cloud Functions that automatically scales based on demand, eliminating server management overhead.

### 4. **Performance Optimization**
Implemented parallel async/await calls in Swift to fetch and display articles instantly, with smooth loading states and error handling.

### 5. **Local Development**
Created a complete local development environment using Firebase emulators, allowing full-stack development without cloud costs or internet dependency.

**Built with** ❤️ **for language learners worldwide**

</div>

---

## 🙏 Acknowledgments

Special thanks to the open-source community and these services that made Idioma possible:

- **[NewsAPI](https://newsdata.io/)** - Reliable news aggregation
- **[OpenAI](https://openai.com/)** - Powerful language models
- **[Firebase](https://firebase.google.com/)** - Robust backend infrastructure
- **[Mozilla Readability](https://github.com/mozilla/readability)** - Article extraction

---

<div align="center">

### 🌟 Star this repo if you find it interesting!

*Made to help millions of language learners access authentic content* 

</div>
