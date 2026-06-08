# Speda Mark IV

**Built in February 2025 — Recovered June 2026**

The fourth iteration of SPEDA (Specialized Personal Executive Digital Assistant), built as a mobile-first personal AI assistant using Flutter and Dart.

## Features

- **Conversational AI**: Powered by the GPT-4o-mini model.
- **Google Calendar Integration**: List, add, and summarize upcoming events.
- **Authentication**: Secure Firebase Authentication with Google Sign-In.
- **Web Search**: Integrated web search via Google Custom Search API.
- **Image Support**: Image attachment and analysis capabilities.
- **Local Push Notifications**: Reminders for calendar events.
- **Custom UI**: Dark blue theme featuring custom Logirent and Azbuka fonts.

## Architecture & History

In this iteration, the project architecture was highly centralized:
- `lib/screens/openai_service.dart` handles all backend and API logic.
- `lib/screens/chat_screen.dart` contains the complete user interface.

*Note: This structural approach was revised and improved in Mark VI.*

## Project Lineage

Mark I ➔ Mark II ➔ *(Mark III lost)* ➔ **Mark IV (this repository)** ➔ Mark V ➔ Mark VI

## Setup Instructions

To run this application locally:

1. **API Keys**: Add your API keys to `lib/screens/secrets.dart`.
2. **Firebase Configuration**: 
   - For Android, add `google-services.json` to the correct Android directory.
   - For iOS, add `GoogleService-Info.plist` to the correct iOS directory.
3. **Assets**: Ensure your custom fonts are placed in `assets/fonts/`.
4. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
5. **Run the App**:
   ```bash
   flutter run
   ```
