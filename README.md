# TarotReadingApp

An AI-powered tarot reading application developed in **SwiftUI** with **Firebase Firestore** integration and **OpenAI GPT** for dynamic text generation.  
The app allows users to log in, perform tarot readings, ask questions, and save their session history. It combines traditional tarot logic with modern AI-driven interpretations.

---

## Overview

The application provides three primary features:
- **Full Tarot Reading (7 cards)**: Generates a personalized reading using OpenAI GPT based on user data and selected cards.  
- **Daily Tarot**: Offers a single daily card reading with concise insights.  
- **Ask a Question**: Lets users draw three cards, enter a custom question, and receive an AI-generated answer.

User data and reading history are securely stored in **Firebase Firestore**. The app uses **SwiftUI** for a smooth and reactive interface.

---

## Core Features

- **AI Integration:** Uses OpenAI GPT API (Chat Completions) for generating tarot readings and Q&A responses.  
- **User Profile Management:** Includes user registration, profile editing (name, birth date, favourite category, relationship, and work status).  
- **History Management:** Stores and retrieves past tarot readings and user questions from Firestore.  
- **Local Persistence:** Saves user information locally with `UserDefaults` for faster app relaunch.  
- **Custom Animations:** Tarot cards are presented with flip and movement animations.

---

## Architecture

- **Framework:** SwiftUI  
- **Pattern:** MVVM (Model-View-ViewModel)  
- **Backend:** Firebase Firestore  
- **AI Service:** OpenAI GPT API  
- **Networking:** URLSession-based JSON communication  
- **Storage:** Firestore for remote data, UserDefaults for local caching  

---

## Project Structure

| File | Description |
|------|--------------|
| `TarotReadingAppApp.swift` | App entry point, initializes Firebase and main view model. |
| `ContentView.swift` | Handles authentication and main navigation. |
| `MainTarotView.swift` | Core 7-card tarot reading interface. |
| `DailyTarotView.swift` | Implements single-card daily reading. |
| `AskTarotView.swift` | Manages three-card question readings. |
| `HistoryView.swift` | Displays and manages saved readings and user questions. |
| `ProfileView.swift` | Handles profile creation, updates, and Firestore synchronization. |
| `TarotViewModel.swift` | Business logic, data loading, and OpenAI API integration. |
| `tarot-images.json` | Local dataset defining tarot card images and names. |

---

## Getting Started

### Prerequisites
- macOS with **Xcode 15 or later**
- A Firebase project with **Firestore** enabled
- An OpenAI API key (kept local and not committed)

### Setup
1. Clone the repository:
2. Add GoogleService-Info.plist from your Firebase project to the Xcode target.
3. In the code, replace the placeholder API key constant:
    private let apiKey = "YOUR_OPENAI_API_KEY"
4. Run the app on an iOS simulator or physical device.
