# Celestera — Intelligent Multimodal Mobile AI Assistant

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Firestore-FFCA28?style=flat-square&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Groq](https://img.shields.io/badge/Groq-LLM%20Inference-F55036?style=flat-square)](https://groq.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

A production-ready, feature-complete mobile AI assistant built with Flutter and Dart. Celestera combines fast cloud inference (Groq), multimodal image generation (Gradio), voice interaction, local on-device biometric security, and persistent Firebase cloud synchronization.

---

## ⚡ Key Highlights

- 🔐 **On-Device Biometric Security**: Native fingerprint and facial authentication (`biometric_service.dart`) with secure PIN fallback and encrypted chat session locking (`chat_lock_service.dart`).
- ⚡ **Ultra-Fast Cloud Inference**: Integrated with Groq API (`groq_service.dart`) for streaming high-speed conversational intelligence.
- 🎨 **Multimodal Image Generation**: Built-in diffusion image generation pipeline (`gradio_image_service.dart`, `image_generation_service.dart`).
- 🎙️ **Voice Interaction Pipeline**: Real-time speech-to-text recording and voice response synthesis (`voice_service.dart`).
- 🧠 **Local NLP & Command Processing**: On-device intent classifier and command router (`nlp_classifier.dart`, `command_processor.dart`) that parses structured commands directly.
- 🎭 **Dynamic Bot Personas**: Configurable system personas, temperature controls, and context management (`persona_service.dart`, `bot_config_service.dart`).
- ☁️ **Cloud Synchronization**: User profiles, persistent chat history, and document indexing via Firebase Firestore and Auth (`firebase_chat_service.dart`).
- 📱 **Adaptive UI/UX**: Fluid dark/light themes, Provider state management, animated markdown chat bubbles, and interactive bot selector modals.

---

## 🏗️ Architecture & Project Structure

```
lib/
├── auth/                      # Native authentication providers
│   └── biometric_service.dart # Local_auth wrapper for fingerprint/FaceID
├── config/                    # Environment & API configurations
│   └── app_config.dart        # Groq/Firebase endpoints and runtime flags
├── models/                    # Immutable data transfer objects
│   ├── chat_model.dart        # Chat session schemas
│   ├── message_model.dart     # Multimodal message entities (Text, Audio, Image)
│   └── user_profile.dart      # User preferences and security parameters
├── providers/                 # State management layer (Provider)
│   ├── auth_provider.dart     # Authentication state machine
│   ├── chat_provider.dart     # Streaming messages, history, and token counts
│   └── theme_provider.dart    # Dynamic system/dark/light theme controller
├── screens/                   # Top-level screen views
│   ├── splash_screen.dart     # Initializing boot sequence
│   ├── login_screen.dart      # Firebase Auth login / registration
│   ├── home_screen.dart       # Main chat viewport with animated input bar
│   ├── bot_settings_screen.dart # Persona tuning & system prompts
│   ├── settings_screen.dart   # Security, API keys, and cache management
│   └── todo_screen.dart       # Extracted tasks and action items
├── services/                  # Business logic & external integrations
│   ├── ai_services.dart       # General AI orchestrator
│   ├── groq_service.dart      # Groq LLM API client
│   ├── gradio_image_service.dart # Gradio API client for image generation
│   ├── voice_service.dart     # Audio recording & text-to-speech engine
│   ├── nlp_classifier.dart    # Natural language intent recognition
│   ├── command_processor.dart # Action dispatcher
│   ├── chat_lock_service.dart # Session encryption and biometric gatekeeper
│   └── firebase_chat_service.dart # Cloud Firestore sync & real-time listeners
└── widgets/                   # Reusable UI components
    ├── message_bubble.dart    # Markdown-rendered speech bubbles
    ├── bot_selection_modal.dart # Bottom-sheet persona picker
    ├── chat_lock_widget.dart  # Secure PIN authentication overlay
    └── sidebar_drawer.dart    # Conversation drawer & user profile badge
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: `>=3.0.0 <4.0.0`
- **Dart SDK**: Compatible with Flutter SDK
- **Android Studio** / **Xcode**
- **Groq API Key**: [console.groq.com](https://console.groq.com)
- **Firebase Project**: Configured for Android/iOS

### Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/AT-1006/Celestera-AI.git
   cd Celestera-AI
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Configure API Keys**:
   Update `lib/config/app_config.dart` or supply environment variables:
   ```dart
   const String groqApiKey = 'YOUR_GROQ_API_KEY';
   ```

4. **Run on connected device or simulator**:
   ```bash
   flutter run
   ```

---

## 🔒 Security Architecture

- **Biometric Enclave**: Hardware-backed biometric confirmation via Android BiometricPrompt and iOS LocalAuthentication.
- **PIN Lock Protocol**: Offline SHA-256 hashed PIN gate for individual session confidentiality.
- **Client-Side Key Hygiene**: API keys are isolated from version control and bound to user sessions.

---

## 📄 License

MIT License © 2026 Atharv Gawand
