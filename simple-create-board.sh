#!/bin/bash
# simple-create-board.sh - Dead simple board creation test

set -e

# Configuration - Uses your existing environment variables
MONDAY_API_TOKEN=$MONDAY_API_TOKEN  # Uses your existing env var
WORKSPACE_ID=$WORKSPACE_ID          # Uses your existing env var
BOARD_NAME="Test Board from Code"

# Colors for pretty output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check required environment variables
if [[ -z "$MONDAY_API_TOKEN" ]]; then
  echo -e "${RED}❌ MONDAY_API_TOKEN environment variable not set!${NC}"
  echo "Please run: export MONDAY_API_TOKEN='your_token_here'"
  exit 1
fi

if [[ -z "$WORKSPACE_ID" ]]; then
  echo -e "${RED}❌ WORKSPACE_ID environment variable not set!${NC}"
  echo "Please run: export WORKSPACE_ID='your_workspace_id'"
  echo "Use ./get-workspace-id.sh to find your workspace ID"
  exit 1
fi

echo -e "${BLUE}🚀 Creating Monday.com board via API...${NC}"
echo "Board Name: $BOARD_NAME"
echo "Workspace ID: $WORKSPACE_ID"
echo ""

# Step 1: Test API connection
echo -e "${BLUE}Step 1: Testing API connection...${NC}"

TEST_QUERY='{"query": "{ me { id name email } }"}'

TEST_RESPONSE=$(curl -s \
  -H "Authorization: $MONDAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$TEST_QUERY" \
  https://api.monday.com/v2)

# Check if we got a user back
USER_NAME=$(echo "$TEST_RESPONSE" | jq -r '.data.me.name // "null"')

if [[ "$USER_NAME" == "null" ]]; then
  echo -e "${RED}❌ API connection failed!${NC}"
  echo "Response: $TEST_RESPONSE"
  exit 1
else
  echo -e "${GREEN}✅ Connected as: $USER_NAME${NC}"
fi

echo ""

# Step 2: Check if board already exists
echo -e "${BLUE}Step 2: Checking if board already exists...${NC}"

LIST_BOARDS_QUERY=$(cat << EOF
{
  "query": "query(\$workspace_id: [Int!]) { boards(workspace_ids: \$workspace_id, limit: 50) { id name } }",
  "variables": {"workspace_id": [$WORKSPACE_ID]}
}
EOF
)

BOARDS_RESPONSE=$(curl -s \
  -H "Authorization: $MONDAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$LIST_BOARDS_QUERY" \
  https://api.monday.com/v2)

# Check if board with this name already exists
EXISTING_BOARD_ID=$(echo "$BOARDS_RESPONSE" | jq -r --arg name "$BOARD_NAME" '.data.boards[]? | select(.name == $name) | .id')

if [[ -n "$EXISTING_BOARD_ID" && "$EXISTING_BOARD_ID" != "null" ]]; then
  echo -e "${GREEN}✅ Board already exists with ID: $EXISTING_BOARD_ID${NC}"
  echo "Skipping creation (this is good - idempotent behavior!)"
  exit 0
else
  echo -e "${BLUE}📋 Board doesn't exist yet, will create it${NC}"
fi

echo ""

# Step 3: Create the board
echo -e "${BLUE}Step 3: Creating the board...${NC}"

CREATE_BOARD_QUERY=$(cat << EOF
{
  "query": "mutation(\$board_name: String!, \$workspace_id: Int!) { create_board(board_name: \$board_name, board_kind: public, workspace_id: \$workspace_id) { id name } }",
  "variables": {
    "board_name": "$BOARD_NAME",
    "workspace_id": $WORKSPACE_ID
  }
}
EOF
)

CREATE_RESPONSE=$(curl -s \
  -H "Authorization: $MONDAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$CREATE_BOARD_QUERY" \
  https://api.monday.com/v2)

# Check for errors
ERRORS=$(echo "$CREATE_RESPONSE" | jq -r '.errors // empty')
if [[ -n "$ERRORS" ]]; then
  echo -e "${RED}❌ Board creation failed!${NC}"
  echo "Errors: $ERRORS"
  echo "Full response: $CREATE_RESPONSE"
  exit 1
fi

# Get the new board ID
NEW_BOARD_ID=$(echo "$CREATE_RESPONSE" | jq -r '.data.create_board.id')

if [[ -n "$NEW_BOARD_ID" && "$NEW_BOARD_ID" != "null" ]]; then
  echo -e "${GREEN}🎉 Board created successfully!${NC}"
  echo "Board ID: $NEW_BOARD_ID"
  echo "Board Name: $BOARD_NAME"
  echo ""
  echo "You can view it at: https://your-org.monday.com/boards/$NEW_BOARD_ID"
else
  echo -e "${RED}❌ Something went wrong - no board ID returned${NC}"
  echo "Full response: $CREATE_RESPONSE"
  exit 1
fi

echo ""
echo -e "${GREEN}✅ Success! Your first Monday.com board created via code!${NC}"
