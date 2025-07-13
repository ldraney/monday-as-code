#!/bin/bash
# scripts/visualize-connections.sh - Generate visual connection maps and diagrams
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Create visualization directories
mkdir -p "$PROJECT_ROOT/visualizations"
mkdir -p "$PROJECT_ROOT/visualizations/mermaid"
mkdir -p "$PROJECT_ROOT/visualizations/graphviz"
mkdir -p "$PROJECT_ROOT/visualizations/html"

show_usage() {
  echo "Monday.com Connection Visualizer - Generate visual maps of board relationships"
  echo ""
  echo "Usage: ./scripts/visualize-connections.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  workspace-overview   Generate workspace-level connection overview"
  echo "  detailed-flow        Create detailed board connection flow"
  echo "  cleanup-candidates   Visualize boards marked for cleanup"
  echo "  crm-flow            Show CRM-centric connection flow"
  echo "  interactive-html     Generate interactive HTML visualization"
  echo "  all-formats         Generate all visualization formats"
  echo ""
  echo "Options:"
  echo "  --format <fmt>       Output format: mermaid, graphviz, html, svg, png"
  echo "  --workspace <ws>     Focus on specific workspace: lab, production, crm"
  echo "  --include-orphans    Include orphaned boards in visualization"
  echo "  --highlight-issues   Highlight problematic connections"
  echo "  --export-path <p>    Custom export path for visualizations"
  echo ""
  echo "Examples:"
  echo "  ./scripts/visualize-connections.sh workspace-overview --format mermaid"
  echo "  ./scripts/visualize-connections.sh crm-flow --format html"
  echo "  ./scripts/visualize-connections.sh cleanup-candidates --highlight-issues"
}

# Check prerequisites
check_prerequisites() {
  # Check if connection analysis exists
  if [[ ! -f "$PROJECT_ROOT/analysis/connections/board_connections.json" ]]; then
    echo -e "${YELLOW}⚠️ No connection analysis found. Running analysis first...${NC}"
    "$PROJECT_ROOT/scripts/analyze-connections.sh" map-all
  fi
  
  # Check if cleanup plan exists
  if [[ ! -f "$PROJECT_ROOT/analysis/cleanup/cleanup_plan.json" ]]; then
    echo -e "${YELLOW}⚠️ No cleanup plan found. Generating now...${NC}"
    "$PROJECT_ROOT/scripts/analyze-connections.sh" identify-orphans
  fi
}

# Generate workspace overview diagram
generate_workspace_overview() {
  local format="$1"
  local output_dir="$PROJECT_ROOT/visualizations/$format"
  
  echo -e "${BLUE}🗺️ Generating workspace overview ($format)...${NC}"
  
  local connections_file="$PROJECT_ROOT/analysis/connections/board_connections.json"
  
  case "$format" in
    mermaid)
      generate_mermaid_workspace_overview "$connections_file" "$output_dir/workspace_overview.mmd"
      ;;
    graphviz)
      generate_graphviz_workspace_overview "$connections_file" "$output_dir/workspace_overview.dot"
      ;;
    html)
      generate_html_workspace_overview "$connections_file" "$output_dir/workspace_overview.html"
      ;;
    *)
      echo -e "${RED}❌ Unsupported format for workspace overview: $format${NC}"
      exit 1
      ;;
  esac
}

# Generate Mermaid workspace overview
generate_mermaid_workspace_overview() {
  local connections_file="$1"
  local output_file="$2"
  
  jq -r '
    # Calculate workspace statistics
    (.connections | group_by(.workspace) | map({
      workspace: .[0].workspace,
      total_boards: length,
      connected_boards: ([.[] | select(.connection_count > 0)] | length),
      orphaned_boards: ([.[] | select(.connection_count == 0)] | length),
      deprecated_boards: ([.[] | select(.is_deprecated)] | length)
    })) as $workspace_stats |
    
    "graph TD" as $header |
    "  %% Monday.com Workspace Connection Overview" as $comment1 |
    "  %% Generated: " + (now | strftime("%Y-%m-%d %H:%M:%S")) as $comment2 |
    "" as $blank |
    
    # Workspace nodes with statistics
    ($workspace_stats | map(
      "  " + (.workspace | ascii_upcase) + "_WS[\"" + (.workspace | ascii_upcase) + " Workspace<br/>" +
      "📋 " + (.total_boards | tostring) + " boards<br/>" +
      "🔗 " + (.connected_boards | tostring) + " connected<br/>" +
      "🔍 " + (.orphaned_boards | tostring) + " orphaned" +
      (if .deprecated_boards > 0 then "<br/>⚠️ " + (.deprecated_boards | tostring) + " deprecated" else "" end) +
      "\"]"
    )) as $workspace_nodes |
    
    # Cross-workspace connections (simplified)
    (["  %% Cross-workspace connection patterns"] +
     [.connections[] | 
      select(.connections | length > 0) |
      .connections[] |
      select(.potential_target) |
      # Simplify to workspace-level connections
      (.board_name | ascii_upcase | .[0:3]) + "_WS --> " + 
      (.potential_target | ascii_upcase | .[0:3]) + "_WS"
     ] | unique) as $cross_connections |
    
    # Styling
    (["  %% Workspace styling"] +
     ["  classDef labStyle fill:#e3f2fd,stroke:#1976d2,stroke-width:2px"] +
     ["  classDef prodStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px"] +
     ["  classDef crmStyle fill:#e8f5e8,stroke:#388e3c,stroke-width:2px"] +
     ["  classDef issueStyle fill:#ffebee,stroke:#d32f2f,stroke-width:3px"] +
     [""] +
     ["  class LAB_WS labStyle"] +
     ["  class PRODUCTION_WS prodStyle"] +
     ["  class CRM_WS crmStyle"]) as $styling |
    
    [$header, $comment1, $comment2, $blank] +
    $workspace_nodes + [$blank] +
    $cross_connections + [$blank] +
    $styling |
    join("\n")
  ' "$connections_file" > "$output_file"
  
  echo -e "${GREEN}✅ Mermaid workspace overview: $output_file${NC}"
}

# Generate detailed board connection flow
generate_detailed_flow() {
  local format="$1"
  local workspace="$2"
  local output_dir="$PROJECT_ROOT/visualizations/$format"
  
  echo -e "${BLUE}🔄 Generating detailed connection flow ($format)...${NC}"
  
  local connections_file="$PROJECT_ROOT/analysis/connections/board_connections.json"
  local output_file="$output_dir/detailed_flow"
  
  if [[ -n "$workspace" ]]; then
    output_file="${output_file}_${workspace}"
  fi
  
  case "$format" in
    mermaid)
      generate_mermaid_detailed_flow "$connections_file" "$workspace" "${output_file}.mmd"
      ;;
    graphviz)
      generate_graphviz_detailed_flow "$connections_file" "$workspace" "${output_file}.dot"
      ;;
    html)
      generate_html_detailed_flow "$connections_file" "$workspace" "${output_file}.html"
      ;;
    *)
      echo -e "${RED}❌ Unsupported format for detailed flow: $format${NC}"
      exit 1
      ;;
  esac
}

# Generate Mermaid detailed flow
generate_mermaid_detailed_flow() {
  local connections_file="$1"
  local workspace_filter="$2"
  local output_file="$3"
  
  local workspace_condition=""
  if [[ -n "$workspace_filter" ]]; then
    workspace_condition="| select(.workspace == \"$workspace_filter\")"
  fi
  
  jq -r --arg workspace_filter "$workspace_filter" '
    "graph TD" as $header |
    "  %% Monday.com Detailed Board Connection Flow" as $comment1 |
    (if $workspace_filter != "" then "  %% Workspace: " + $workspace_filter else "  %% All Workspaces" end) as $comment2 |
    "  %% Generated: " + (now | strftime("%Y-%m-%d %H:%M:%S")) as $comment3 |
    "" as $blank |
    
    # Filter boards based on workspace if specified
    (if $workspace_filter != "" then 
      [.connections[] | select(.workspace == $workspace_filter)]
    else 
      .connections
    end) as $boards |
    
    # Create board nodes with connection indicators
    ($boards | map(
      "  " + (.resource_name | gsub("-"; "_")) + "[\"" + .board_name + 
      (if .connection_count > 0 then "<br/>🔗 " + (.connection_count | tostring) + " connections" else "<br/>🔍 orphaned" end) +
      (if .is_deprecated then "<br/>⚠️ deprecated" else "" end) +
      "\"]"
    )) as $board_nodes |
    
    # Create connections between boards
    ($boards | map(
      select(.connections | length > 0) |
      .connections[] |
      select(.potential_target) |
      "  " + ((.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-")) | gsub("-"; "_")) + 
      " --> " + (.potential_target | gsub("-"; "_")) + 
      "[\"" + .column_title + "\"]"
    )) as $connections |
    
    # Group boards by workspace if showing all
    (if $workspace_filter == "" then
      ["  subgraph LAB[\"Lab Workspace\"]"] +
      [$boards[] | select(.workspace == "lab") | "    " + (.resource_name | gsub("-"; "_"))] +
      ["  end", ""] +
      ["  subgraph PROD[\"Production Workspace\"]"] +
      [$boards[] | select(.workspace == "production") | "    " + (.resource_name | gsub("-"; "_"))] +
      ["  end", ""] +
      ["  subgraph CRM[\"CRM Workspace\"]"] +
      [$boards[] | select(.workspace == "crm") | "    " + (.resource_name | gsub("-"; "_"))] +
      ["  end", ""]
    else [] end) as $subgraphs |
    
    # Styling based on board status
    (["  %% Board styling"] +
     ["  classDef connected fill:#d4edda,stroke:#28a745,stroke-width:2px"] +
     ["  classDef orphaned fill:#fff3cd,stroke:#ffc107,stroke-width:2px"] +
     ["  classDef deprecated fill:#f8d7da,stroke:#dc3545,stroke-width:2px"] +
     [""] +
     # Apply styles to boards
     ($boards | map(
       "  class " + (.resource_name | gsub("-"; "_")) + " " +
       (if .is_deprecated then "deprecated"
        elif .connection_count > 0 then "connected"
        else "orphaned" end)
     ))) as $styling |
    
    [$header, $comment1, $comment2, $comment3, $blank] +
    (if $workspace_filter == "" then $subgraphs else $board_nodes + [$blank] end) +
    $connections + [$blank] +
    $styling |
    join("\n")
  ' "$connections_file" > "$output_file"
  
  echo -e "${GREEN}✅ Mermaid detailed flow: $output_file${NC}"
}

# Generate cleanup candidates visualization
generate_cleanup_visualization() {
  local format="$1"
  local highlight_issues="${2:-false}"
  local output_dir="$PROJECT_ROOT/visualizations/$format"
  
  echo -e "${BLUE}🧹 Generating cleanup candidates visualization ($format)...${NC}"
  
  local cleanup_file="$PROJECT_ROOT/analysis/cleanup/cleanup_plan.json"
  local output_file="$output_dir/cleanup_candidates"
  
  case "$format" in
    mermaid)
      generate_mermaid_cleanup_viz "$cleanup_file" "$highlight_issues" "${output_file}.mmd"
      ;;
    html)
      generate_html_cleanup_viz "$cleanup_file" "$highlight_issues" "${output_file}.html"
      ;;
    *)
      echo -e "${RED}❌ Unsupported format for cleanup visualization: $format${NC}"
      exit 1
      ;;
  esac
}

# Generate Mermaid cleanup visualization
generate_mermaid_cleanup_viz() {
  local cleanup_file="$1"
  local highlight_issues="$2"
  local output_file="$3"
  
  jq -r --argjson highlight_issues "$highlight_issues" '
    "graph TD" as $header |
    "  %% Monday.com Board Cleanup Plan" as $comment1 |
    "  %% Generated: " + (now | strftime("%Y-%m-%d %H:%M:%S")) as $comment2 |
    "" as $blank |
    
    # Cleanup categories as root nodes
    (["  CLEANUP[\"📋 Board Cleanup Plan\"]"] +
     ["  DEPRECATED[\"⚠️ Deprecated Boards<br/>(" + (.cleanup_plan.cleanup_categories.deprecated_boards.count | tostring) + ")\"]"] +
     ["  ORPHANED[\"🔍 Orphaned Boards<br/>(" + (.cleanup_plan.cleanup_categories.orphaned_boards.count | tostring) + ")\"]"] +
     ["  TEST[\"🧪 Test/Demo Boards<br/>(" + (.cleanup_plan.cleanup_categories.test_boards.count | tostring) + ")\"]"]) as $category_nodes |
    
    # Connect main node to categories
    (["  CLEANUP --> DEPRECATED"] +
     ["  CLEANUP --> ORPHANED"] +
     ["  CLEANUP --> TEST"]) as $category_connections |
    
    # Board nodes for each category
    (.cleanup_plan.cleanup_categories.deprecated_boards.boards | map(
      "  DEP_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_")) + 
      "[\"" + .board_name + "<br/>📍 " + .workspace + "\"]"
    )) as $deprecated_boards |
    
    (.cleanup_plan.cleanup_categories.orphaned_boards.boards | map(
      "  ORP_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_")) + 
      "[\"" + .board_name + "<br/>📍 " + .workspace + "\"]"
    )) as $orphaned_boards |
    
    (.cleanup_plan.cleanup_categories.test_boards.boards | map(
      "  TEST_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_")) + 
      "[\"" + .board_name + "<br/>📍 " + .workspace + "\"]"
    )) as $test_boards |
    
    # Connect categories to boards
    (.cleanup_plan.cleanup_categories.deprecated_boards.boards | map(
      "  DEPRECATED --> DEP_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_"))
    )) as $deprecated_connections |
    
    (.cleanup_plan.cleanup_categories.orphaned_boards.boards | map(
      "  ORPHANED --> ORP_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_"))
    )) as $orphaned_connections |
    
    (.cleanup_plan.cleanup_categories.test_boards.boards | map(
      "  TEST --> TEST_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_"))
    )) as $test_connections |
    
    # Styling
    (["  %% Cleanup styling"] +
     ["  classDef cleanup fill:#e3f2fd,stroke:#1976d2,stroke-width:3px"] +
     ["  classDef deprecated fill:#ffebee,stroke:#d32f2f,stroke-width:2px"] +
     ["  classDef orphaned fill:#fff3cd,stroke:#ff8f00,stroke-width:2px"] +
     ["  classDef test fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px"] +
     ["  classDef board fill:#f5f5f5,stroke:#666,stroke-width:1px"] +
     [""] +
     ["  class CLEANUP cleanup"] +
     ["  class DEPRECATED deprecated"] +
     ["  class ORPHANED orphaned"] +
     ["  class TEST test"] +
     # Apply board styling
     (.cleanup_plan.cleanup_categories.deprecated_boards.boards | map(
       "  class DEP_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_")) + " board"
     )) +
     (.cleanup_plan.cleanup_categories.orphaned_boards.boards | map(
       "  class ORP_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_")) + " board"
     )) +
     (.cleanup_plan.cleanup_categories.test_boards.boards | map(
       "  class TEST_" + (.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-") | gsub("-"; "_")) + " board"
     ))) as $styling |
    
    [$header, $comment1, $comment2, $blank] +
    $category_nodes + [$blank] +
    $category_connections + [$blank] +
    $deprecated_boards + $orphaned_boards + $test_boards + [$blank] +
    $deprecated_connections + $orphaned_connections + $test_connections + [$blank] +
    $styling |
    join("\n")
  ' "$cleanup_file" > "$output_file"
  
  echo -e "${GREEN}✅ Mermaid cleanup visualization: $output_file${NC}"
}

# Generate CRM-centric flow
generate_crm_flow() {
  local format="$1"
  local output_dir="$PROJECT_ROOT/visualizations/$format"
  
  echo -e "${BLUE}🎯 Generating CRM-centric flow ($format)...${NC}"
  
  local connections_file="$PROJECT_ROOT/analysis/connections/board_connections.json"
  local output_file="$output_dir/crm_flow"
  
  case "$format" in
    mermaid)
      generate_mermaid_crm_flow "$connections_file" "${output_file}.mmd"
      ;;
    html)
      generate_html_crm_flow "$connections_file" "${output_file}.html"
      ;;
    *)
      echo -e "${RED}❌ Unsupported format for CRM flow: $format${NC}"
      exit 1
      ;;
  esac
}

# Generate Mermaid CRM flow
generate_mermaid_crm_flow() {
  local connections_file="$1"
  local output_file="$2"
  
  jq -r '
    "graph LR" as $header |
    "  %% CRM-Centric Board Connection Flow" as $comment1 |
    "  %% Shows how customer data flows through the organization" as $comment2 |
    "  %% Generated: " + (now | strftime("%Y-%m-%d %H:%M:%S")) as $comment3 |
    "" as $blank |
    
    # Identify CRM and customer-related boards
    ([.connections[] | 
      select(.board_name | test("(?i)(crm|contact|account|deal|lead|customer)")) or 
      (.connections[]? | select(.column_title | test("(?i)(crm|contact|account|deal|customer)")))
    ]) as $crm_boards |
    
    # Identify sales and production boards that connect to CRM
    ([.connections[] | 
      select(.connections[]? | select(.potential_target | test("(?i)(account|contact|deal)")))
    ]) as $connected_boards |
    
    # CRM core nodes
    ($crm_boards | map(
      "  " + (.resource_name | gsub("-"; "_")) + "[\"" + .board_name + 
      "<br/>📍 " + .workspace + "\"]"
    )) as $crm_nodes |
    
    # Connected board nodes  
    ($connected_boards | map(
      select([.] | inside($crm_boards) | not) |
      "  " + (.resource_name | gsub("-"; "_")) + "[\"" + .board_name + 
      "<br/>📍 " + .workspace + "\"]"
    )) as $connected_nodes |
    
    # Flow connections showing data movement
    ($connected_boards | map(
      .connections[] |
      select(.potential_target | test("(?i)(account|contact|deal)")) |
      "  " + ((.board_name | ascii_downcase | gsub("[^a-z0-9-]"; "-")) | gsub("-"; "_")) + 
      " --> " + (.potential_target | gsub("-"; "_")) + 
      "[\"" + .column_title + "\"]"
    )) as $flow_connections |
    
    # Key customer journey stages
    (["  subgraph CUSTOMER_JOURNEY[\"Customer Journey\"]"] +
     ["    LEADS[\"🎯 Leads\"]"] +
     ["    CONTACTS[\"👤 Contacts\"] "] +
     ["    ACCOUNTS[\"🏢 Accounts\"]"] +
     ["    DEALS[\"💰 Deals\"]"] +
     ["    PRODUCTION[\"🏭 Production\"]"] +
     ["  end"]) as $journey_subgraph |
    
    # Journey flow
    (["  LEADS --> CONTACTS"] +
     ["  CONTACTS --> ACCOUNTS"] +
     ["  ACCOUNTS --> DEALS"] +
     ["  DEALS --> PRODUCTION"]) as $journey_flow |
    
    # Styling for CRM flow
    (["  %% CRM Flow styling"] +
     ["  classDef crm fill:#e8f5e8,stroke:#2e7d32,stroke-width:3px"] +
     ["  classDef sales fill:#e3f2fd,stroke:#1565c0,stroke-width:2px"] +
     ["  classDef production fill:#fff3e0,stroke:#ef6c00,stroke-width:2px"] +
     ["  classDef journey fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px"] +
     [""] +
     # Apply CRM styling to actual CRM boards
     ($crm_boards | map(
       "  class " + (.resource_name | gsub("-"; "_")) + " crm"
     )) +
     # Journey node styling
     ["  class LEADS,CONTACTS,ACCOUNTS,DEALS,PRODUCTION journey"]) as $styling |
    
    [$header, $comment1, $comment2, $comment3, $blank] +
    $journey_subgraph + [$blank] +
    $journey_flow + [$blank] +
    $crm_nodes + $connected_nodes + [$blank] +
    $flow_connections + [$blank] +
    $styling |
    join("\n")
  ' "$connections_file" > "$output_file"
  
  echo -e "${GREEN}✅ Mermaid CRM flow: $output_file${NC}"
}

# Generate interactive HTML visualization
generate_interactive_html() {
  local output_file="$PROJECT_ROOT/visualizations/html/interactive_dashboard.html"
  
  echo -e "${BLUE}🌐 Generating interactive HTML dashboard...${NC}"
  
  local connections_file="$PROJECT_ROOT/analysis/connections/board_connections.json"
  local cleanup_file="$PROJECT_ROOT/analysis/cleanup/cleanup_plan.json"
  
  # Read data into variables for embedding
  local connections_data=$(cat "$connections_file")
  local cleanup_data=$(cat "$cleanup_file")
  
  cat > "$output_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Monday.com Connection Dashboard</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.5/d3.min.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .dashboard {
            max-width: 1400px;
            margin: 0 auto;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            text-align: center;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            text-align: center;
        }
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            font-size: 1.1em;
            color: #666;
            margin-top: 10px;
        }
        .visualization-section {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 30px;
        }
        .section-title {
            font-size: 1.5em;
            font-weight: bold;
            margin-bottom: 20px;
            color: #333;
        }
        .workspace-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .workspace-card {
            border: 2px solid #ddd;
            border-radius: 8px;
            padding: 20px;
            background: #fafafa;
        }
        .workspace-card.lab { border-color: #2196F3; }
        .workspace-card.production { border-color: #9C27B0; }
        .workspace-card.crm { border-color: #4CAF50; }
        .board-list {
            max-height: 200px;
            overflow-y: auto;
            margin-top: 15px;
        }
        .board-item {
            padding: 8px;
            margin: 5px 0;
            border-radius: 5px;
            font-size: 0.9em;
        }
        .board-item.connected { background: #e8f5e8; }
        .board-item.orphaned { background: #fff3cd; }
        .board-item.deprecated { background: #ffebee; }
        .cleanup-section {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
        }
        .cleanup-category {
            border-left: 5px solid #666;
            padding: 20px;
            background: #f9f9f9;
            border-radius: 5px;
        }
        .cleanup-category.deprecated { border-left-color: #f44336; }
        .cleanup-category.orphaned { border-left-color: #ff9800; }
        .cleanup-category.test { border-left-color: #9c27b0; }
        .board-count {
            font-size: 1.2em;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .action-buttons {
            margin-top: 20px;
            text-align: center;
        }
        .btn {
            background: #667eea;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            margin: 5px;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
        }
        .btn:hover {
            background: #5a6fd8;
        }
        .generated-info {
            text-align: center;
            color: #666;
            font-size: 0.9em;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="dashboard">
        <div class="header">
            <h1>📊 Monday.com Connection Dashboard</h1>
            <p>Infrastructure as Code - Board Relationship Analysis</p>
        </div>

        <div class="stats-grid" id="stats-grid">
            <!-- Stats will be populated by JavaScript -->
        </div>

        <div class="visualization-section">
            <div class="section-title">📋 Workspace Overview</div>
            <div class="workspace-grid" id="workspace-grid">
                <!-- Workspace cards will be populated by JavaScript -->
            </div>
        </div>

        <div class="visualization-section">
            <div class="section-title">🧹 Cleanup Candidates</div>
            <div class="cleanup-section" id="cleanup-section">
                <!-- Cleanup categories will be populated by JavaScript -->
            </div>
        </div>

        <div class="action-buttons">
            <a href="#" class="btn" onclick="downloadMermaid()">📊 Download Mermaid Diagram</a>
            <a href="#" class="btn" onclick="generateReport()">📄 Generate Report</a>
            <a href="https://github.com/your-org/monday-as-code" class="btn">🔗 View Repository</a>
        </div>

        <div class="generated-info">
            Generated by Monday as Code • <span id="generation-time"></span>
        </div>
    </div>

    <script>
        // Embedded data
        const connectionsData = $connections_data;
        const cleanupData = $cleanup_data;

        // Populate dashboard
        document.addEventListener('DOMContentLoaded', function() {
            populateStats();
            populateWorkspaces();
            populateCleanup();
            document.getElementById('generation-time').textContent = new Date().toLocaleString();
        });

        function populateStats() {
            const stats = [
                {
                    number: connectionsData.connections.length,
                    label: 'Total Boards'
                },
                {
                    number: connectionsData.connections.filter(b => b.connection_count > 0).length,
                    label: 'Connected Boards'
                },
                {
                    number: connectionsData.connections.filter(b => b.connection_count === 0).length,
                    label: 'Orphaned Boards'
                },
                {
                    number: connectionsData.deprecated_boards.length,
                    label: 'Deprecated Boards'
                }
            ];

            const statsGrid = document.getElementById('stats-grid');
            statsGrid.innerHTML = stats.map(stat => \`
                <div class="stat-card">
                    <div class="stat-number">\${stat.number}</div>
                    <div class="stat-label">\${stat.label}</div>
                </div>
            \`).join('');
        }

        function populateWorkspaces() {
            const workspaces = ['lab', 'production', 'crm'];
            const workspaceGrid = document.getElementById('workspace-grid');
            
            workspaceGrid.innerHTML = workspaces.map(workspace => {
                const boards = connectionsData.connections.filter(b => b.workspace === workspace);
                const connected = boards.filter(b => b.connection_count > 0);
                const orphaned = boards.filter(b => b.connection_count === 0);
                const deprecated = boards.filter(b => b.is_deprecated);
                
                return \`
                    <div class="workspace-card \${workspace}">
                        <h3>\${workspace.toUpperCase()} Workspace</h3>
                        <div>📋 Total: \${boards.length} boards</div>
                        <div>🔗 Connected: \${connected.length}</div>
                        <div>🔍 Orphaned: \${orphaned.length}</div>
                        <div>⚠️ Deprecated: \${deprecated.length}</div>
                        
                        <div class="board-list">
                            \${boards.map(board => \`
                                <div class="board-item \${board.is_deprecated ? 'deprecated' : board.connection_count > 0 ? 'connected' : 'orphaned'}">
                                    \${board.board_name} (\${board.connection_count} connections)
                                </div>
                            \`).join('')}
                        </div>
                    </div>
                \`;
            }).join('');
        }

        function populateCleanup() {
            const cleanupSection = document.getElementById('cleanup-section');
            const categories = [
                {
                    name: 'Deprecated Boards',
                    class: 'deprecated',
                    boards: cleanupData.cleanup_plan.cleanup_categories.deprecated_boards.boards,
                    description: 'Explicitly marked as deprecated - safe to archive immediately'
                },
                {
                    name: 'Orphaned Boards',
                    class: 'orphaned',
                    boards: cleanupData.cleanup_plan.cleanup_categories.orphaned_boards.boards,
                    description: 'No connections to other boards - review before archiving'
                },
                {
                    name: 'Test/Demo Boards',
                    class: 'test',
                    boards: cleanupData.cleanup_plan.cleanup_categories.test_boards.boards,
                    description: 'Appear to be test or demo boards - usually safe to archive'
                }
            ];

            cleanupSection.innerHTML = categories.map(category => \`
                <div class="cleanup-category \${category.class}">
                    <div class="board-count">\${category.name}: \${category.boards.length}</div>
                    <p>\${category.description}</p>
                    <div class="board-list">
                        \${category.boards.map(board => \`
                            <div class="board-item">
                                \${board.board_name} (\${board.workspace})
                            </div>
                        \`).join('')}
                    </div>
                </div>
            \`).join('');
        }

        function downloadMermaid() {
            // Generate a simple Mermaid diagram
            const mermaid = \`graph TD
    A[Total Boards: \${connectionsData.connections.length}] --> B[Connected: \${connectionsData.connections.filter(b => b.connection_count > 0).length}]
    A --> C[Orphaned: \${connectionsData.connections.filter(b => b.connection_count === 0).length}]
    A --> D[Deprecated: \${connectionsData.deprecated_boards.length}]
    
    classDef connected fill:#d4edda,stroke:#28a745
    classDef orphaned fill:#fff3cd,stroke:#ffc107
    classDef deprecated fill:#f8d7da,stroke:#dc3545
    
    class B connected
    class C orphaned
    class D deprecated\`;
            
            const blob = new Blob([mermaid], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'monday-connections.mmd';
            a.click();
            URL.revokeObjectURL(url);
        }

        function generateReport() {
            alert('Report generation would create a detailed PDF/HTML report with recommendations. This is a placeholder for the full implementation.');
        }
    </script>
</body>
</html>
EOF
  
  echo -e "${GREEN}✅ Interactive HTML dashboard: $output_file${NC}"
  echo ""
  echo "Open in browser: file://$output_file"
}

# Generate all visualization formats
generate_all_formats() {
  echo -e "${BOLD}🎨 Generating all visualization formats...${NC}"
  echo ""
  
  # Generate workspace overviews
  generate_workspace_overview "mermaid"
  generate_workspace_overview "html"
  
  # Generate detailed flows
  generate_detailed_flow "mermaid" ""
  generate_detailed_flow "mermaid" "lab"
  generate_detailed_flow "mermaid" "crm"
  
  # Generate cleanup visualizations
  generate_cleanup_visualization "mermaid" "true"
  
  # Generate CRM flows
  generate_crm_flow "mermaid"
  
  # Generate interactive dashboard
  generate_interactive_html
  
  echo ""
  echo -e "${GREEN}✅ All visualizations generated!${NC}"
  echo ""
  echo "📁 Generated files:"
  find "$PROJECT_ROOT/visualizations" -type f -name "*.*" | sort | while read -r file; do
    echo "  $(basename "$file")"
  done
}

# Main command dispatcher
main() {
  if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
  fi

  local command=""
  local format="mermaid"
  local workspace=""
  local include_orphans=false
  local highlight_issues=false
  local export_path=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      workspace-overview|detailed-flow|cleanup-candidates|crm-flow|interactive-html|all-formats)
        command="$1"
        shift
        ;;
      --format)
        format="$2"
        shift 2
        ;;
      --workspace)
        workspace="$2"
        shift 2
        ;;
      --include-orphans)
        include_orphans=true
        shift
        ;;
      --highlight-issues)
        highlight_issues=true
        shift
        ;;
      --export-path)
        export_path="$2"
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

  if [[ -z "$command" ]]; then
    echo -e "${RED}❌ No command specified${NC}"
    show_usage
    exit 1
  fi

  echo -e "${BOLD}🎨 Monday.com Connection Visualizer${NC}"
  echo "Command: $command"
  echo "Format: $format"
  if [[ -n "$workspace" ]]; then
    echo "Workspace: $workspace"
  fi
  echo ""

  check_prerequisites

  case "$command" in
    workspace-overview)
      generate_workspace_overview "$format"
      ;;
    detailed-flow)
      generate_detailed_flow "$format" "$workspace"
      ;;
    cleanup-candidates)
      generate_cleanup_visualization "$format" "$highlight_issues"
      ;;
    crm-flow)
      generate_crm_flow "$format"
      ;;
    interactive-html)
      generate_interactive_html
      ;;
    all-formats)
      generate_all_formats
      ;;
    *)
      echo -e "${RED}❌ Unknown command: $command${NC}"
      show_usage
      exit 1
      ;;
  esac
}

main "$@"
