# English Vocabulary Learning App

A powerful, cloud-synced Flutter application designed to help you master English vocabulary. Features AI-powered lookup, smart Spaced Repetition (SRS), and cross-device synchronization.

## 🌍 Web Version
Ứng dụng hiện đã có bản Web chính thức tại: [https://learn-english-85f06.web.app](https://learn-english-85f06.web.app)

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

### 🧠 AI-Powered by Gemini & Bulk Tools
*   **Auto-Definition**: Automatically fetches meanings, IPA, and examples for new words.
*   **Bulk Word Adding [NEW]**: Dán danh sách từ vựng số lượng lớn theo định dạng `Từ Loại_từ /Phiên_âm/ Nghĩa`. Hệ thống tự động phân tách và thêm vào kho từ của bạn mà không cần Gemini API Key.
*   **Flexible Config**: Enter your own **Gemini API Key** and choose your preferred model (e.g., `gemini-1.5-flash`, `gemini-1.5-pro`) directly in the app.

### 📚 Rich Vocabulary Structure
*   **Deep Linguistic Data**: Words store comprehensive details:
    *   **Multiple Meanings**: Categorized by Part of Speech (Noun, Verb, Adj).
    *   **Verb Forms**: Learn conjugations alongside the base form.
    *   **Pronunciation**: Both US 🇺🇸 and UK 🇬🇧 IPA transcriptions.
*   **Status Editor [NEW]**: Chỉnh sửa trực quan trạng thái thuộc bài (4 mức độ từ Đỏ đến Xanh) ngay trong màn hình chi tiết từ vựng.

### ⚡ Smart Learning (SRS)
*   **Flashcard Review**: Tự động lọc và **loại bỏ các từ đã thạo** (Status 3 - Xanh lá) khỏi danh sách ôn tập hàng ngày để tập trung vào từ mới và từ khó.
*   **Selection Mode**: Hỗ trợ chọn nhiều từ cùng lúc để xóa hàng loạt hoặc gộp nhóm. Tính năng xóa đã được tối ưu hóa bằng Firebase Write Batch để đảm bảo tốc độ và độ tin cậy.

### 🔔 Reliable Notification System (Android)
*   **Enhanced Stability**: Optimized for **Android 13+** using `permission_handler`.
*   **Smart Scheduling**: Automated reminders 5 times per day.
*   **Persistent Mode**: High-priority notifications that stay visible until interacted with.

### 🎮 Interactive Notification Games (Android)
*   **Active Recall**: Turn passive notifications into active learning moments.
*   **Game Modes**:
    *   **Multiple Choice 🎯**: Choose the correct meaning directly in the notification.
    *   **Direct Input ✍️**: Type the meaning of a word in the notification reply box.

---

## 🛠️ Technology Stack
*   **Frontend**: Flutter (Provider for state management).
*   **Backend**: Firebase (Auth, Firestore, Hosting).
*   **Local Settings**: Hive (for API keys & preferences).
*   **AI**: Google Gemini API.
*   **Audio**: flutter_tts.

## 🚀 Getting Started

### Web
Truy cập trực tiếp: [https://learn-english-85f06.web.app](https://learn-english-85f06.web.app)

### Android
1.  **Install**: Run the app on your Android device/emulator.
2.  **Login**: Sign in with your Google account.
3.  **Setup AI**:
    *   Go to **Settings** (Gear icon).
    *   Enter your **Gemini API Key**.
4.  **Start Learning**: Add a word or paste a bulk list!

---
*Built with ❤️ for English Learners.*
