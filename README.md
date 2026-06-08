# Speda Mark IV

**Built in February 2025 — RecoveredJune 2026**

The fourth iteration of SPEDA (Specialized Personal Executive Digital Assistant), built in Flutter/Dart.

## What This Was

A mobile-first personal AI assistant with:
- GPT-4o-mini powered chat
- Google Calendar integration (list, add, summarize events)
- Firebase Authentication with Google Sign In
- Web search via Google Custom Search API
- Image attachment and analysis
- Local push notifications for calendar events
- Dark blue UI with custom Logirent/Azbuka fonts

## Architecture (Such As It Was)

Everything lived in two files:
- `lib/screens/openai_service.dart` — all backend logic
- `lib/screens/chat_screen.dart` — all UI

This is what Mark VI fixed.

## Setup

1. Add your API keys to `lib/screens/secrets.dart`
2. Configure Firebase (add `google-services.json` for Android / `GoogleService-Info.plist` for iOS)
3. Add your custom fonts to `assets/fonts/`
4. Run `flutter pub get`
5. Run `flutter run`

## Lineage

Mark I → Mark II → *(Mark III lost)* → **Mark IV (this)** → Mark V → Mark VI
