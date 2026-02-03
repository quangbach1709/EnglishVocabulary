# English Vocabulary Learning App

A powerful, cloud-synced Flutter application designed to help you master English vocabulary. Features AI-powered lookup, smart Spaced Repetition (SRS), and cross-device synchronization.

## 🌟 New & Key Features

### ☁️ Cloud Sync & Authentication
*   **Google Sign-In**: Securely log in with your Google account.
*   **Real-time Sync**: Your vocabulary and grammar topics are synced across all your devices using **Firebase Cloud Firestore**.
*   **User Profiles**: Every user has their own private data space.

### 🔊 Advanced Text-to-Speech (TTS)
*   **Global Audio Settings**: Customize your listening experience in Settings:
    *   **Accent Control**: Choose between US, UK, Australian, or Irish voices.
    *   **Speed Control**: Adjust speech rate from 0.1x (Slow) to 1.0x (Fast).
*   **Instant Pronunciation**: Tap the speaker icon 🔊 in the "Edit Word" screen to hear the correct pronunciation immediately.

### 🧠 AI-Powered by Gemini
*   **Auto-Definition**: Automatically fetches meanings, IPA, and examples for new words.
*   **Flexible Config**: Enter your own **Gemini API Key** and choose your preferred model (e.g., `gemini-1.5-flash`, `gemini-1.5-pro`) directly in the app.
*   **Privacy-First**: Your API key is stored locally on your device.

### ⚡ Smart Learning & Management
### 📚 Rich Vocabulary Structure [NEW]
*   **Deep Linguistic Data**: Words now store comprehensive details beyond just meaning:
    *   **Multiple Meanings**: Definitions are categorized by Part of Speech (Noun, Verb, Adj) with specific translations.
    *   **Verb Forms**: Learn conjugations (Past Tense, Participles) alongside the base form.
    *   **Pronunciation**: Includes both US 🇺🇸 and UK 🇬🇧 IPA transcriptions and audio support.
    *   **Contextual Examples**: Sentences are tied to specific definitions, helping you understand nuance.

### 🎮 Interactive Notification Games [NEW]
*   **Active Recall**: Turn passive notifications into active learning moments 3 times a day (Morning, Noon, Evening).
*   **Game Modes**:
    *   **Multiple Choice 🎯**: Choose the correct meaning from 3 options directly in the notification.
    *   **Direct Input ✍️**: Type the meaning of a word in the notification reply box. Includes a "Show Answer" hint button.
*   **Spaced Repetition**: The system intelligently picks words you struggle with (80% chance) vs. words you've mastered (20% review).
*   **Persistent Learning**: Notifications stick until you interact, ensuring you never miss a daily goal.

### ⚡ Smart Learning & Management
*   **Proof of Knowledge**: Answering correctly in notifications automatically updates the word's review status to "Good".
*   **Grouping**: Organize words into custom groups (e.g., "IELTS", "Verbs").
*   **Swipe Actions**:
    *   **Swipe Right**: Remove from group.
    *   **Swipe Left**: Delete word.
*   **Selection Mode**: Batch delete or group words easily.

---

## 🛠️ Technology Stack
*   **Frontend**: Flutter (Provider for state management).
*   **Backend**: Firebase (Auth, Firestore).
*   **Local Settings**: Hive (for API keys & preferences).
*   **AI**: Google Gemini API.
*   **Audio**: flutter_tts.

## 🚀 Getting Started

1.  **Install**: Run the app on your Android device/emulator.
2.  **Login**: Sign in with your Google account.
3.  **Setup AI**:
    *   Go to **Settings** (Gear icon).
    *   Enter your **Gemini API Key**.
    *   (Optional) Customize your **Global TTS** settings (Voice & Speed).
4.  **Start Learning**: Add a word and watch the AI fill in the details!

---
*Built with ❤️ for English Learners.*
