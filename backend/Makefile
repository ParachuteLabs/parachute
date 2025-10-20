.PHONY: run build test clean dev install-tools help

# Default target
help:
	@echo "Parachute Backend - Available Commands:"
	@echo ""
	@echo "  make run          - Run the development server"
	@echo "  make dev          - Run with hot reload (requires air)"
	@echo "  make build        - Build production binary"
	@echo "  make test         - Run all tests"
	@echo "  make test-v       - Run tests with verbose output"
	@echo "  make clean        - Clean build artifacts and data"
	@echo "  make install-tools - Install development tools"
	@echo ""

# Run development server
run:
	go run cmd/server/main.go

# Run with hot reload
dev:
	air

# Build production binary
build:
	mkdir -p bin
	go build -o bin/server cmd/server/main.go
	@echo "✅ Binary built: bin/server"

# Run all tests
test:
	go test ./...

# Run tests with verbose output
test-v:
	go test -v ./...

# Run tests with coverage
test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "✅ Coverage report: coverage.html"

# Clean build artifacts
clean:
	rm -rf bin/
	rm -rf data/
	rm -rf tmp/
	rm -f coverage.out coverage.html
	@echo "✅ Cleaned build artifacts"

# Install development tools
install-tools:
	go install github.com/cosmtrek/air@latest
	@echo "✅ Development tools installed"

# Format code
fmt:
	go fmt ./...

# Run linter
lint:
	go vet ./...

# Download dependencies
deps:
	go mod download
	go mod tidy

# Create necessary directories
setup:
	mkdir -p data/spaces
	@echo "✅ Directories created"
