#!/bin/bash
# monday-api.sh - Monday.com API helper functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# API Configuration
MONDAY_API_URL="https://api.monday.com/v2"
MONDAY_API_VERSION="2023-10"

# Test API connection and return user info
test_api_connection() {
  if [[ -z "$MONDAY_API_TOKEN" ]]; then
    echo -e "${RED}❌ MONDAY_API_TOKEN not set${NC}"
    return 1
  fi

  local query='{"query": "{ me { id name email } }"}'
  
  local response=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "API-Version: $MONDAY_API_VERSION" \
    -d "$query" \
    "$MONDAY_API_URL")

  local user_name=$(echo "$response" | jq -r '.data.me.name // "null"')
  
  if [[ "$user_name" == "null" ]]; then
    echo -e "${RED}❌ API connection failed${NC}"
    echo "Response: $response"
    return 1
  fi
  
  echo "$user_name"
  return 0
}

# Get all boards in a workspace
get_workspace_boards() {
  local workspace_id="$1"
  
  local query=$(cat << END
{
  "query": "query(\$workspace_id: [ID!]) { boards(workspace_ids: \$workspace_id, limit: 100) { id name description } }",
  "variables": {"workspace_id": ["$workspace_id"]}
}
END
)

  local response=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "API-Version: $MONDAY_API_VERSION" \
    -d "$query" \
    "$MONDAY_API_URL")

  echo "$response"
}

# Check if board exists by name
board_exists() {
  local workspace_id="$1"
  local board_name="$2"
  
  local boards_response=$(get_workspace_boards "$workspace_id")
  local board_id=$(echo "$boards_response" | jq -r --arg name "$board_name" '.data.boards[]? | select(.name == $name) | .id')
  
  if [[ -n "$board_id" && "$board_id" != "null" ]]; then
    echo "$board_id"
    return 0
  else
    return 1
  fi
}

# Create a new board
create_board() {
  local board_name="$1"
  local workspace_id="$2"
  local board_kind="${3:-public}"
  local description="$4"
  
  local query=$(cat << END
{
  "query": "mutation(\$board_name: String!, \$workspace_id: ID!, \$board_kind: BoardKind!, \$description: String) { create_board(board_name: \$board_name, workspace_id: \$workspace_id, board_kind: \$board_kind, description: \$description) { id name } }",
  "variables": {
    "board_name": "$board_name",
    "workspace_id": "$workspace_id",
    "board_kind": "$board_kind",
    "description": "$description"
  }
}
END
)

  local response=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "API-Version: $MONDAY_API_VERSION" \
    -d "$query" \
    "$MONDAY_API_URL")

  local errors=$(echo "$response" | jq -r '.errors // empty')
  if [[ -n "$errors" ]]; then
    echo -e "${RED}❌ Board creation failed: $errors${NC}"
    return 1
  fi

  local board_id=$(echo "$response" | jq -r '.data.create_board.id')
  echo "$board_id"
}

# Get existing columns for a board
get_board_columns() {
  local board_id="$1"
  
  local query=$(cat << END
{
  "query": "query(\$board_id: [ID!]) { boards(ids: \$board_id) { columns { id title type settings_str } } }",
  "variables": {"board_id": ["$board_id"]}
}
END
)

  local response=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "API-Version: $MONDAY_API_VERSION" \
    -d "$query" \
    "$MONDAY_API_URL")

  echo "$response"
}

# Check if column exists on board
column_exists() {
  local board_id="$1"
  local column_title="$2"
  
  local columns_response=$(get_board_columns "$board_id")
  local existing_columns=$(echo "$columns_response" | jq -r '.data.boards[0].columns[]?.title' 2>/dev/null || echo "")
  
  echo "$existing_columns" | grep -q "^$column_title$"
}

# Create a column on a board
create_column() {
  local board_id="$1"
  local column_title="$2"
  local column_type="$3"
  local column_settings="$4"
  
  local query=$(cat << END
{
  "query": "mutation(\$board_id: ID!, \$title: String!, \$type: ColumnType!) { create_column(board_id: \$board_id, title: \$title, column_type: \$type) { id title type } }",
  "variables": {
    "board_id": "$board_id",
    "title": "$column_title",
    "type": "$column_type"
  }
}
END
)

  local response=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "API-Version: $MONDAY_API_VERSION" \
    -d "$query" \
    "$MONDAY_API_URL")

  local errors=$(echo "$response" | jq -r '.errors // empty')
  if [[ -n "$errors" ]]; then
    echo -e "${RED}❌ Column creation failed: $errors${NC}"
    return 1
  fi

  local column_id=$(echo "$response" | jq -r '.data.create_column.id')
  echo "$column_id"
}

# Log deployment action
log_action() {
  local action="$1"
  local resource="$2"
  local status="$3"
  local details="$4"
  
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local log_entry="[$timestamp] $action $resource - $status"
  
  if [[ -n "$details" ]]; then
    log_entry="$log_entry - $details"
  fi
  
  echo "$log_entry" >> "logs/deploy-$(date '+%Y%m%d').log"
  
  # Also output to console with colors
  case "$status" in
    "SUCCESS")
      echo -e "${GREEN}✅ $action $resource${NC}"
      ;;
    "SKIPPED")
      echo -e "${YELLOW}⏭️  $action $resource - $details${NC}"
      ;;
    "FAILED")
      echo -e "${RED}❌ $action $resource - $details${NC}"
      ;;
    *)
      echo -e "${BLUE}ℹ️  $action $resource - $status${NC}"
      ;;
  esac
}
