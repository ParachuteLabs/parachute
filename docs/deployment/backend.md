# Deployment Guide

**Status:** To be finalized before Phase 7 (MVP Release)

---

## Overview

This guide covers deploying the Parachute backend to various environments.

---

## Deployment Options

### Option 1: Mac Mini + Tailscale (Recommended for Beta)

**Pros:**
- Free (hardware you own)
- Private network via Tailscale
- Full control
- Good for beta testing

**Cons:**
- Requires Mac Mini
- Manual setup
- You manage uptime

**Setup:**

1. Install Tailscale on Mac Mini
2. Build backend binary
3. Set up as launch daemon
4. Access via Tailscale IP

### Option 2: Render.com

**Pros:**
- Easy deploy from Git
- Managed service
- HTTPS included
- $7/month

**Cons:**
- Costs money
- Less control

**Setup:**

1. Create Render account
2. Connect GitHub repo
3. Configure build command: `go build -o server cmd/server/main.go`
4. Set environment variables
5. Deploy

### Option 3: Fly.io

**Pros:**
- Global edge deployment
- Pay-as-you-go
- Good for scaling

**Cons:**
- More complex
- Can get expensive

**Setup:**

```bash
fly launch
fly deploy
```

### Option 4: Docker + Any Host

**Pros:**
- Run anywhere
- Reproducible
- Easy to scale

**Cons:**
- Requires Docker knowledge

---

## Building for Production

### Local Build

```bash
# Build binary
make build

# Binary location: bin/server
./bin/server
```

### Cross-Platform Builds

```bash
# For Linux (most servers)
GOOS=linux GOARCH=amd64 go build -o bin/server-linux cmd/server/main.go

# For macOS Intel
GOOS=darwin GOARCH=amd64 go build -o bin/server-mac-intel cmd/server/main.go

# For macOS Apple Silicon
GOOS=darwin GOARCH=arm64 go build -o bin/server-mac-arm cmd/server/main.go
```

---

## Environment Configuration

Create `.env.production`:

```bash
PORT=8080
DATABASE_PATH=/var/lib/parachute/parachute.db
SPACES_PATH=/var/lib/parachute/spaces
LOG_LEVEL=info
JWT_SECRET=<production-secret>
# Don't set ANTHROPIC_API_KEY here - users provide their own
```

---

## Mac Mini Deployment (Detailed)

### 1. Build Binary

```bash
# On development machine
cd backend
GOOS=darwin GOARCH=arm64 go build -o bin/server cmd/server/main.go

# Copy to Mac Mini
scp bin/server macmini:~/parachute/server
scp .env.production macmini:~/parachute/.env
```

### 2. Create Launch Daemon

Create `/Library/LaunchDaemons/com.parachute.backend.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.parachute.backend</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/you/parachute/server</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/you/parachute</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/Users/you/parachute/logs/error.log</string>
    <key>StandardOutPath</key>
    <string>/Users/you/parachute/logs/output.log</string>
</dict>
</plist>
```

Load:
```bash
sudo launchctl load /Library/LaunchDaemons/com.parachute.backend.plist
```

### 3. Install Tailscale

```bash
# On Mac Mini
brew install tailscale
sudo tailscale up

# Note the Tailscale IP (e.g., 100.x.x.x)
```

### 4. Access from Mobile

On iOS/Android device:
1. Install Tailscale
2. Connect to your network
3. Access backend: `http://100.x.x.x:8080`

---

## Render.com Deployment (Detailed)

### 1. Create `render.yaml`

```yaml
services:
  - type: web
    name: parachute-backend
    env: go
    buildCommand: go build -o server cmd/server/main.go
    startCommand: ./server
    envVars:
      - key: PORT
        value: 8080
      - key: DATABASE_PATH
        value: /var/data/parachute.db
      - key: SPACES_PATH
        value: /var/data/spaces
      - key: LOG_LEVEL
        value: info
      - key: JWT_SECRET
        generateValue: true
    disk:
      name: parachute-data
      mountPath: /var/data
      sizeGB: 10
```

### 2. Deploy

1. Push to GitHub
2. Connect repo in Render dashboard
3. Render auto-deploys on push

---

## Docker Deployment

### Dockerfile

```dockerfile
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build
RUN go build -o server cmd/server/main.go

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates nodejs npm

WORKDIR /root/

# Copy binary
COPY --from=builder /app/server .

# Expose port
EXPOSE 8080

# Run
CMD ["./server"]
```

### Build and Run

```bash
# Build image
docker build -t parachute-backend .

# Run container
docker run -d \
  -p 8080:8080 \
  -v $(pwd)/data:/var/data \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -e JWT_SECRET=your-secret \
  parachute-backend
```

---

## Health Checks

All deployments should monitor health:

```bash
curl http://your-backend/health
```

Expected response:
```json
{"status":"ok","service":"parachute-backend","version":"0.1.0"}
```

---

## Logging

### Structured Logging

Use structured logs in production:

```go
log.Printf("level=info event=server_start port=%s", port)
log.Printf("level=error event=acp_error error=%s", err)
```

### Log Rotation

Use `logrotate` or similar:

```
/var/log/parachute/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

---

## Monitoring

### Metrics to Track

- Request rate
- Error rate
- Response times
- Database size
- WebSocket connections
- ACP subprocess health

### Tools

- Prometheus (metrics)
- Grafana (dashboards)
- Sentry (error tracking)
- Uptimerobot (uptime monitoring)

---

## Backup Strategy

### Database Backups

```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
cp /var/data/parachute.db /var/backups/parachute-$DATE.db

# Keep only last 30 days
find /var/backups/ -name "parachute-*.db" -mtime +30 -delete
```

Run via cron:
```
0 2 * * * /path/to/backup-script.sh
```

---

## Security Considerations

1. **HTTPS:** Use reverse proxy (nginx, Caddy) for HTTPS
2. **Firewall:** Only expose necessary ports
3. **JWT Secret:** Use strong, random secret
4. **API Keys:** Never log API keys
5. **Updates:** Keep dependencies updated

---

## Troubleshooting

### Server Won't Start

Check:
- Port already in use: `lsof -i :8080`
- Database path writable
- Environment variables set
- Node.js/npm installed (for claude-code-acp)

### ACP Integration Fails

Check:
- `npx @zed-industries/claude-code-acp --version` works
- ANTHROPIC_API_KEY is valid
- Subprocess logs in stderr

### High Memory Usage

Check:
- Number of active WebSocket connections
- Database size
- ACP subprocess not cleaned up

---

## Rollback Procedure

If deployment fails:

1. Stop new version
2. Start previous version
3. Restore database from backup if needed
4. Investigate issue
5. Fix and redeploy

---

**Last Updated:** October 20, 2025
**Status:** Deployment strategy defined, finalize before MVP release
