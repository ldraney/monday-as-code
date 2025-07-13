#!/bin/bash
# scripts/manage-state.sh - Simple state management for Monday as Code

set -e
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_usage() {
  echo "Monday as Code - State Manager"
  echo "Track current state and desired state of your Monday.com infrastructure"
  echo ""
  echo "Usage: ./scripts/manage-state.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  capture-current      Capture current state of all workspaces"
  echo "  show-current         Display current state summary"
  echo "  create-desired       Create desired state file for cleanup planning"
  echo "  compare              Compare current vs desired state"
  echo "  generate-plan        Generate action plan to reach desired state"
  echo ""
  echo "Options:"
  echo "  --workspace <ws>     Target specific workspace: lab, production, crm"
  echo "  --format <fmt>       Output format: json, markdown, summary"
  echo ""
  echo "Examples:"
  echo "  ./scripts/manage-state.sh capture-current"
  echo "  ./scripts/manage-state.sh create-desired --workspace lab"
  echo "  ./scripts/manage-state.sh compare"
}

# Create state directories
setup_state_dirs() {
  mkdir -p "$PROJECT_ROOT/state"
  mkdir -p "$PROJECT_ROOT/state/current"
  mkdir -p "$PROJECT_ROOT/state/desired"
  mkdir -p "$PROJECT_ROOT/state/plans"
}

# Capture current state from existing analysis
capture_current_state() {
  echo -e "${BLUE}📊 Capturing current state...${NC}"
  
  setup_state_dirs
  
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local current_state_file="$PROJECT_ROOT/state/current/lab_state_$(date +%Y%m%d_%H%M%S).json"
  
  # Use existing analysis if available
  if [[ -f "$PROJECT_ROOT/analysis/simple/lab_analysis.json" ]]; then
    echo -e "${BLUE}  Using existing Lab analysis...${NC}"
    
    # Create comprehensive current state
    cat > "$current_state_file" << EOF
{
  "captured_at": "$timestamp",
  "workspaces": {
    "lab": {
      "workspace_id": "9736208",
      "analysis_file": "analysis/simple/lab_analysis.json",
      "total_boards": $(jq -r '.total_boards' "$PROJECT_ROOT/analysis/simple/lab_analysis.json"),
      "connected_boards": $(jq -r '.connected_boards' "$PROJECT_ROOT/analysis/simple/lab_analysis.json"),
      "orphaned_boards": $(jq -r '.orphaned_boards' "$PROJECT_ROOT/analysis/simple/lab_analysis.json"),
      "status": "analyzed"
    },
    "production": {
      "workspace_id": "519072", 
      "status": "not_exported"
    },
    "crm": {
      "workspace_id": "11007618",
      "status": "not_exported"
    }
  },
  "summary": {
    "total_analyzed_boards": $(jq -r '.total_boards' "$PROJECT_ROOT/analysis/simple/lab_analysis.json"),
    "cleanup_opportunity": $(jq -r '.orphaned_boards' "$PROJECT_ROOT/analysis/simple/lab_analysis.json"),
    "workspaces_analyzed": 1,
    "workspaces_remaining": 2
  }
}
EOF
    
    # Create symlink to latest state
    ln -sf "$(basename "$current_state_file")" "$PROJECT_ROOT/state/current/latest.json"
    
    echo -e "${GREEN}✅ Current state captured: $current_state_file${NC}"
  else
    echo -e "${YELLOW}⚠️ No Lab analysis found. Run ./scripts/simple-analyzer.sh first${NC}"
    exit 1
  fi
}

# Show current state summary
show_current_state() {
  echo -e "${BLUE}📋 Current State Summary${NC}"
  echo "======================="
  
  local latest_state="$PROJECT_ROOT/state/current/latest.json"
  
  if [[ -f "$latest_state" ]]; then
    local captured_at=$(jq -r '.captured_at' "$latest_state")
    echo "Last updated: $captured_at"
    echo ""
    
    echo -e "${BLUE}Workspace Status:${NC}"
    jq -r '.workspaces | to_entries[] | "  \(.key): \(.value.status)"' "$latest_state"
    echo ""
    
    echo -e "${BLUE}Lab Workspace Analysis:${NC}"
    local total=$(jq -r '.workspaces.lab.total_boards // 0' "$latest_state")
    local connected=$(jq -r '.workspaces.lab.connected_boards // 0' "$latest_state")
    local orphaned=$(jq -r '.workspaces.lab.orphaned_boards // 0' "$latest_state")
    
    echo "  📋 Total boards: $total"
    echo "  🔗 Connected: $connected"
    echo "  🔍 Orphaned: $orphaned"
    echo ""
    
    if [[ "$orphaned" -gt 0 ]]; then
      echo -e "${YELLOW}💡 Cleanup Opportunity: $orphaned boards could potentially be archived${NC}"
    fi
  else
    echo -e "${YELLOW}⚠️ No current state captured. Run: ./scripts/manage-state.sh capture-current${NC}"
  fi
}

# Create desired state file for cleanup planning
create_desired_state() {
  local workspace="$1"
  
  echo -e "${BLUE}🎯 Creating desired state for $workspace workspace...${NC}"
  
  setup_state_dirs
  
  local desired_state_file="$PROJECT_ROOT/state/desired/${workspace}_desired_state.json"
  
  case "$workspace" in
    lab)
      # Based on the analysis, create a desired state for Lab
      cat > "$desired_state_file" << 'EOF'
{
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "workspace": "lab",
  "desired_board_count": 35,
  "cleanup_plan": {
    "boards_to_keep": {
      "core_workflow": [
        "Development",
        "Accounts", 
        "Prod Deals",
        "Production",
        "Projects"
      ],
      "supporting_workflow": [
        "Bulk Documentation (Finalization)",
        "Bulk Batch Traceability", 
        "Contacts",
        "Lab - Purchasing",
        "Dev Deals"
      ],
      "operational": [
        "Activities",
        "Equipment", 
        "Leads",
        "Production Schedule 2025"
      ]
    },
    "boards_to_archive": {
      "immediate_safe": [
        "Meeting summary",
        "PM Meeting Agendas",
        "Pain Point - Actionables", 
        "Duplicate of Compounding Schedule",
        "New Board",
        "Test Board from Code"
      ],
      "review_first": [
        "Purchasing (deprecated)",
        "Production (Bulk)",
        "TODO - Lab",
        "TODO - Team"
      ],
      "bulk_subitems": "Archive all orphaned subitem boards"
    }
  },
  "success_criteria": {
    "board_reduction": "60-70% reduction in total boards",
    "orphaned_boards": "Less than 5 orphaned boards remaining", 
    "connected_ratio": "90%+ of remaining boards should be connected"
  }
}
EOF
      ;;
    *)
      echo -e "${YELLOW}⚠️ Desired state templates only available for Lab workspace currently${NC}"
      exit 1
      ;;
  esac
  
  echo -e "${GREEN}✅ Desired state created: $desired_state_file${NC}"
  echo ""
  echo "Review and edit this file to match your specific cleanup goals."
}

# Compare current vs desired state
compare_states() {
  echo -e "${BLUE}🔄 Comparing Current vs Desired State${NC}"
  echo "====================================="
  
  local current_state="$PROJECT_ROOT/state/current/latest.json"
  local desired_state="$PROJECT_ROOT/state/desired/lab_desired_state.json"
  
  if [[ ! -f "$current_state" ]]; then
    echo -e "${YELLOW}⚠️ No current state found. Run: ./scripts/manage-state.sh capture-current${NC}"
    exit 1
  fi
  
  if [[ ! -f "$desired_state" ]]; then
    echo -e "${YELLOW}⚠️ No desired state found. Run: ./scripts/manage-state.sh create-desired --workspace lab${NC}"
    exit 1
  fi
  
  # Compare key metrics
  local current_total=$(jq -r '.workspaces.lab.total_boards // 0' "$current_state")
  local current_orphaned=$(jq -r '.workspaces.lab.orphaned_boards // 0' "$current_state")
  local desired_total=$(jq -r '.desired_board_count // 0' "$desired_state")
  
  echo "📊 Board Count Comparison:"
  echo "  Current total: $current_total boards"
  echo "  Desired total: $desired_total boards"
  echo "  Reduction needed: $((current_total - desired_total)) boards"
  echo ""
  
  echo "🎯 Cleanup Progress:"
  echo "  Current orphaned: $current_orphaned boards"
  echo "  Target: <5 orphaned boards"
  echo ""
  
  if [[ $current_total -gt $desired_total ]]; then
    echo -e "${YELLOW}📋 Action Required: Need to archive $((current_total - desired_total)) boards${NC}"
  else
    echo -e "${GREEN}✅ Board count target already achieved!${NC}"
  fi
}

# Generate action plan
generate_action_plan() {
  echo -e "${BLUE}📝 Generating Action Plan...${NC}"
  
  local plan_file="$PROJECT_ROOT/state/plans/cleanup_action_plan_$(date +%Y%m%d_%H%M%S).md"
  
  cat > "$plan_file" << 'EOF'
# Monday.com Lab Workspace - Cleanup Action Plan

**Generated:** $(date)
**Goal:** Reduce Lab workspace from 82 boards to ~35 boards

## Phase 1: Immediate Safe Archives (Low Risk)

### Meeting & Administrative Boards
- [ ] Archive "Meeting summary"
- [ ] Archive "PM Meeting Agendas" 
- [ ] Archive "Pain Point - Actionables"
- [ ] Archive "Production Meeting Delegation"
- [ ] Archive "Production Meetings - Delegated Tasks"

### Duplicate & Test Boards  
- [ ] Archive "Duplicate of Compounding Schedule"
- [ ] Archive "New Board"
- [ ] Archive "New Board Connections"
- [ ] Archive "Test Board from Code"

### Commands:
```bash
# Create backup and archive script for Phase 1
./scripts/archive-board.sh --board-name "Meeting summary" --workspace lab
./scripts/archive-board.sh --board-name "Duplicate of Compounding Schedule" --workspace lab
# (Continue for each board)
```

## Phase 2: Review Required (Medium Risk)

### Legacy Systems
- [ ] Review "Purchasing (deprecated)" - Has 4 connections, migrate first
- [ ] Review "Production (Bulk)" - Check if still needed
- [ ] Review "Production Calendar 2024" - Migrate to 2025 version?

### Task Management
- [ ] Review "TODO - Lab" - Check if actively used
- [ ] Review "TODO - Team" - Check if actively used

### Commands:
```bash
# Review connections before archiving
./scripts/analyze-board.sh --board-name "Purchasing (deprecated)"
```

## Phase 3: Bulk Subitem Cleanup

### Auto-Generated Subitem Boards (40 boards)
- [ ] Bulk archive all orphaned "Subitems of..." boards
- [ ] Keep: Subitems of Accounts, Lab - Purchasing, Production Schedule 2025, Test Board Output 1

### Commands:
```bash
./scripts/bulk-archive-subitems.sh --exclude-connected
```

## Success Metrics

- **Target:** 35 total boards (down from 82)
- **Connected ratio:** 90%+ of remaining boards
- **Orphaned boards:** <5 remaining

## Rollback Plan

All archived boards will have:
- Complete backup of structure and data
- Restore commands documented
- 30-day review period before permanent deletion

EOF
  
  echo -e "${GREEN}✅ Action plan generated: $plan_file${NC}"
}

# Main command dispatcher
main() {
  if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
  fi

  local command=""
  local workspace=""
  local format="json"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      capture-current|show-current|create-desired|compare|generate-plan)
        command="$1"
        shift
        ;;
      --workspace)
        workspace="$2"
        shift 2
        ;;
      --format)
        format="$2"
        shift 2
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

  case "$command" in
    capture-current)
      capture_current_state
      ;;
    show-current)
      show_current_state
      ;;
    create-desired)
      if [[ -z "$workspace" ]]; then
        echo -e "${RED}❌ --workspace required for create-desired${NC}"
        exit 1
      fi
      create_desired_state "$workspace"
      ;;
    compare)
      compare_states
      ;;
    generate-plan)
      generate_action_plan
      ;;
    *)
      echo -e "${RED}❌ Unknown command: $command${NC}"
      show_usage
      exit 1
      ;;
  esac
}

main "$@"
