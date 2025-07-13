#!/bin/bash
# discover-monday.sh - Discover and map existing Monday.com infrastructure
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create discovery directories
mkdir -p "$PROJECT_ROOT/discovery"
mkdir -p "$PROJECT_ROOT/state"

# Check for API token
if [[ -z "$MONDAY_API_TOKEN" ]]; then
  echo -e "${RED}❌ MONDAY_API_TOKEN environment variable not set!${NC}"
  echo "Please run: export MONDAY_API_TOKEN='your_token_here'"
  exit 1
fi

show_usage() {
  echo "Monday.com Discovery Tool - Map your existing Monday.com infrastructure"
  echo ""
  echo "Usage: ./scripts/discover-monday.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  scan-all           Discover all workspaces, boards, and connections"
  echo "  scan-workspace     Discover specific workspace"
  echo "  map-connections    Analyze cross-board connections"
  echo "  generate-state     Generate state files for existing infrastructure"
  echo "  export-boards      Export board configurations as JSON"
  echo ""
  echo "Options:"
  echo "  --workspace-id <id>   Target specific workspace"
  echo "  --output-format <fmt> Output format: json, yaml, markdown"
  echo "  --include-data        Include actual board data (items)"
  echo "  --connections-only    Focus only on board connections"
  echo ""
  echo "Examples:"
  echo "  ./scripts/discover-monday.sh scan-all"
  echo "  ./scripts/discover-monday.sh scan-workspace --workspace-id 11619397"
  echo "  ./scripts/discover-monday.sh map-connections"
  echo "  ./scripts/discover-monday.sh export-boards --workspace-id 11619397"
}

# Test API connection
test_api_connection() {
  if [[ -z "$MONDAY_API_TOKEN" ]]; then
    echo -e "${RED}❌ MONDAY_API_TOKEN not set${NC}"
    exit 1
  fi

  local query='{"query": "{ me { id name email } }"}'
  
  local response=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "API-Version: 2023-10" \
    -d "$query" \
    https://api.monday.com/v2)

  local user_name=$(echo "$response" | jq -r '.data.me.name // "null"')
  
  if [[ "$user_name" == "null" ]]; then
    echo -e "${RED}❌ API connection failed${NC}"
    exit 1
  fi
  
  echo "$user_name"
}

# Get all workspaces with detailed info
discover_workspaces() {
  echo -e "${BLUE}🔍 Discovering workspaces...${NC}" >&2
  
  local query='{"query": "{ workspaces { id name description kind } }"}'
  
  local response=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "API-Version: 2023-10" \
    -d "$query" \
    https://api.monday.com/v2)

  # Check for errors
  local errors=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
  if [[ -n "$errors" ]]; then
    echo -e "${RED}❌ API request failed!${NC}" >&2
    echo "Errors: $errors" >&2
    echo "Response: $response" >&2
    exit 1
  fi

  # Check if response is valid JSON
  if ! echo "$response" | jq empty 2>/dev/null; then
    echo -e "${RED}❌ Invalid JSON response!${NC}" >&2
    echo "Response: $response" >&2
    exit 1
  fi

  echo "$response" | jq '.data.workspaces' > "$PROJECT_ROOT/discovery/workspaces.json"
  
  local workspace_count=$(echo "$response" | jq '.data.workspaces | length')
  echo -e "${GREEN}✅ Found $workspace_count workspaces${NC}" >&2
  
  # Return only the JSON response to stdout
  echo "$response"
}

# Get all boards in a workspace with full details
discover_workspace_boards() {
  local workspace_id="$1"
  
  echo -e "${BLUE}🔍 Discovering boards in workspace $workspace_id...${NC}"
  
  local query='{"query": "query($workspace_id: [ID!]) { boards(workspace_ids: $workspace_id, limit: 100) { id name description board_kind state updated_at columns { id title type description settings_str } groups { id title color } views { id name type settings_str } subscribers { id name email } } }", "variables": {"workspace_id": ["'$workspace_id'"]}}'

  local response=$(curl -s \
    -H "Authorization: $MONDAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "API-Version: 2023-10" \
    -d "$query" \
    https://api.monday.com/v2)

  # Check for errors
  local errors=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
  if [[ -n "$errors" ]]; then
    echo -e "${RED}❌ API request failed for workspace $workspace_id!${NC}"
    echo "Errors: $errors"
    return 1
  fi

  # Check if response is valid JSON
  if ! echo "$response" | jq empty 2>/dev/null; then
    echo -e "${RED}❌ Invalid JSON response for workspace $workspace_id!${NC}"
    echo "Response: $response"
    return 1
  fi

  # Save full board data
  echo "$response" | jq '.data.boards' > "$PROJECT_ROOT/discovery/workspace_${workspace_id}_boards.json"
  
  local board_count=$(echo "$response" | jq '.data.boards | length')
  echo -e "${GREEN}✅ Found $board_count boards in workspace $workspace_id${NC}"
  
  echo "$response"
}

# Analyze board connections by looking for connect_boards and mirror columns
analyze_board_connections() {
  echo -e "${BLUE}🔗 Analyzing board connections...${NC}"
  
  local connections_file="$PROJECT_ROOT/discovery/board_connections.json"
  echo '{"connections": [], "analysis": {}}' > "$connections_file"
  
  # Process each workspace's boards
  for workspace_file in "$PROJECT_ROOT/discovery"/workspace_*_boards.json; do
    if [[ -f "$workspace_file" ]]; then
      local workspace_id=$(basename "$workspace_file" | sed 's/workspace_\(.*\)_boards.json/\1/')
      
      echo -e "${BLUE}  Analyzing workspace $workspace_id...${NC}"
      
      # Look for connect_boards and mirror columns
      local connections=$(jq --arg workspace_id "$workspace_id" '
        [
          .[] | 
          {
            board_id: .id,
            board_name: .name,
            workspace_id: $workspace_id,
            connected_columns: [
              .columns[] | 
              select(.type == "board_relation" or .type == "mirror" or (.settings_str | contains("board") or contains("connect"))) |
              {
                column_id: .id,
                column_title: .title,
                column_type: .type,
                settings: .settings_str,
                potential_connection: true
              }
            ]
          } |
          select(.connected_columns | length > 0)
        ]
      ' "$workspace_file")
      
      # Merge into main connections file
      jq --argjson new_connections "$connections" '.connections += $new_connections' "$connections_file" > "$connections_file.tmp"
      mv "$connections_file.tmp" "$connections_file"
    fi
  done
  
  # Generate connection summary
  local total_connections=$(jq '.connections | length' "$connections_file")
  echo -e "${GREEN}✅ Found $total_connections boards with potential connections${NC}"
  
  # Create readable connection report
  jq -r '
    .connections[] | 
    "Board: \(.board_name) (ID: \(.board_id), Workspace: \(.workspace_id))" +
    "\n  Connected Columns:" +
    (.connected_columns[] | "\n    - \(.column_title) (\(.column_type))") +
    "\n"
  ' "$connections_file" > "$PROJECT_ROOT/discovery/connections_report.txt"
  
  echo -e "${BLUE}📄 Connection report saved to discovery/connections_report.txt${NC}"
}

# Generate current state files for existing infrastructure
generate_state_files() {
  echo -e "${BLUE}📊 Generating state files...${NC}"
  
  local state_dir="$PROJECT_ROOT/state"
  mkdir -p "$state_dir"
  
  # Create master state file
  local master_state="{\"discovered_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"workspaces\": {}, \"boards\": {}, \"connections\": []}"
  echo "$master_state" > "$state_dir/current_state.json"
  
  # Process each workspace
  for workspace_file in "$PROJECT_ROOT/discovery"/workspace_*_boards.json; do
    if [[ -f "$workspace_file" ]]; then
      local workspace_id=$(basename "$workspace_file" | sed 's/workspace_\(.*\)_boards.json/\1/')
      
      echo -e "${BLUE}  Processing workspace $workspace_id...${NC}"
      
      # Extract board state information
      local board_state=$(jq --arg workspace_id "$workspace_id" '
        [
          .[] | 
          {
            resource_name: (.name | gsub("[^a-zA-Z0-9-]"; "-") | ascii_downcase),
            board_id: .id,
            board_name: .name,
            workspace_id: $workspace_id,
            description: .description,
            board_kind: .board_kind,
            state: .state,
            created_at: .created_at,
            updated_at: .updated_at,
            column_count: (.columns | length),
            columns: [
              .columns[] | 
              {
                column_id: .id,
                title: .title,
                type: .type,
                description: .description
              }
            ]
          }
        ]
      ' "$workspace_file")
      
      # Add to master state
      jq --arg workspace_id "$workspace_id" --argjson boards "$board_state" '
        .workspaces[$workspace_id] = {
          workspace_id: $workspace_id,
          board_count: ($boards | length),
          boards: $boards
        } |
        .boards += ($boards | map({(.resource_name): .}) | add // {})
      ' "$state_dir/current_state.json" > "$state_dir/current_state.json.tmp"
      mv "$state_dir/current_state.json.tmp" "$state_dir/current_state.json"
    fi
  done
  
  echo -e "${GREEN}✅ State files generated in state/current_state.json${NC}"
}

# Export existing boards as deployable JSON configs
export_boards_as_configs() {
  local workspace_id="$1"
  
  echo -e "${BLUE}📤 Exporting boards as deployable configs...${NC}"
  
  local export_dir="$PROJECT_ROOT/exported_configs"
  mkdir -p "$export_dir/boards"
  
  if [[ -n "$workspace_id" ]]; then
    local workspace_file="$PROJECT_ROOT/discovery/workspace_${workspace_id}_boards.json"
    if [[ ! -f "$workspace_file" ]]; then
      echo -e "${RED}❌ No discovery data for workspace $workspace_id. Run scan-workspace first.${NC}"
      exit 1
    fi
    
    # Convert discovered boards to deployable configs
    jq -r '.[] | 
      {
        resource_type: "board",
        name: (.name | gsub("[^a-zA-Z0-9-]"; "-") | ascii_downcase),
        spec: {
          board_name: .name,
          board_kind: .board_kind,
          description: .description,
          workspace_id: "${WORKSPACE_ID}",
          columns: [
            .columns[] | 
            {
              title: .title,
              type: .type,
              description: .description
            }
          ]
        }
      }
    ' "$workspace_file" | jq -s '.[]' | while IFS= read -r board_config; do
      local board_name=$(echo "$board_config" | jq -r '.name')
      echo "$board_config" | jq '.' > "$export_dir/boards/${board_name}.json"
      echo -e "${GREEN}✅ Exported $board_name.json${NC}"
    done
  else
    echo -e "${YELLOW}⚠️  No workspace specified. Use --workspace-id to export specific workspace${NC}"
  fi
}

# Generate visual connection map
generate_connection_map() {
  echo -e "${BLUE}🗺️  Generating connection map...${NC}"
  
  if [[ ! -f "$PROJECT_ROOT/discovery/board_connections.json" ]]; then
    echo -e "${YELLOW}⚠️  No connection data found. Run map-connections first.${NC}"
    return
  fi
  
  # Create a simple text-based connection map
  cat > "$PROJECT_ROOT/discovery/connection_map.txt" << 'EOF'
# Monday.com Board Connection Map
# Generated by Monday as Code Discovery

## Cross-Board Connections Detected

EOF
  
  jq -r '
    .connections[] | 
    "### \(.board_name) (Workspace: \(.workspace_id))" +
    (.connected_columns[] | "\n- **\(.column_title)** (\(.column_type)) - Potential connection to other board") +
    "\n"
  ' "$PROJECT_ROOT/discovery/board_connections.json" >> "$PROJECT_ROOT/discovery/connection_map.txt"
  
  echo -e "${GREEN}✅ Connection map saved to discovery/connection_map.txt${NC}"
}

# Main command dispatcher
main() {
  # Handle case where no arguments provided
  if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
  fi

  local command=""
  local workspace_id=""
  local output_format="json"
  local include_data=false
  local connections_only=false

  # Parse command and options
  while [[ $# -gt 0 ]]; do
    case $1 in
      scan-all|scan-workspace|map-connections|generate-state|export-boards)
        command="$1"
        shift
        ;;
      --scan-all)
        command="scan-all"
        shift
        ;;
      --workspace-id)
        workspace_id="$2"
        shift 2
        ;;
      --output-format)
        output_format="$2"
        shift 2
        ;;
      --include-data)
        include_data=true
        shift
        ;;
      --connections-only)
        connections_only=true
        shift
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        echo -e "${RED}❌ Unknown option: $1${NC}"
        show_usage
        exit 1
        ;;
    esac
  done

  # If no command specified but --scan-all used, set command
  if [[ -z "$command" ]]; then
    echo -e "${RED}❌ No command specified${NC}"
    show_usage
    exit 1
  fi

  # Test API connection
  local user_name=$(test_api_connection)
  echo -e "${GREEN}✅ Connected as: $user_name${NC}"
  echo ""

  case "$command" in
    scan-all)
      echo -e "${BOLD}🔍 Scanning all Monday.com infrastructure...${NC}"
      echo ""
      
      # Discover workspaces
      echo -e "${BLUE}Step 1: Discovering workspaces...${NC}"
      local workspaces_response=$(discover_workspaces)
      
      # Debug: Check if workspaces were discovered properly
      local workspace_count=$(echo "$workspaces_response" | jq '.data.workspaces | length' 2>/dev/null || echo "0")
      echo -e "${BLUE}Found $workspace_count workspaces to scan${NC}"
      
      # Discover boards in each workspace
      if [[ "$workspace_count" -gt 0 ]]; then
        echo -e "${BLUE}Step 2: Discovering boards in each workspace...${NC}"
        echo "$workspaces_response" | jq -r '.data.workspaces[].id' | while read -r ws_id; do
          echo -e "${BLUE}Processing workspace: $ws_id${NC}"
          discover_workspace_boards "$ws_id"
        done
      else
        echo -e "${YELLOW}⚠️  No workspaces found to scan${NC}"
        echo "Workspaces response: $workspaces_response"
      fi
      
      # Analyze connections
      echo -e "${BLUE}Step 3: Analyzing connections...${NC}"
      analyze_board_connections
      
      # Generate state files
      echo -e "${BLUE}Step 4: Generating state files...${NC}"
      generate_state_files
      
      # Generate connection map
      echo -e "${BLUE}Step 5: Generating connection map...${NC}"
      generate_connection_map
      
      echo ""
      echo -e "${BOLD}🎉 Discovery complete!${NC}"
      echo "Results saved in:"
      echo "  - discovery/workspaces.json"
      echo "  - discovery/workspace_*_boards.json"
      echo "  - discovery/board_connections.json"
      echo "  - discovery/connections_report.txt"
      echo "  - discovery/connection_map.txt"
      echo "  - state/current_state.json"
      ;;
      
    scan-workspace)
      if [[ -z "$workspace_id" ]]; then
        echo -e "${RED}❌ --workspace-id required for scan-workspace${NC}"
        exit 1
      fi
      
      discover_workspace_boards "$workspace_id"
      ;;
      
    map-connections)
      analyze_board_connections
      generate_connection_map
      ;;
      
    generate-state)
      generate_state_files
      ;;
      
    export-boards)
      export_boards_as_configs "$workspace_id"
      ;;
      
    *)
      echo -e "${RED}❌ Unknown command: $command${NC}"
      show_usage
      exit 1
      ;;
  esac
}

main "$@"
