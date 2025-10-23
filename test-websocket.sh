#!/bin/bash

# WebSocket Integration Test Runner
# Tests the Flutter-Go WebSocket bridge

set -e

echo "🧪 Parachute WebSocket Integration Tests"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if backend is built
if [ ! -f "backend/bin/server" ]; then
    echo -e "${YELLOW}⚠️  Backend not built. Building now...${NC}"
    cd backend && make build && cd ..
fi

# Run WebSocket integration tests
echo -e "${YELLOW}📡 Running WebSocket Integration Tests...${NC}"
echo ""

cd backend/tests/integration

# Run tests with verbose output
go test -v -race -timeout 30s ./... 2>&1 | while read line; do
    if [[ $line == *"PASS"* ]]; then
        echo -e "${GREEN}✓${NC} $line"
    elif [[ $line == *"FAIL"* ]]; then
        echo -e "${RED}✗${NC} $line"
    elif [[ $line == *"RUN"* ]]; then
        echo -e "${YELLOW}▶${NC} $line"
    else
        echo "$line"
    fi
done

# Check exit code
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All WebSocket tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some WebSocket tests failed${NC}"
    exit 1
fi
