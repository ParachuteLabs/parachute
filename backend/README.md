# Parachute Backend

Go backend service for Parachute - your open, interoperable second brain powered by Claude AI.

---

## Quick Start

```bash
# Install dependencies
go mod download

# Create data directories
make setup

# Copy environment template
cp .env.example .env

# Edit .env and add your Anthropic API key

# Run development server
make run
```

Backend runs on http://localhost:8080

**Health Check:**
```bash
curl http://localhost:8080/health
```

---

## Development

See **[CLAUDE.md](CLAUDE.md)** for complete development context.

### Common Commands

```bash
make run          # Run development server
make dev          # Run with hot reload (requires air)
make test         # Run tests
make build        # Build production binary
make clean        # Clean artifacts
```

### Project Structure

```
backend/
├── cmd/server/          # Application entry point
├── internal/
│   ├── api/            # HTTP handlers, WebSocket, middleware
│   ├── domain/         # Business logic
│   ├── acp/            # ACP integration
│   ├── storage/        # Database layer
│   └── config/         # Configuration
├── dev-docs/           # Developer documentation
├── CLAUDE.md           # AI assistant context
└── Makefile            # Development commands
```

---

## Documentation

- **[CLAUDE.md](CLAUDE.md)** - Development context for AI assistants
- **[dev-docs/](dev-docs/)** - Detailed developer documentation
  - [ACP-INTEGRATION.md](dev-docs/ACP-INTEGRATION.md) - ACP implementation guide
  - [DATABASE.md](dev-docs/DATABASE.md) - Database schema and queries
  - [WEBSOCKET-PROTOCOL.md](dev-docs/WEBSOCKET-PROTOCOL.md) - WebSocket events
  - [TESTING.md](dev-docs/TESTING.md) - Testing strategy
  - [DEPLOYMENT.md](dev-docs/DEPLOYMENT.md) - Deployment guide

---

## Prerequisites

- Go 1.25+
- Node.js 18+ (for claude-code-acp)
- Anthropic API key

See **[../docs/SETUP.md](../docs/SETUP.md)** for detailed setup instructions.

---

## Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
PORT=8080
DATABASE_PATH=./data/parachute.db
ANTHROPIC_API_KEY=sk-ant-your-key-here
JWT_SECRET=<generate-with-openssl-rand>
SPACES_PATH=./data/spaces
LOG_LEVEL=info
```

---

## API Endpoints

### Health Check
```
GET /health
```

### Spaces (Future)
```
GET    /api/spaces              # List spaces
POST   /api/spaces              # Create space
GET    /api/spaces/:id          # Get space
PUT    /api/spaces/:id          # Update space
DELETE /api/spaces/:id          # Delete space
```

### Conversations (Future)
```
GET  /api/conversations?space_id=...  # List conversations
POST /api/messages                    # Send message
```

### WebSocket (Future)
```
WS /ws  # Real-time chat streaming
```

---

## Testing

```bash
# Run all tests
make test

# Run with verbose output
make test-v

# Generate coverage report
make test-coverage
```

---

## Building for Production

```bash
# Build binary
make build

# Binary location
./bin/server

# Run in production
./bin/server
```

---

## License

TBD

---

**Last Updated:** October 20, 2025
**Status:** Foundation phase - Ready for implementation
