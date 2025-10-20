# Parachute App

Flutter frontend for Parachute - your open, interoperable second brain powered by Claude AI.

---

## Quick Start

```bash
# Get dependencies
flutter pub get

# Run on iOS simulator
flutter run

# Run on Android emulator
flutter run

# Run on Web (Chrome)
flutter run -d chrome

# Run on desktop (macOS/Windows/Linux)
flutter run -d macos  # or windows, linux
```

---

## Development

See **[CLAUDE.md](CLAUDE.md)** for complete development context.

### Common Commands

```bash
flutter run                 # Run app
flutter test               # Run tests
flutter analyze            # Analyze code
flutter pub get            # Get dependencies
flutter clean              # Clean build artifacts

# Code generation (for Riverpod)
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Project Structure

```
app/
├── lib/
│   ├── main.dart              # Entry point
│   ├── core/                  # App-wide concerns
│   │   ├── constants/         # API URLs, constants
│   │   ├── theme/             # Themes
│   │   ├── router/            # Navigation
│   │   └── config/            # Configuration
│   ├── features/              # Features (auth, spaces, chat, settings)
│   │   └── [feature]/
│   │       ├── presentation/  # Screens, widgets
│   │       ├── providers/     # Riverpod providers
│   │       └── models/        # Data models
│   └── shared/                # Shared across features
│       ├── widgets/           # Reusable widgets
│       ├── services/          # API, WebSocket
│       └── models/            # Shared models
├── test/                      # Tests
└── dev-docs/                  # Developer docs
```

---

## Documentation

- **[CLAUDE.md](CLAUDE.md)** - Development context for AI assistants
- **[dev-docs/](dev-docs/)** - Detailed developer documentation
- **[../ARCHITECTURE.md](../ARCHITECTURE.md)** - Overall system architecture

---

## Prerequisites

- Flutter 3.24+
- Dart 3.5+

See **[../docs/SETUP.md](../docs/SETUP.md)** for detailed setup instructions.

---

## Configuration

### API Base URL

```bash
# Development (default)
flutter run

# Custom backend
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8080

# Production
flutter run --dart-define=API_BASE_URL=https://api.parachute.app
```

---

## Building for Production

### iOS

```bash
flutter build ios --release
# Open ios/Runner.xcworkspace in Xcode
# Archive and submit to App Store
```

### Android

```bash
# APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

### Web

```bash
flutter build web --release
# Deploy contents of build/web/
```

### Desktop

```bash
# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

---

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/features/chat/chat_screen_test.dart
```

---

## Platforms Supported

- ✅ iOS (iPhone, iPad)
- ✅ Android (Phone, Tablet)
- ✅ Web (Chrome, Safari, Firefox, Edge)
- ✅ macOS (Desktop)
- ✅ Windows (Desktop)
- ✅ Linux (Desktop)

---

## License

TBD

---

**Last Updated:** October 20, 2025
**Status:** Foundation phase - Ready for implementation
