#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 Parachute Test Suite${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Parse command line arguments
BACKEND_ONLY=false
FLUTTER_ONLY=false
SKIP_INTEGRATION=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --backend-only)
      BACKEND_ONLY=true
      shift
      ;;
    --flutter-only)
      FLUTTER_ONLY=true
      shift
      ;;
    --skip-integration)
      SKIP_INTEGRATION=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--backend-only] [--flutter-only] [--skip-integration] [-v|--verbose]"
      exit 1
      ;;
  esac
done

TESTS_PASSED=0
TESTS_FAILED=0

# Function to run backend tests
run_backend_tests() {
  echo -e "${YELLOW}📦 Running Backend Tests...${NC}"
  echo ""

  cd backend

  # Run unit tests
  echo -e "${BLUE}Running Go unit tests...${NC}"
  if [ "$VERBOSE" = true ]; then
    if go test -v ./...; then
      echo -e "${GREEN}✅ Backend unit tests passed${NC}"
      ((TESTS_PASSED++))
    else
      echo -e "${RED}❌ Backend unit tests failed${NC}"
      ((TESTS_FAILED++))
    fi
  else
    if go test ./... 2>&1 | grep -v "no test files"; then
      echo -e "${GREEN}✅ Backend unit tests passed${NC}"
      ((TESTS_PASSED++))
    else
      echo -e "${RED}❌ Backend unit tests failed${NC}"
      ((TESTS_FAILED++))
    fi
  fi

  echo ""

  # Run integration tests if not skipped
  if [ "$SKIP_INTEGRATION" = false ]; then
    echo -e "${BLUE}Running API integration tests...${NC}"
    if [ "$VERBOSE" = true ]; then
      if go test -v ./internal/api/handlers/...; then
        echo -e "${GREEN}✅ API integration tests passed${NC}"
        ((TESTS_PASSED++))
      else
        echo -e "${RED}❌ API integration tests failed${NC}"
        ((TESTS_FAILED++))
      fi
    else
      if go test ./internal/api/handlers/...; then
        echo -e "${GREEN}✅ API integration tests passed${NC}"
        ((TESTS_PASSED++))
      else
        echo -e "${RED}❌ API integration tests failed${NC}"
        ((TESTS_FAILED++))
      fi
    fi
  fi

  cd ..
  echo ""
}

# Function to run Flutter tests
run_flutter_tests() {
  echo -e "${YELLOW}📱 Running Flutter Tests...${NC}"
  echo ""

  cd app

  # Install dependencies first
  echo -e "${BLUE}Installing Flutter dependencies...${NC}"
  if flutter pub get > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Dependencies installed${NC}"
  else
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    ((TESTS_FAILED++))
    cd ..
    return
  fi

  echo ""

  # Run Flutter tests
  echo -e "${BLUE}Running Flutter tests...${NC}"
  if [ "$VERBOSE" = true ]; then
    if flutter test; then
      echo -e "${GREEN}✅ Flutter tests passed${NC}"
      ((TESTS_PASSED++))
    else
      echo -e "${RED}❌ Flutter tests failed${NC}"
      ((TESTS_FAILED++))
    fi
  else
    if flutter test --machine 2>&1 | grep -q "\"success\":true"; then
      echo -e "${GREEN}✅ Flutter tests passed${NC}"
      ((TESTS_PASSED++))
    else
      # Fall back to normal test output
      if flutter test > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Flutter tests passed${NC}"
        ((TESTS_PASSED++))
      else
        echo -e "${RED}❌ Flutter tests failed${NC}"
        ((TESTS_FAILED++))
      fi
    fi
  fi

  cd ..
  echo ""
}

# Function to check if backend server is running
check_backend_server() {
  echo -e "${BLUE}Checking backend server...${NC}"
  if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend server is running${NC}"
    return 0
  else
    echo -e "${YELLOW}⚠️  Backend server is not running${NC}"
    echo -e "${YELLOW}   Start it with: cd backend && ./bin/server${NC}"
    return 1
  fi
  echo ""
}

# Function to run end-to-end tests (if backend is running)
run_e2e_tests() {
  if [ "$SKIP_INTEGRATION" = true ]; then
    return
  fi

  echo -e "${YELLOW}🔗 Checking E2E Prerequisites...${NC}"
  echo ""

  if check_backend_server; then
    echo -e "${BLUE}Running end-to-end health check...${NC}"
    HEALTH_RESPONSE=$(curl -s http://localhost:8080/health)
    if echo "$HEALTH_RESPONSE" | grep -q "\"status\":\"ok\""; then
      echo -e "${GREEN}✅ Backend health check passed${NC}"
      ((TESTS_PASSED++))

      # Test spaces endpoint
      echo -e "${BLUE}Testing /api/spaces endpoint...${NC}"
      SPACES_RESPONSE=$(curl -s http://localhost:8080/api/spaces)
      if echo "$SPACES_RESPONSE" | grep -q "\"spaces\""; then
        echo -e "${GREEN}✅ Spaces API format is correct${NC}"
        ((TESTS_PASSED++))
      else
        echo -e "${RED}❌ Spaces API format is incorrect${NC}"
        echo -e "${RED}   Expected: {\"spaces\": [...]}${NC}"
        echo -e "${RED}   Got: $SPACES_RESPONSE${NC}"
        ((TESTS_FAILED++))
      fi
    else
      echo -e "${RED}❌ Backend health check failed${NC}"
      ((TESTS_FAILED++))
    fi
  else
    echo -e "${YELLOW}⚠️  Skipping E2E tests (backend not running)${NC}"
  fi
  echo ""
}

# Main test execution
if [ "$FLUTTER_ONLY" = true ]; then
  run_flutter_tests
elif [ "$BACKEND_ONLY" = true ]; then
  run_backend_tests
else
  run_backend_tests
  run_flutter_tests
  run_e2e_tests
fi

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Test Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some tests failed${NC}"
  exit 1
fi
