#!/bin/bash
# deploy.sh - Monday as Code deployment script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load API library
source "$SCRIPT_DIR/monday-api.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# Global variables
COMMAND=""
ENVIRONMENT=""

show_usage() {
  echo "Monday as Code - Infrastructure as Code for Monday.com"
  echo ""
  echo "Usage: ./scripts/deploy.sh <command> --env <environment>"
  echo ""
  echo "Commands:"
  echo "  plan     Preview changes that would be made"
  echo "  apply    Create/update Monday.com resources"
  echo ""
  echo "Environments:"
  echo "  lab         Lab workspace for testing"
  echo "  production  Production workspace"
  echo ""
  echo "Examples:"
  echo "  ./scripts/deploy.sh plan --env lab"
  echo "  ./scripts/deploy.sh apply --env lab"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      plan|apply)
        COMMAND="$1"
        shift
        ;;
      --env)
        ENVIRONMENT="$2"
        shift 2
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        echo -e "${RED}❌ Unknown argument: $1${NC}"
        show_usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$COMMAND" ]]; then
    echo -e "${RED}❌ Command required${NC}"
    show_usage
    exit 1
  fi

  if [[ -z "$ENVIRONMENT" ]]; then
    echo -e "${RED}❌ Environment required (--env)${NC}"
    show_usage
    exit 1
  fi
}

load_environment() {
  local env_file="$PROJECT_ROOT/configs/$ENVIRONMENT.env"
  
  if [[ ! -f "$env_file" ]]; then
    echo -e "${RED}❌ Environment file not found: $env_file${NC}"
    exit 1
  fi

  echo -e "${BLUE}🔧 Loading environment: $ENVIRONMENT${NC}"
  source "$env_file"

  if [[ -z "$MONDAY_API_TOKEN" ]]; then
    echo -e "${RED}❌ MONDAY_API_TOKEN not set${NC}"
    exit 1
  fi

  if [[ -z "$WORKSPACE_ID" ]]; then
    echo -e "${RED}❌ WORKSPACE_ID not set${NC}"
    exit 1
  fi

  echo "   Workspace: $WORKSPACE_ID"
}

setup_directories() {
  mkdir -p "$PROJECT_ROOT/logs"
}

get_resource_files() {
  local resources_path="$PROJECT_ROOT/$RESOURCES_DIR"
  find "$resources_path" -name "*.json" -type f 2>/dev/null | sort
}

substitute_env_vars() {
  local json_content="$1"
  echo "$json_content" | sed "s/\${WORKSPACE_ID}/$WORKSPACE_ID/g"
}

validate_resource_file() {
  local file_path="$1"
  
  if [[ ! -f "$file_path" ]]; then
    echo -e "${RED}❌ Resource file not found: $file_path${NC}"
    return 1
  fi
  
  if ! jq empty "$file_path" 2>/dev/null; then
    echo -e "${RED}❌ Invalid JSON in: $file_path${NC}"
    return 1
  fi
  
  return 0
}

plan_deployment() {
  echo -e "${BOLD}📋 Monday as Code Deployment Plan${NC}"
  echo "Environment: $ENVIRONMENT"
  echo "Workspace ID: $WORKSPACE_ID"
  echo ""

  local user_name=$(test_api_connection)
  if [[ $? -ne 0 ]]; then
    exit 1
  fi
  echo -e "${GREEN}✅ Connected as: $user_name${NC}"
  echo ""

  local boards_response=$(get_workspace_boards "$WORKSPACE_ID")
  local existing_boards=$(echo "$boards_response" | jq -r '.data.boards[]?.name' 2>/dev/null || echo "")
  
  echo "Existing boards:"
  if [[ -n "$existing_boards" ]]; then
    echo "$existing_boards" | sed 's/^/  - /'
  else
    echo "  (no boards found)"
  fi
  echo ""

  local resource_files=$(get_resource_files)
  if [[ -z "$resource_files" ]]; then
    echo -e "${YELLOW}⚠️  No resource files found${NC}"
    return 0
  fi

  echo "Changes to be made:"
  echo ""

  while IFS= read -r file; do
    if ! validate_resource_file "$file"; then
      continue
    fi

    local json_content=$(cat "$file")
    local processed_json=$(substitute_env_vars "$json_content")
    local board_name=$(echo "$processed_json" | jq -r '.spec.board_name')
    local resource_name=$(echo "$processed_json" | jq -r '.name')
    
    if echo "$existing_boards" | grep -q "^$board_name$"; then
      echo -e "  ${YELLOW}📝 UPDATE${NC} Board '$board_name' (resource: $resource_name)"
    else
      echo -e "  ${GREEN}➕ CREATE${NC} Board '$board_name' (resource: $resource_name)"
    fi
  done <<< "$resource_files"

  echo ""
  echo -e "${BLUE}💡 Run 'apply' to make these changes${NC}"
}

apply_deployment() {
  echo -e "${BOLD}🚀 Applying Monday as Code Deployment${NC}"
  echo "Environment: $ENVIRONMENT"
  echo "Workspace ID: $WORKSPACE_ID"
  echo ""

  local user_name=$(test_api_connection)
  if [[ $? -ne 0 ]]; then
    exit 1
  fi
  log_action "CONNECT" "API" "SUCCESS" "User: $user_name"

  local resource_files=$(get_resource_files)
  if [[ -z "$resource_files" ]]; then
    echo -e "${YELLOW}⚠️  No resource files found${NC}"
    return 0
  fi

  while IFS= read -r file; do
    echo -e "${BLUE}📄 Processing $(basename "$file")...${NC}"
    
    if ! validate_resource_file "$file"; then
      continue
    fi

    local json_content=$(cat "$file")
    local processed_json=$(substitute_env_vars "$json_content")
    local resource_name=$(echo "$processed_json" | jq -r '.name')
    local board_name=$(echo "$processed_json" | jq -r '.spec.board_name')
    local board_kind=$(echo "$processed_json" | jq -r '.spec.board_kind // "public"')
    local description=$(echo "$processed_json" | jq -r '.spec.description // ""')
    
    local board_id=""
    if board_id=$(board_exists "$WORKSPACE_ID" "$board_name"); then
      log_action "CHECK" "$resource_name" "EXISTS" "Board ID: $board_id"
    else
      echo -e "${GREEN}➕ Creating board '$board_name'...${NC}"
      
      if board_id=$(create_board "$board_name" "$WORKSPACE_ID" "$board_kind" "$description"); then
        log_action "CREATE" "$resource_name" "SUCCESS" "Board ID: $board_id"
      else
        log_action "CREATE" "$resource_name" "FAILED" "Board creation failed"
        continue
      fi
    fi

    local columns=$(echo "$processed_json" | jq -c '.spec.columns[]?')
    if [[ -n "$columns" ]]; then
      echo -e "${BLUE}🔧 Processing columns...${NC}"
      
      while IFS= read -r column; do
        local col_title=$(echo "$column" | jq -r '.title')
        local col_type=$(echo "$column" | jq -r '.type')
        
        if [[ "$col_type" == "name" ]]; then
          log_action "COLUMN" "$col_title" "SKIPPED" "Name column auto-created"
          continue
        fi
        
        if column_exists "$board_id" "$col_title"; then
          log_action "COLUMN" "$col_title" "SKIPPED" "Already exists"
        else
          if create_column "$board_id" "$col_title" "$col_type"; then
            log_action "COLUMN" "$col_title" "SUCCESS" "Type: $col_type"
          else
            log_action "COLUMN" "$col_title" "FAILED" "Column creation failed"
          fi
        fi
      done <<< "$columns"
    fi

    echo ""
  done <<< "$resource_files"

  echo -e "${GREEN}🎉 Deployment completed!${NC}"
}

main() {
  parse_args "$@"
  load_environment
  setup_directories

  case "$COMMAND" in
    plan)
      plan_deployment
      ;;
    apply)
      apply_deployment
      ;;
    *)
      echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
      exit 1
      ;;
  esac
}

main "$@"
