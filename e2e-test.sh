#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔗 Parachute End-to-End Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

BACKEND_URL="http://localhost:8080"
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
  local name=$1
  local method=$2
  local endpoint=$3
  local data=$4
  local expected_status=$5
  local check_field=$6

  echo -e "${BLUE}Testing: $name${NC}"

  if [ "$method" = "GET" ]; then
    response=$(curl -s -w "\n%{http_code}" "$BACKEND_URL$endpoint")
  else
    response=$(curl -s -w "\n%{http_code}" -X "$method" \
      -H "Content-Type: application/json" \
      -d "$data" \
      "$BACKEND_URL$endpoint")
  fi

  # Split response and status code
  status_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  # Check status code
  if [ "$status_code" != "$expected_status" ]; then
    echo -e "${RED}❌ FAIL: Expected status $expected_status, got $status_code${NC}"
    echo -e "${RED}   Response: $body${NC}"
    ((TESTS_FAILED++))
    return 1
  fi

  # Check response field if provided
  if [ -n "$check_field" ]; then
    if echo "$body" | grep -q "$check_field"; then
      echo -e "${GREEN}✅ PASS${NC}"
      ((TESTS_PASSED++))
    else
      echo -e "${RED}❌ FAIL: Expected field '$check_field' not found in response${NC}"
      echo -e "${RED}   Response: $body${NC}"
      ((TESTS_FAILED++))
      return 1
    fi
  else
    echo -e "${GREEN}✅ PASS${NC}"
    ((TESTS_PASSED++))
  fi

  echo ""
}

# Check if backend is running
echo -e "${BLUE}Checking if backend is running...${NC}"
if ! curl -s "$BACKEND_URL/health" > /dev/null 2>&1; then
  echo -e "${RED}❌ Backend is not running on $BACKEND_URL${NC}"
  echo -e "${YELLOW}Start it with: cd backend && ./bin/server${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Backend is running${NC}"
echo ""

# Test 1: Health Check
test_endpoint "Health Check" "GET" "/health" "" "200" "\"status\":\"ok\""

# Test 2: List Spaces (Empty State)
test_endpoint "List Spaces" "GET" "/api/spaces" "" "200" "\"spaces\":"

# Test 3: Create Space
# First, create the directory
mkdir -p /tmp/e2e-test-space
SPACE_DATA='{"name":"E2E Test Space","path":"/tmp/e2e-test-space"}'
SPACE_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$SPACE_DATA" \
  "$BACKEND_URL/api/spaces")
SPACE_ID=$(echo "$SPACE_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SPACE_ID" ]; then
  echo -e "${RED}❌ FAIL: Could not create space${NC}"
  echo -e "${RED}   Response: $SPACE_RESPONSE${NC}"
  ((TESTS_FAILED++))
else
  echo -e "${BLUE}Testing: Create Space${NC}"
  echo -e "${GREEN}✅ PASS (Space ID: $SPACE_ID)${NC}"
  echo ""
  ((TESTS_PASSED++))
fi

# Test 4: Get Space
test_endpoint "Get Space" "GET" "/api/spaces/$SPACE_ID" "" "200" "\"id\":\"$SPACE_ID\""

# Test 5: List Conversations (Empty for new space)
test_endpoint "List Conversations (Empty)" "GET" "/api/conversations?space_id=$SPACE_ID" "" "200" "\"conversations\":"

# Test 6: List Conversations (Missing space_id parameter)
test_endpoint "List Conversations (No space_id)" "GET" "/api/conversations" "" "400" "\"error\":"

# Test 7: Create Conversation
CONV_DATA="{\"space_id\":\"$SPACE_ID\",\"title\":\"E2E Test Conversation\"}"
CONV_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$CONV_DATA" \
  "$BACKEND_URL/api/conversations")
CONV_ID=$(echo "$CONV_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$CONV_ID" ]; then
  echo -e "${RED}❌ FAIL: Could not create conversation${NC}"
  echo -e "${RED}   Response: $CONV_RESPONSE${NC}"
  ((TESTS_FAILED++))
else
  echo -e "${BLUE}Testing: Create Conversation${NC}"
  echo -e "${GREEN}✅ PASS (Conversation ID: $CONV_ID)${NC}"
  echo ""
  ((TESTS_PASSED++))
fi

# Test 8: List Conversations (Should have 1)
CONV_LIST=$(curl -s "$BACKEND_URL/api/conversations?space_id=$SPACE_ID")
CONV_COUNT=$(echo "$CONV_LIST" | grep -o '"id":"[^"]*"' | wc -l | tr -d ' ')

echo -e "${BLUE}Testing: List Conversations (Has Conversation)${NC}"
if [ "$CONV_COUNT" = "1" ]; then
  echo -e "${GREEN}✅ PASS (Found 1 conversation)${NC}"
  ((TESTS_PASSED++))
else
  echo -e "${RED}❌ FAIL: Expected 1 conversation, found $CONV_COUNT${NC}"
  echo -e "${RED}   Response: $CONV_LIST${NC}"
  ((TESTS_FAILED++))
fi
echo ""

# Test 9: Send Message (User)
MSG_DATA="{\"conversation_id\":\"$CONV_ID\",\"content\":\"Hello, this is a test message\"}"
test_endpoint "Send Message" "POST" "/api/messages" "$MSG_DATA" "201" "\"role\":\"user\""

# Test 10: List Messages
test_endpoint "List Messages" "GET" "/api/messages?conversation_id=$CONV_ID" "" "200" "\"messages\":"

# Test 11: Verify Message Content
MSG_LIST=$(curl -s "$BACKEND_URL/api/messages?conversation_id=$CONV_ID")
echo -e "${BLUE}Testing: Message Content${NC}"
if echo "$MSG_LIST" | grep -q "Hello, this is a test message"; then
  echo -e "${GREEN}✅ PASS (Message content found)${NC}"
  ((TESTS_PASSED++))
else
  echo -e "${RED}❌ FAIL: Message content not found${NC}"
  echo -e "${RED}   Response: $MSG_LIST${NC}"
  ((TESTS_FAILED++))
fi
echo ""

# Test 12: Update Space
UPDATE_DATA='{"name":"E2E Test Space (Updated)"}'
test_endpoint "Update Space" "PUT" "/api/spaces/$SPACE_ID" "$UPDATE_DATA" "200" "\"name\":\"E2E Test Space (Updated)\""

# Test 13: List Spaces (Should have at least 1)
SPACE_LIST=$(curl -s "$BACKEND_URL/api/spaces")
SPACE_COUNT=$(echo "$SPACE_LIST" | grep -o '"id":"[^"]*"' | wc -l | tr -d ' ')

echo -e "${BLUE}Testing: List Spaces (Has Spaces)${NC}"
if [ "$SPACE_COUNT" -ge "1" ]; then
  echo -e "${GREEN}✅ PASS (Found $SPACE_COUNT space(s))${NC}"
  ((TESTS_PASSED++))
else
  echo -e "${RED}❌ FAIL: Expected at least 1 space, found $SPACE_COUNT${NC}"
  echo -e "${RED}   Response: $SPACE_LIST${NC}"
  ((TESTS_FAILED++))
fi
echo ""

# Test 14: Delete Space
test_endpoint "Delete Space" "DELETE" "/api/spaces/$SPACE_ID" "" "204" ""

# Test 15: Verify Space Deleted
DELETED_RESPONSE=$(curl -s -w "%{http_code}" "$BACKEND_URL/api/spaces/$SPACE_ID")
STATUS=$(echo "$DELETED_RESPONSE" | tail -c 4)

echo -e "${BLUE}Testing: Verify Space Deleted${NC}"
if [ "$STATUS" = "404" ]; then
  echo -e "${GREEN}✅ PASS (Space no longer exists)${NC}"
  ((TESTS_PASSED++))
else
  echo -e "${RED}❌ FAIL: Space still exists (status: $STATUS)${NC}"
  ((TESTS_FAILED++))
fi
echo ""

# Test 16: API Response Format (Spaces)
SPACES_FORMAT=$(curl -s "$BACKEND_URL/api/spaces")
echo -e "${BLUE}Testing: API Response Format (Spaces)${NC}"
if echo "$SPACES_FORMAT" | jq -e '.spaces | type == "array"' > /dev/null 2>&1; then
  echo -e "${GREEN}✅ PASS (Correct format: {\"spaces\": [...]})${NC}"
  ((TESTS_PASSED++))
else
  echo -e "${RED}❌ FAIL: Incorrect response format${NC}"
  echo -e "${RED}   Expected: {\"spaces\": [...]}${NC}"
  echo -e "${RED}   Got: $SPACES_FORMAT${NC}"
  ((TESTS_FAILED++))
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 E2E Test Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ All E2E tests passed!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some E2E tests failed${NC}"
  exit 1
fi
