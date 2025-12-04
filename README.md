# English Vocabulary Learning App

A powerful and intuitive Flutter application designed to help you master English vocabulary effectively. Built with modern features like AI-powered word lookup, smart grouping, and interactive learning modes.

## 🌟 Key Features

### 📚 Smart Vocabulary Management
*   **Add Words Easily**: Quickly add new words.
*   **AI Integration**: Automatically fetches meanings, IPA pronunciation, and examples using **Gemini AI**.
*   **Batch Actions**: Select multiple words to delete or group them instantly.

### ⚙️ Flexible Configuration (New!)
*   **User Settings**: Configure your **Gemini API Key** and **Model Name** directly in the app.
*   **No Coding Required**: You don't need to edit code or configuration files to get started. Just enter your key in the Settings screen.
*   **Custom Models**: Switch between Gemini models (e.g., `gemini-2.0-flash`, `gemini-1.5-flash`) as needed.

### 🗂️ Word Grouping & Organization
*   **Create Groups**: Organize your vocabulary into custom groups (e.g., "Verbs", "Travel", "IELTS").
*   **Visual Organization**: Groups are displayed in distinct, bordered cards for easy scanning.
*   **Manage Groups**: Rename or delete groups with a simple long-press.
*   **Swipe Actions**:
    *   **Swipe Left ➡️ Right**: Delete a word (with confirmation).
    *   **Swipe Right ⬅️ Left**: Remove a word from its group.

### 🎮 Interactive Learning Modes
*   **Game Mode**: Test your knowledge with a multiple-choice game.
    *   **Filtered Play**: Select specific groups or words to focus your game session.
    *   **Global Play**: Play with your entire vocabulary collection.
*   **Review Mode**: Flashcard-style review to reinforce your memory.
    *   **TTS Support**: Listen to the correct pronunciation of words.

### ⚡ Efficient User Interface
*   **Always-on Selection**: Checkboxes are always visible for quick multi-selection.
*   **Select All**: One-tap selection for all words.
*   **Expand/Collapse**: Keep your home screen tidy by collapsing groups you aren't studying.

## 🛠️ Technology Stack
*   **Framework**: Flutter
*   **State Management**: Provider
*   **Local Storage**: Hive (NoSQL Database)
*   **AI Service**: Google Gemini API
*   **Text-to-Speech**: flutter_tts

## 🚀 Getting Started

1.  **Install the App**: Download the APK or build from source.
2.  **Configure API Key**:
    *   Open the app.
    *   Tap the **Settings (Gear)** icon in the top right.
    *   Enter your **Gemini API Key**.
    *   (Optional) Change the Model Name (default is `gemini-2.0-flash`).
    *   Tap **Save**.
3.  **Start Learning**: Add your first word!

*(Note: For developers, you can still use a `.env` file for development convenience, but the in-app settings will take precedence.)*

## 📱 Screenshots
*(Add your screenshots here)*

---
*Built with ❤️ for English Learners.*
