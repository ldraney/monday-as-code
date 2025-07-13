#!/bin/bash
# setup-tasks-board.sh - Create the 'Tasks' board in Monday.com and provision it with expected form-compatible columns
# Author: Lucas Draney via ChatGPT
# Context: Monday as Code (Phase 2B - Infrastructure Lifecycle Management)
# Updated: 2025-07-12

set -e

# CONFIG
MONDAY_API_TOKEN=${MONDAY_API_TOKEN:?Missing MONDAY_API_TOKEN}
BOARD_NAME="Tasks"

# Style
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Fetch all boards and check if 'Tasks' exists
echo -e "${BLUE}🔍 Searching for board named '$BOARD_NAME'...${NC}"
GET_ALL_BOARDS_QUERY='{"query":"query { boards(limit: 100) { id name } }"}'
RESPONSE=$(curl -s -H "Authorization: $MONDAY_API_TOKEN" -H "Content-Type: application/json" \
  -d "$GET_ALL_BOARDS_QUERY" https://api.monday.com/v2)

BOARD_ID=$(echo "$RESPONSE" | jq -r --arg name "$BOARD_NAME" '.data.boards[]? | select(.name == $name) | .id')

if [[ -n "$BOARD_ID" ]]; then
  echo -e "${YELLOW}⚠️ Board '$BOARD_NAME' already exists (ID: $BOARD_ID).${NC}"
else
  echo -e "${BLUE}📋 Creating '$BOARD_NAME' board...${NC}"
  CREATE_QUERY=$(cat <<EOF
{
  "query": "mutation { create_board(board_name: \"$BOARD_NAME\", board_kind: public) { id } }"
}
EOF
)
  BOARD_ID=$(curl -s -H "Authorization: $MONDAY_API_TOKEN" -H "Content-Type: application/json" \
    -d "$CREATE_QUERY" https://api.monday.com/v2 | jq -r '.data.create_board.id')
  echo -e "${GREEN}✅ Created board '$BOARD_NAME' (ID: $BOARD_ID)${NC}"
fi

# 2. Ensure required columns
COLUMNS=(
  "Description long_text"
  "Requester people"
  "Priority status"
  "Due Date date"
  "Area dropdown"
  "Files file"
  "Needs Ticket checkbox"
  "Related Ticket board_relation"
)

GET_COLS_QUERY=$(cat <<EOF
{
  "query": "query { boards(ids: [$BOARD_ID]) { columns { title } } }"
}
EOF
)
EXISTING_COLS=$(curl -s -H "Authorization: $MONDAY_API_TOKEN" -H "Content-Type: application/json" \
  -d "$GET_COLS_QUERY" https://api.monday.com/v2 | jq -r '.data.boards[0].columns[].title')

for COL_DEF in "${COLUMNS[@]}"; do
  TITLE=$(echo $COL_DEF | cut -d' ' -f1)
  TYPE=$(echo $COL_DEF | cut -d' ' -f2)

  if echo "$EXISTING_COLS" | grep -q "^$TITLE$"; then
    echo -e "${YELLOW}⏭️ Column '$TITLE' already exists${NC}"
  else
    echo -e "${BLUE}➕ Adding column '$TITLE' ($TYPE)...${NC}"
    ADD_COL_QUERY=$(cat <<EOF
{
  "query": "mutation { create_column(board_id: \"$BOARD_ID\", title: \"$TITLE\", column_type: $TYPE) { id } }"
}
EOF
)
    curl -s -H "Authorization: $MONDAY_API_TOKEN" -H "Content-Type: application/json" -d "$ADD_COL_QUERY" https://api.monday.com/v2 > /dev/null
    echo -e "${GREEN}✅ Added column '$TITLE'${NC}"
  fi
done

# 3. Save board schema
mkdir -p state/current
GET_STATE_QUERY=$(cat <<EOF
{
  "query": "query { boards(ids: [$BOARD_ID]) { id name columns { id title type } } }"
}
EOF
)
curl -s -H "Authorization: $MONDAY_API_TOKEN" -H "Content-Type: application/json" \
  -d "$GET_STATE_QUERY" https://api.monday.com/v2 | jq . > "state/current/lab_tasks_board.json"

echo -e "\n${GREEN}🎯 Tasks board setup complete and state saved.${NC}"

