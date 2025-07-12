#!/bin/bash
# simple-create-board.sh - Board creation with columns (ENHANCED)

set -e

# Configuration - Uses your existing environment variables
MONDAY_API_TOKEN=$MONDAY_API_TOKEN  # Uses your existing env var
WORKSPACE_ID=$WORKSPACE_ID          # Uses your existing env var
BOARD_NAME="Test Board from Code"

# Colors for pretty output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

echo -e "${BLUE}🚀 Creating Monday.com board with columns via API...${NC}"
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

LIST_BOARDS_QUERY=$(cat << END
{
  "query": "query(\$workspace_id: [ID!]) { boards(workspace_ids: \$workspace_id, limit: 50) { id name } }",
  "variables": {"workspace_id": ["$WORKSPACE_ID"]}
}
END
)

BOARDS_RESPONSE=$(curl -s \
  -H "Authorization: $MONDAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$LIST_BOARDS_QUERY" \
  https://api.monday.com/v2)

# Check if board with this name already exists
EXISTING_BOARD_ID=$(echo "$BOARDS_RESPONSE" | jq -r --arg name "$BOARD_NAME" '.data.boards[]? | select(.name == $name) | .id')

BOARD_ID=""
BOARD_CREATED=false

if [[ -n "$EXISTING_BOARD_ID" && "$EXISTING_BOARD_ID" != "null" ]]; then
  echo -e "${GREEN}✅ Board already exists with ID: $EXISTING_BOARD_ID${NC}"
  BOARD_ID="$EXISTING_BOARD_ID"
  echo "Will check and add missing columns..."
else
  echo -e "${BLUE}📋 Board doesn't exist yet, will create it${NC}"
  
  # Step 3: Create the board
  echo -e "${BLUE}Step 3: Creating the board...${NC}"

  CREATE_BOARD_QUERY=$(cat << END
{
  "query": "mutation(\$board_name: String!, \$workspace_id: ID!) { create_board(board_name: \$board_name, board_kind: public, workspace_id: \$workspace_id) { id name } }",
  "variables": {
    "board_name": "$BOARD_NAME",
    "workspace_id": "$WORKSPACE_ID"
  }
}
END
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
  BOARD_ID=$(echo "$CREATE_RESPONSE" | jq -r '.data.create_board.id')

  if [[ -n "$BOARD_ID" && "$BOARD_ID" != "null" ]]; then
    echo -e "${GREEN}🎉 Board created successfully!${NC}"
    echo "Board ID: $BOARD_ID"
    BOARD_CREATED=true
  else
    echo -e "${RED}❌ Something went wrong - no board ID returned${NC}"
    echo "Full response: $CREATE_RESPONSE"
    exit 1
  fi
fi

echo ""

# Step 4: Get existing columns to avoid duplicates
echo -e "${BLUE}Step 4: Checking existing columns...${NC}"

GET_COLUMNS_QUERY=$(cat << END
{
  "query": "query(\$board_id: [ID!]) { boards(ids: \$board_id) { columns { id title type settings_str } } }",
  "variables": {"board_id": ["$BOARD_ID"]}
}
END
)

COLUMNS_RESPONSE=$(curl -s \
  -H "Authorization: $MONDAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$GET_COLUMNS_QUERY" \
  https://api.monday.com/v2)

# Get existing column titles
EXISTING_COLUMNS=$(echo "$COLUMNS_RESPONSE" | jq -r '.data.boards[0].columns[]?.title' 2>/dev/null || echo "")

echo "Existing columns: $(echo "$EXISTING_COLUMNS" | tr '\n' ', ' | sed 's/,$//')"

# Function to check if column exists
column_exists() {
  local column_title="$1"
  echo "$EXISTING_COLUMNS" | grep -q "^$column_title$"
}

# Function to create a column (simplified approach)
create_column() {
  local column_title="$1"
  local column_type="$2"
  
  if column_exists "$column_title"; then
    echo -e "${YELLOW}⏭️  Column '$column_title' already exists, skipping${NC}"
    return 0
  fi
  
  echo -e "${BLUE}➕ Creating '$column_title' column (type: $column_type)...${NC}"
  
  # Simple column creation without complex settings (we'll add settings later if needed)
  CREATE_COLUMN_QUERY=$(cat << END
{
  "query": "mutation(\$board_id: ID!, \$title: String!, \$type: ColumnType!) { create_column(board_id: \$board_id, title: \$title, column_type: \$type) { id title type } }",
  "variables": {
    "board_id": "$BOARD_ID",
    "title": "$column_title",
    "type": "$column_type"
  }
}
END
)
  
  COLUMN_RESPONSE=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CREATE_COLUMN_QUERY" \
    https://api.monday.com/v2)
  
  # Check for errors
  COLUMN_ERRORS=$(echo "$COLUMN_RESPONSE" | jq -r '.errors // empty')
  if [[ -n "$COLUMN_ERRORS" ]]; then
    echo -e "${RED}❌ Failed to create '$column_title' column!${NC}"
    echo "Errors: $COLUMN_ERRORS"
    echo "Response: $COLUMN_RESPONSE"
    return 1
  fi
  
  COLUMN_ID=$(echo "$COLUMN_RESPONSE" | jq -r '.data.create_column.id')
  if [[ -n "$COLUMN_ID" && "$COLUMN_ID" != "null" ]]; then
    echo -e "${GREEN}✅ Created '$column_title' column (ID: $COLUMN_ID)${NC}"
  else
    echo -e "${RED}❌ Column creation failed - no ID returned${NC}"
    echo "Response: $COLUMN_RESPONSE"
    return 1
  fi
}

echo ""
echo -e "${BLUE}Step 5: Creating columns...${NC}"

# Create basic columns without complex settings first
# We can always add settings later once the columns exist

create_column "Status" "status"
create_column "Priority" "priority"  
create_column "Due Date" "date"
create_column "Assignee" "people"
create_column "Progress" "numbers"
create_column "Tags" "tags"
create_column "Notes" "text"

echo ""
echo -e "${GREEN}🎉 Success! Board with columns created/updated!${NC}"
echo ""
echo "📋 Board Details:"
echo "   Name: $BOARD_NAME"
echo "   ID: $BOARD_ID"
echo "   Workspace: $WORKSPACE_ID"
echo ""
echo "📊 Columns created:"
echo "   • Status (default settings)"
echo "   • Priority (default settings)"
echo "   • Due Date"
echo "   • Assignee (people picker)"
echo "   • Progress (numbers)"
echo "   • Tags"
echo "   • Notes (text)"
echo ""
echo "🔗 Check it out in your Lab workspace at Monday.com!"
echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "   - Run this script again - it's idempotent!"
echo "   - Customize Status/Priority labels in Monday.com UI"
echo "   - Column settings can be configured manually after creation"
