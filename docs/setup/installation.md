# Parachute - Setup Guide

**Last Updated:** October 20, 2025

This guide will help you set up your development environment for Parachute.

---

## Prerequisites

### Required Software

1. **Go 1.25+**
2. **Flutter 3.24+**
3. **Node.js 18+** (for claude-code-acp)
4. **Git**

### Optional but Recommended

- **VSCode** with Go and Flutter extensions
- **DB Browser for SQLite** (for database inspection)
- **Postman** or **Insomnia** (for API testing)

---

## Installation Steps

### 1. Install Go

**macOS (Homebrew):**
```bash
brew install go

# Verify
go version
# Should show: go version go1.25.x darwin/arm64 (or amd64)
```

**Linux:**
```bash
# Download from https://go.dev/dl/
wget https://go.dev/dl/go1.25.x.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.25.x.linux-amd64.tar.gz

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH=$PATH:/usr/local/go/bin

# Verify
go version
```

**Windows:**
- Download installer from https://go.dev/dl/
- Run installer
- Verify in PowerShell: `go version`

### 2. Install Flutter

**macOS (Homebrew):**
```bash
brew install --cask flutter

# Verify
flutter doctor
```

**Linux:**
```bash
# Download from https://docs.flutter.dev/get-started/install/linux
cd ~/development
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.x-stable.tar.xz
tar xf flutter_linux_3.24.x-stable.tar.xz

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$PATH:~/development/flutter/bin"

# Verify
flutter doctor
```

**Windows:**
- Download from https://docs.flutter.dev/get-started/install/windows
- Extract to C:\src\flutter
- Add to PATH
- Verify: `flutter doctor`

**Run Flutter Doctor:**
```bash
flutter doctor
```

This will check for:
- Flutter SDK
- Android toolchain (for Android development)
- Xcode (for iOS development, macOS only)
- Chrome (for web development)
- VSCode or Android Studio

Follow any recommendations from `flutter doctor` to complete setup.

### 3. Install Node.js

**macOS (Homebrew):**
```bash
brew install node

# Verify
node -v
# Should show: v18.x or v20.x

npm -v
# Should show: 9.x or 10.x
```

**Linux:**
```bash
# Using NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify
node -v
npm -v
```

**Windows:**
- Download installer from https://nodejs.org/
- Run installer
- Verify: `node -v` and `npm -v`

### 4. Verify claude-code-acp

```bash
npx @zed-industries/claude-code-acp --version
```

This should download (if needed) and show the version. If this works, your environment is ready!

---

## Platform-Specific Setup

### iOS Development (macOS only)

1. **Install Xcode:**
   - Download from Mac App Store
   - Or download from https://developer.apple.com/xcode/

2. **Accept Xcode license:**
   ```bash
   sudo xcodebuild -license accept
   ```

3. **Install iOS simulator:**
   ```bash
   open -a Simulator
   ```

4. **Configure signing:**
   - Open Xcode
   - Preferences → Accounts → Add Apple ID
   - Or use "Automatically manage signing" in Flutter

### Android Development (All platforms)

1. **Install Android Studio:**
   - Download from https://developer.android.com/studio
   - Run installer

2. **Install Android SDK:**
   - Open Android Studio
   - SDK Manager → Install latest Android SDK
   - Install Android SDK Command-line Tools

3. **Accept Android licenses:**
   ```bash
   flutter doctor --android-licenses
   ```

4. **Create Android emulator:**
   - Open Android Studio
   - Tools → AVD Manager → Create Virtual Device
   - Choose Pixel 5 or similar
   - Download system image (API 33 recommended)
   - Finish and launch emulator

### Web Development (All platforms)

Web development works out of the box with Flutter. Just need Chrome:

```bash
# Verify
flutter devices
# Should show Chrome listed
```

### Desktop Development

**macOS:**
```bash
# Already supported, no extra setup needed
flutter config --enable-macos-desktop
```

**Linux:**
```bash
flutter config --enable-linux-desktop

# Install required libraries
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

**Windows:**
```bash
flutter config --enable-windows-desktop

# Visual Studio required (not just VS Code)
# Download from https://visualstudio.microsoft.com/
```

---

## Project Setup

### Clone Repository

```bash
cd ~/Projects  # or wherever you keep projects
git clone https://github.com/yourusername/parachute.git
cd parachute
```

### Backend Setup

```bash
cd backend

# Initialize Go modules (if not already done)
go mod init github.com/yourusername/parachute-backend

# Download dependencies
go mod tidy

# Create .env file
cp .env.example .env

# Edit .env and add your Anthropic API key
# ANTHROPIC_API_KEY=sk-ant-...
```

### Frontend Setup

```bash
cd app

# Get Flutter dependencies
flutter pub get

# Run code generation (if using build_runner)
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Verify Installation

### Test Backend

```bash
cd backend
go run cmd/server/main.go
```

You should see:
```
Starting server on port 8080
```

In another terminal:
```bash
curl http://localhost:8080/health
```

Should return:
```json
{"status":"ok","service":"parachute-backend"}
```

Press Ctrl+C to stop the server.

### Test Frontend

```bash
cd app
flutter run
```

Choose a device (press number):
- iOS simulator
- Android emulator
- Chrome
- Desktop

App should launch and show "Parachute" home screen.

---

## Troubleshooting

### Go Issues

**Problem:** `go: command not found`
**Solution:** Go not in PATH. Add to ~/.bashrc or ~/.zshrc:
```bash
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$(go env GOPATH)/bin
```

**Problem:** Module errors
**Solution:** Run `go mod tidy` to clean up dependencies

### Flutter Issues

**Problem:** `flutter: command not found`
**Solution:** Flutter not in PATH. Add to ~/.bashrc or ~/.zshrc:
```bash
export PATH="$PATH:~/development/flutter/bin"
```

**Problem:** "Android licenses not accepted"
**Solution:** Run `flutter doctor --android-licenses`

**Problem:** "Xcode not properly configured"
**Solution:**
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

**Problem:** iOS simulator not showing up
**Solution:** Open Xcode, go to Window → Devices and Simulators, create new simulator

### Node.js Issues

**Problem:** `npx: command not found`
**Solution:** Node.js not installed or not in PATH

**Problem:** claude-code-acp fails to download
**Solution:** Check internet connection, or run `npm install -g @zed-industries/claude-code-acp`

---

## IDE Setup

### VSCode (Recommended)

**Install Extensions:**
- Go (by Go Team)
- Flutter (by Dart Code)
- Dart (by Dart Code)
- SQLite Viewer (by qwtel)

**Settings (`.vscode/settings.json`):**
```json
{
  "go.useLanguageServer": true,
  "go.lintOnSave": "file",
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.selectionHighlight": false,
    "editor.suggest.snippetsPreventQuickSuggestions": false,
    "editor.suggestSelection": "first",
    "editor.tabCompletion": "onlySnippets",
    "editor.wordBasedSuggestions": "off"
  }
}
```

### GoLand / IntelliJ IDEA

- Install Go plugin
- Import backend directory as Go module
- Enable Go modules support

### Android Studio

- Flutter and Dart plugins should be installed
- Import app directory as Flutter project

---

## Environment Variables

### Backend (.env)

Create `backend/.env`:

```bash
# Server
PORT=8080
LOG_LEVEL=debug

# Database
DATABASE_PATH=./data/parachute.db

# Anthropic API
ANTHROPIC_API_KEY=sk-ant-your-key-here

# JWT (generate random string)
JWT_SECRET=your-random-secret-key-at-least-32-chars

# Spaces storage
SPACES_PATH=./data/spaces

# Node.js paths (optional, auto-detected)
NODE_PATH=/usr/local/bin/node
NPX_PATH=/usr/local/bin/npx
```

**Generate JWT Secret:**
```bash
openssl rand -base64 32
```

### Frontend

Flutter uses build-time environment variables:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Or create `app/.env` (requires flutter_dotenv package):
```bash
API_BASE_URL=http://localhost:8080
WS_URL=ws://localhost:8080/ws
```

---

## Next Steps

Once setup is complete:

1. Read [DEVELOPMENT-WORKFLOW.md](DEVELOPMENT-WORKFLOW.md) for day-to-day development
2. Check [ROADMAP.md](ROADMAP.md) for implementation priorities
3. Review `backend/CLAUDE.md` and `app/CLAUDE.md` for component-specific context
4. Start with backend ACP integration (see `backend/dev-docs/ACP-INTEGRATION.md`)

---

## Getting Help

**Setup Issues:**
- Check [Troubleshooting](#troubleshooting) section above
- Review official docs: [Go](https://go.dev/doc/), [Flutter](https://docs.flutter.dev/)
- Search existing issues on GitHub

**Development Questions:**
- See `DEVELOPMENT-WORKFLOW.md`
- Check component CLAUDE.md files
- Review dev-docs in backend/ and app/

---

**Last Updated:** October 20, 2025
**Status:** Setup guide complete for foundation phase
