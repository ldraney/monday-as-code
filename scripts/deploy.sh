#!/bin/bash
# deploy.sh - Monday as Code deployment script (Enhanced with Production Safeguards)
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
FORCE_FLAG=false
DRY_RUN=false

show_usage() {
  echo "Monday as Code - Infrastructure as Code for Monday.com"
  echo ""
  echo "Usage: ./scripts/deploy.sh <command> --env <environment> [options]"
  echo ""
  echo "Commands:"
  echo "  plan      Preview changes that would be made"
  echo "  apply     Create/update Monday.com resources"
  echo "  destroy   Remove resources (use with extreme caution)"
  echo "  validate  Validate configuration files"
  echo ""
  echo "Environments:"
  echo "  lab         Lab workspace for testing"
  echo "  production  Production workspace"
  echo ""
  echo "Options:"
  echo "  --force     Skip confirmation prompts (use with caution)"
  echo "  --dry-run   Show what would be done without making changes"
  echo ""
  echo "Examples:"
  echo "  ./scripts/deploy.sh plan --env lab"
  echo "  ./scripts/deploy.sh apply --env lab"
  echo "  ./scripts/deploy.sh apply --env production"
  echo "  ./scripts/deploy.sh validate --env lab --dry-run"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      plan|apply|destroy|validate)
        COMMAND="$1"
        shift
        ;;
      --env)
        ENVIRONMENT="$2"
        shift 2
        ;;
      --force)
        FORCE_FLAG=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
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
  echo "   Description: ${ENV_DESCRIPTION:-No description}"

  # Check if this is a production environment and apply safeguards
  if [[ "$ENVIRONMENT" == "production" ]]; then
    echo -e "${YELLOW}⚠️  PRODUCTION ENVIRONMENT DETECTED${NC}"
    
    if [[ "$REQUIRE_WORKSPACE_CONFIRMATION" == "true" && "$FORCE_FLAG" == "false" ]]; then
      echo -e "${YELLOW}Production deployment requires workspace confirmation${NC}"
      confirm_workspace_access
    fi

    if [[ "$CONFIRM_BEFORE_APPLY" == "true" && "$COMMAND" == "apply" && "$FORCE_FLAG" == "false" ]]; then
      echo -e "${YELLOW}Production deployment requires explicit confirmation${NC}"
      confirm_production_deployment
    fi
  fi
}

confirm_workspace_access() {
  echo -e "${BLUE}🔐 Verifying production workspace access...${NC}"
  
  local user_name=$(test_api_connection)
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  local boards_response=$(get_workspace_boards "$WORKSPACE_ID")
  local board_count=$(echo "$boards_response" | jq -r '.data.boards | length' 2>/dev/null || echo "0")
  
  echo "Connected as: $user_name"
  echo "Workspace contains: $board_count boards"
  echo ""
  
  if [[ "$board_count" -eq 0 ]]; then
    echo -e "${RED}❌ No boards found in workspace. Please verify workspace ID.${NC}"
    exit 1
  fi

  read -p "Confirm this is the correct production workspace? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo -e "${YELLOW}Deployment cancelled by user${NC}"
    exit 0
  fi
}

confirm_production_deployment() {
  echo -e "${YELLOW}🚨 PRODUCTION DEPLOYMENT CONFIRMATION${NC}"
  echo "Environment: $ENVIRONMENT"
  echo "Workspace ID: $WORKSPACE_ID"
  echo "Command: $COMMAND"
  echo ""
  echo -e "${RED}This will make changes to your production Monday.com workspace.${NC}"
  echo ""
  
  read -p "Type 'DEPLOY PRODUCTION' to confirm: " confirm
  if [[ "$confirm" != "DEPLOY PRODUCTION" ]]; then
    echo -e "${YELLOW}Production deployment cancelled${NC}"
    exit 0
  fi
}

setup_directories() {
  mkdir -p "$PROJECT_ROOT/logs"
  mkdir -p "$PROJECT_ROOT/backups/$ENVIRONMENT"
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

  # Validate required fields
  local json_content=$(cat "$file_path")
  local resource_type=$(echo "$json_content" | jq -r '.resource_type // "null"')
  local resource_name=$(echo "$json_content" | jq -r '.name // "null"')
  local board_name=$(echo "$json_content" | jq -r '.spec.board_name // "null"')

  if [[ "$resource_type" == "null" ]]; then
    echo -e "${RED}❌ Missing 'resource_type' in: $file_path${NC}"
    return 1
  fi

  if [[ "$resource_name" == "null" ]]; then
    echo -e "${RED}❌ Missing 'name' in: $file_path${NC}"
    return 1
  fi

  if [[ "$board_name" == "null" ]]; then
    echo -e "${RED}❌ Missing 'spec.board_name' in: $file_path${NC}"
    return 1
  fi
  
  return 0
}

validate_deployment() {
  echo -e "${BOLD}🔍 Validating Monday as Code Configuration${NC}"
  echo "Environment: $ENVIRONMENT"
  echo ""

  local resource_files=$(get_resource_files)
  if [[ -z "$resource_files" ]]; then
    echo -e "${YELLOW}⚠️  No resource files found${NC}"
    return 0
  fi

  local validation_failed=false

  while IFS= read -r file; do
    echo -e "${BLUE}📄 Validating $(basename "$file")...${NC}"
    
    if ! validate_resource_file "$file"; then
      validation_failed=true
      continue
    fi

    local json_content=$(cat "$file")
    local processed_json=$(substitute_env_vars "$json_content")
    
    # Additional validation checks
    local columns=$(echo "$processed_json" | jq -c '.spec.columns[]?' 2>/dev/null)
    if [[ -n "$columns" ]]; then
      while IFS= read -r column; do
        local col_type=$(echo "$column" | jq -r '.type')
        local col_title=$(echo "$column" | jq -r '.title')
        
        if [[ -z "$col_type" || "$col_type" == "null" ]]; then
          echo -e "${RED}❌ Missing column type for '$col_title'${NC}"
          validation_failed=true
        fi
      done <<< "$columns"
    fi

    echo -e "${GREEN}✅ Valid: $(basename "$file")${NC}"
  done <<< "$resource_files"

  if [[ "$validation_failed" == "true" ]]; then
    echo -e "${RED}❌ Validation failed${NC}"
    exit 1
  else
    echo -e "${GREEN}🎉 All configurations valid!${NC}"
  fi
}

create_backup() {
  if [[ "$ENVIRONMENT" == "production" ]]; then
    echo -e "${BLUE}💾 Creating backup before production deployment...${NC}"
    
    local backup_file="$PROJECT_ROOT/backups/$ENVIRONMENT/backup-$(date +%Y%m%d-%H%M%S).json"
    local boards_response=$(get_workspace_boards "$WORKSPACE_ID")
    
    echo "$boards_response" > "$backup_file"
    log_action "BACKUP" "workspace" "SUCCESS" "Saved to: $backup_file"
  fi
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
  local board_count=$(echo "$boards_response" | jq -r '.data.boards | length' 2>/dev/null || echo "0")
  
  echo "📊 Workspace Status:"
  echo "   Total boards: $board_count"
  echo "   Sample boards: $(echo "$existing_boards" | head -3 | tr '\n' ', ' | sed 's/,$//' | sed 's/,/, /g')"
  if [[ "$board_count" -gt 3 ]]; then
    echo "   (and $((board_count - 3)) more...)"
  fi
  echo ""

  local resource_files=$(get_resource_files)
  if [[ -z "$resource_files" ]]; then
    echo -e "${YELLOW}⚠️  No resource files found${NC}"
    return 0
  fi

  echo "📝 Changes to be made:"
  echo ""

  local create_count=0
  local update_count=0

  while IFS= read -r file; do
    if ! validate_resource_file "$file"; then
      continue
    fi

    local json_content=$(cat "$file")
    local processed_json=$(substitute_env_vars "$json_content")
    local board_name=$(echo "$processed_json" | jq -r '.spec.board_name')
    local resource_name=$(echo "$processed_json" | jq -r '.name')
    local description=$(echo "$processed_json" | jq -r '.spec.description // ""')
    
    if echo "$existing_boards" | grep -q "^$board_name$"; then
      echo -e "  ${YELLOW}📝 UPDATE${NC} Board '$board_name' (resource: $resource_name)"
      if [[ -n "$description" ]]; then
        echo "      Description: $description"
      fi
      ((update_count++))
    else
      echo -e "  ${GREEN}➕ CREATE${NC} Board '$board_name' (resource: $resource_name)"
      if [[ -n "$description" ]]; then
        echo "      Description: $description"
      fi
      ((create_count++))
    fi

    # Show column changes
    local columns=$(echo "$processed_json" | jq -c '.spec.columns[]?' 2>/dev/null)
    if [[ -n "$columns" ]]; then
      local column_count=$(echo "$processed_json" | jq '.spec.columns | length')
      echo "      Columns: $column_count configured"
    fi
    echo ""
  done <<< "$resource_files"

  echo "📊 Summary:"
  echo "   Boards to create: $create_count"
  echo "   Boards to update: $update_count"
  echo "   Total operations: $((create_count + update_count))"
  echo ""

  if [[ "$ENVIRONMENT" == "production" ]]; then
    echo -e "${YELLOW}⚠️  This is a PRODUCTION deployment${NC}"
    echo "   Backup will be created automatically"
    echo "   Additional confirmations may be required"
    echo ""
  fi

  echo -e "${BLUE}💡 Run 'apply' to execute these changes${NC}"
}

apply_deployment() {
  echo -e "${BOLD}🚀 Applying Monday as Code Deployment${NC}"
  echo "Environment: $ENVIRONMENT"
  echo "Workspace ID: $WORKSPACE_ID"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}"
  fi
  echo ""

  local user_name=$(test_api_connection)
  if [[ $? -ne 0 ]]; then
    exit 1
  fi
  log_action "CONNECT" "API" "SUCCESS" "User: $user_name"

  # Create backup for production
  create_backup

  local resource_files=$(get_resource_files)
  if [[ -z "$resource_files" ]]; then
    echo -e "${YELLOW}⚠️  No resource files found${NC}"
    return 0
  fi

  local success_count=0
  local error_count=0

  while IFS= read -r file; do
    echo -e "${BLUE}📄 Processing $(basename "$file")...${NC}"
    
    if ! validate_resource_file "$file"; then
      ((error_count++))
      continue
    fi

    local json_content=$(cat "$file")
    local processed_json=$(substitute_env_vars "$json_content")
    local resource_name=$(echo "$processed_json" | jq -r '.name')
    local board_name=$(echo "$processed_json" | jq -r '.spec.board_name')
    local board_kind=$(echo "$processed_json" | jq -r '.spec.board_kind // "public"')
    local description=$(echo "$processed_json" | jq -r '.spec.description // ""')
    
    if [[ "$DRY_RUN" == "true" ]]; then
      echo -e "${YELLOW}🔍 DRY RUN: Would process board '$board_name'${NC}"
      continue
    fi
    
    local board_id=""
    if board_id=$(board_exists "$WORKSPACE_ID" "$board_name"); then
      log_action "CHECK" "$resource_name" "EXISTS" "Board ID: $board_id"
    else
      echo -e "${GREEN}➕ Creating board '$board_name'...${NC}"
      
      if board_id=$(create_board "$board_name" "$WORKSPACE_ID" "$board_kind" "$description"); then
        log_action "CREATE" "$resource_name" "SUCCESS" "Board ID: $board_id"
        ((success_count++))
      else
        log_action "CREATE" "$resource_name" "FAILED" "Board creation failed"
        ((error_count++))
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
            ((error_count++))
          fi
        fi
      done <<< "$columns"
    fi

    echo ""
  done <<< "$resource_files"

  echo -e "${BOLD}📊 Deployment Summary${NC}"
  echo "   Successful operations: $success_count"
  echo "   Failed operations: $error_count"
  
  if [[ "$error_count" -eq 0 ]]; then
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    log_action "DEPLOY" "$ENVIRONMENT" "SUCCESS" "All resources deployed"
  else
    echo -e "${YELLOW}⚠️  Deployment completed with errors${NC}"
    log_action "DEPLOY" "$ENVIRONMENT" "PARTIAL" "$error_count errors occurred"
  fi
}

destroy_resources() {
  echo -e "${RED}🗑️  DESTROY OPERATION${NC}"
  echo -e "${RED}This will DELETE Monday.com resources!${NC}"
  echo ""
  
  if [[ "$ENVIRONMENT" == "production" && "$FORCE_FLAG" == "false" ]]; then
    echo -e "${RED}❌ Destroy operations on production require --force flag${NC}"
    echo "This is a safety measure to prevent accidental deletions"
    exit 1
  fi

  if [[ "$FORCE_FLAG" == "false" ]]; then
    echo -e "${YELLOW}Type 'DELETE RESOURCES' to confirm destruction:${NC}"
    read -p "> " confirm
    if [[ "$confirm" != "DELETE RESOURCES" ]]; then
      echo -e "${YELLOW}Destroy operation cancelled${NC}"
      exit 0
    fi
  fi

  echo -e "${RED}⚠️  Destroy functionality not yet implemented${NC}"
  echo "This feature will be added in a future release"
  echo "For now, please delete boards manually through Monday.com UI"
}

main() {
  parse_args "$@"
  load_environment
  setup_directories

  case "$COMMAND" in
    validate)
      validate_deployment
      ;;
    plan)
      plan_deployment
      ;;
    apply)
      apply_deployment
      ;;
    destroy)
      destroy_resources
      ;;
    *)
      echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
      exit 1
      ;;
  esac
}

main "$@"
