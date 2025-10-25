# Parachute

> "The mind is like a parachute, it doesn't work if it's not open" — Frank Zappa

**Your open, interoperable second brain powered by Claude AI**

---

## What is Parachute?

Parachute is a cross-platform application that makes the Agent Client Protocol (ACP) as accessible as Claude Desktop, but with the power of local file access, MCP servers, and true multi-platform availability. It also includes integrated voice recording capabilities with AI transcription.

### Core Features

**AI Chat with Spaces**
Each **Space** is a cognitive context - a room in your digital memory palace:
- Has its own `CLAUDE.md` file (persistent AI memory)
- Contains relevant files and resources
- Independent conversation history
- Optional MCP server configurations
- Works across all your devices

**Voice Recorder**
Capture thoughts and conversations effortlessly:
- Local microphone recording
- Omi device integration (Bluetooth pendant)
- Local AI transcription using Whisper
- Recording management and playback
- Future: Cloud sync and AI chat integration

### Built on Openness

1. **Open Protocols** - Built on ACP & MCP (not proprietary)
2. **Open Data** - Your files, your control, standard formats
3. **Open Platforms** - iOS, Android, Web, Desktop
4. **Open Integration** - Connect to anything via MCP servers

---

## Technology Stack

- **Backend:** Go 1.25+ (Fiber web framework, SQLite database)
- **Frontend:** Flutter 3.24+ (iOS, Android, Web, Desktop)
- **AI Integration:** Agent Client Protocol (ACP) via claude-code-acp
- **Extensibility:** Model Context Protocol (MCP)

---

## Project Structure

```
parachute/
├── backend/          # Go backend service (REST API + WebSocket)
├── app/             # Flutter frontend (cross-platform UI)
├── docs/            # Shared documentation
├── scripts/         # Development and deployment scripts
└── README.md        # This file
```

---

## Quick Start

### Prerequisites

- Go 1.25+
- Flutter 3.24+
- Node.js 18+ (for claude-code-acp)

### Backend

```bash
cd backend
go run cmd/server/main.go
```

Backend runs on http://localhost:8080

### Frontend (Flutter App)

```bash
cd app
flutter run -d macos  # or ios, chrome, etc.
```

The app includes two main features accessible via bottom navigation:
- **AI Chat** - Spaces, conversations, and Claude AI interaction
- **Recorder** - Voice recording with transcription

---

## Documentation

- **[Architecture](ARCHITECTURE.md)** - System design and technical decisions
- **[Branding](docs/BRANDING.md)** - Brand identity and philosophy
- **[Launch Guide](docs/LAUNCH-GUIDE.md)** - Comprehensive implementation guide
- **[Setup Guide](docs/SETUP.md)** - Environment setup instructions
- **[Development Workflow](docs/DEVELOPMENT-WORKFLOW.md)** - Day-to-day development
- **[Roadmap](docs/ROADMAP.md)** - Implementation phases and progress

### Component Documentation

- **Backend:** See `backend/CLAUDE.md` and `backend/dev-docs/`
- **Frontend:** See `app/CLAUDE.md` and `app/dev-docs/`

---

## Current Status

🚧 **In Development** - Foundation Phase

We're currently setting up the project structure and core documentation. See [ROADMAP.md](docs/ROADMAP.md) for detailed progress.

**Completed:**
- [x] Project structure
- [x] Core documentation
- [ ] Backend skeleton
- [ ] Frontend skeleton
- [ ] ACP integration
- [ ] Core features
- [ ] MVP release

---

## Target Users

**Primary:**
- Knowledge workers organizing information
- Researchers managing sources and notes
- Writers working on multiple projects
- Consultants managing client contexts

**Future:**
- Developers (complementary to IDE)
- Teams and organizations

---

## Why Parachute?

| Feature | Parachute | Claude Desktop | Claude Code | Zed |
|---------|-----------|---------------|-------------|-----|
| **Mobile Access** | ✅ | ❌ | ❌ | ❌ |
| **File Access** | ✅ | ❌ | ✅ | ✅ |
| **MCP Servers** | ✅ | ❌ | ✅ | ✅ |
| **Spaces/Context** | ✅ | ❌ | ⚠️ | ⚠️ |
| **Open Protocol** | ✅ | ❌ | ✅ | ✅ |
| **Use Case** | Second brain | Chat | Coding | IDE |

**Our Niche:** The only open, cross-platform second brain for Claude AI

---

## Contributing

This is currently a personal project in early development. Once we reach MVP, we'll open up for contributions.

---

## License

TBD - Will be decided before public release

---

## Contact

Questions? Ideas? Reach out: [contact info TBD]

---

**Status:** Foundation Phase - Last Updated: October 20, 2025
