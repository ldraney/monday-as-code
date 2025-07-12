#!/bin/bash
# get-workspace-id.sh - Get your Monday.com workspace IDs

set -e

# Use existing environment variable
if [[ -z "$MONDAY_API_TOKEN" ]]; then
  echo "❌ MONDAY_API_TOKEN environment variable not set!"
  echo "Please run: export MONDAY_API_TOKEN='your_token_here'"
  exit 1
fi

echo "🔍 Fetching your Monday.com workspaces..."
echo ""

# Query to get all workspaces
WORKSPACES_QUERY='{"query": "{ workspaces { id name description } }"}'

RESPONSE=$(curl -s \
  -H "Authorization: $MONDAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$WORKSPACES_QUERY" \
  https://api.monday.com/v2)

# Check for errors
ERRORS=$(echo "$RESPONSE" | jq -r '.errors // empty')
if [[ -n "$ERRORS" ]]; then
  echo "❌ API request failed!"
  echo "Errors: $ERRORS"
  exit 1
fi

# Display workspaces in a nice format
echo "📋 Your Monday.com workspaces:"
echo "================================"

echo "$RESPONSE" | jq -r '.data.workspaces[] | "ID: \(.id)\nName: \(.name)\nDescription: \(.description // "No description")\n---"'

echo ""
echo "💡 To use a workspace ID, run:"
echo "export WORKSPACE_ID='12345678'"
echo ""
echo "🎯 For your lab workspace, look for the one you want to test with!"
