#!/bin/bash
# generate-workspace-docs.sh - Generate workspace documentation

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check for API token
if [[ -z "$MONDAY_API_TOKEN" ]]; then
  echo "❌ MONDAY_API_TOKEN environment variable not set!"
  echo "Please run: export MONDAY_API_TOKEN='your_token_here'"
  exit 1
fi

echo -e "${BLUE}📚 Generating workspace documentation...${NC}"

# Create docs directory
mkdir -p docs

# Get workspace data
echo "🔍 Fetching workspace information..."

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

# Create workspace documentation
cat > docs/workspaces.md << 'EOF'
# Monday.com Workspaces

This document lists all Monday.com workspaces in the organization, categorized by their current status.

## Active Workspaces

These workspaces are currently in use and should be maintained.

EOF

# Add active workspaces (assuming all are active for now)
echo "$RESPONSE" | jq -r '.data.workspaces[] | "### \(.name)\n- **ID:** `\(.id)`\n- **Description:** \(.description // "*No description provided*")\n- **Status:** 🟢 Active\n"' >> docs/workspaces.md

cat >> docs/workspaces.md << 'EOF'

## Inactive Workspaces

These workspaces are no longer in active use but are preserved for historical reference.

*No inactive workspaces identified yet. As workspaces become obsolete, they will be moved to this section.*

## Workspace Categories

Based on the workspace names, here are the main functional categories:

### 🛒 **Purchasing & Sourcing**
- VRM - Purchasing (ID: 11346231)
- Purchasing (ID: 11143550) 
- Purchasing (ID: 2091930)
- Purchasing & Sourcing (ID: 10400340)

### 💰 **Sales & CRM**
- CRM (ID: 11007618)
- CRM - template (ID: 11140574)
- Wholesale + Sales (ID: 2290519)

### 🏭 **Production & Operations**
- Production 2025 (ID: 10142622)
- SKU System (ID: 10534354)
- Suppliers (ID: 10534346)
- Boxes and Label sizes (ID: 11074101)

### 💼 **Finance & Admin**
- Finance (ID: 11040870)
- Main workspace (ID: 5556910)

### 🧪 **Lab & Development**
- Lab (ID: 9736208) - *Recommended for testing Monday as Code*
- Pure Earth Labs (ID: 2265854)

### 📈 **Marketing & PR**
- Marketing (ID: 519088)
- PR Projects (ID: 5453778)
- Earth Harbor (ID: 10564429)

### 📚 **Resources & Training**
- Role Guides & Responsibilities (ID: 8586060)
- Department Resources (ID: 1416756)
- Useful Templates 🧠 (ID: 10506763)
- Fulfillment: Training, Tasks, Info & Etc (ID: 1746990)

### 🎯 **Project Management**
- Project Management (ID: 686563)
- Completed Tasks (ID: 8728181)

### 👤 **Personal/Individual**
- Monse - Workspace (ID: 10099506)

## Recommended Test Workspace

For Monday as Code testing and development:

**Lab Workspace**
- **ID:** `9736208`
- **Name:** Lab
- **Usage:** Perfect for testing new boards, automations, and Monday as Code deployments

To use this workspace for testing:
```bash
export WORKSPACE_ID="9736208"
```

## Notes

- All workspaces are currently marked as active
- Workspace categorization is based on naming patterns
- Some workspaces may have overlapping purposes
- Consider consolidating similar workspaces to reduce complexity

---
*Generated automatically by Monday as Code - `generate-workspace-docs.sh`*
*Last updated: $(date)*
EOF

echo -e "${GREEN}✅ Documentation generated: docs/workspaces.md${NC}"
echo ""
echo "📖 Review the categorization and update as needed:"
echo "   - Mark workspaces as inactive if they're no longer used"
echo "   - Update descriptions for better clarity"
echo "   - Adjust categories based on actual usage"
echo ""
echo -e "${BLUE}🎯 Ready to test with Lab workspace:${NC}"
echo "export WORKSPACE_ID=\"9736208\""
