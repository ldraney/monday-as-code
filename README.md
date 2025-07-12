# Monday as Code 🚀

> Infrastructure as Code for Monday.com - The first open-source tool to manage Monday.com workspaces, boards, and resources programmatically

## 🎯 **Project Vision**

Monday as Code brings the power of Infrastructure as Code (IaC) to Monday.com, similar to how Terraform manages cloud infrastructure. This allows teams to:

- **Version control** their Monday.com workspace configurations
- **Automate** board creation and management through CI/CD pipelines  
- **Standardize** Monday.com setups across environments (dev/staging/production)
- **Scale** Monday.com management for enterprise teams with dozens of workspaces
- **Collaborate** on Monday.com changes through pull requests and code reviews

**Market Opportunity**: No existing "Monday.com as Code" product exists - this could become the Terraform for Monday.com.

## ✅ **Current Status - What's Working**

### **Milestone 1: Basic Board Creation** ✅ COMPLETE
- [x] GraphQL API integration with pure bash/curl (no Node.js required)
- [x] Environment variable configuration (`MONDAY_API_TOKEN`, `WORKSPACE_ID`)
- [x] Simple board creation script that works end-to-end
- [x] Idempotent behavior (running twice doesn't break anything)
- [x] Error handling and validation
- [x] API connection testing
- [x] Workspace discovery script

### **Successfully Tested**
- ✅ API connection to Monday.com
- ✅ Workspace ID discovery (`./get-workspace-id.sh`)
- ✅ Board creation in Lab workspace (ID: 9736208)
- ✅ Idempotent operations (board already exists = skip creation)
- ✅ GraphQL type handling (ID vs Int types)

## 📁 **Current Repository Structure**

```
ldraney/monday-as-code/
├── README.md                 # This file
├── get-workspace-id.sh      # Script to discover workspace IDs
├── simple-create-board.sh   # Working board creation script
└── setup.sh                 # One-click repo setup (already run)
```

## 🧪 **How to Test Current System**

```bash
# 1. Set your API token
export MONDAY_API_TOKEN='your_token_here'

# 2. Find workspace ID (if needed)
./get-workspace-id.sh

# 3. Set workspace ID (Lab = 9736208)
export WORKSPACE_ID='9736208'

# 4. Create a board
./simple-create-board.sh
```

**Expected Output:**
```
🚀 Creating Monday.com board via API...
✅ Connected as: Lucas Draney
📋 Board doesn't exist yet, will create it
🎉 Board created successfully!
Board ID: [new_board_id]
✅ Success! Your first Monday.com board created via code!
```

## 🎯 **End Goal Architecture**

The ultimate vision is a Terraform-like system with:

```bash
# Terraform-style commands
./scripts/deploy.sh plan --env lab        # Preview changes
./scripts/deploy.sh apply --env lab       # Deploy resources
./scripts/deploy.sh destroy --env lab     # Clean up resources

# Resource definitions (JSON-based)
resources/
├── boards/
│   ├── tasks-board.json        # Task management board
│   └── tickets-board.json      # Project tickets board
└── views/                      # Future: board views
    └─ kanban-view.json

# Environment configurations  
configs/
├── lab.env                     # Lab workspace settings
├── staging.env                 # Staging workspace
└── production.env              # Production workspace

# GitHub Actions automation
.github/workflows/deploy.yml    # Auto-deploy on PR merge
```

### **Target Resource Definition Format**
```json
{
  "resource_type": "board",
  "name": "tasks-board", 
  "spec": {
    "board_name": "Development Tasks",
    "board_kind": "public",
    "description": "Track development work and bugs",
    "workspace_id": "${WORKSPACE_ID}",
    "columns": [
      {
        "title": "Task Name",
        "type": "name"
      },
      {
        "title": "Status",
        "type": "status", 
        "settings": {
          "labels": {
            "1": "Not Started",
            "2": "In Progress",
            "3": "Done"
          }
        }
      },
      {
        "title": "Priority",
        "type": "priority"
      }
    ]
  }
}
```

## 🚀 **Recommended Next Steps**

Based on our successful foundation, the best next step is:

### **Milestone 2: Add Columns to Boards**
Extend our working board creation script to also create columns with different types:

1. **Enhance `simple-create-board.sh`** to add columns after board creation
2. **Test column types**: status, priority, date, people, text, file
3. **Handle column settings** (status labels, etc.)
4. **Validate column creation works** end-to-end

**Why this next?**
- Builds directly on our working foundation
- Columns are essential for useful boards
- Tests more complex GraphQL mutations
- Validates Monday.com API column handling
- Still keeps everything in one simple script (avoid complexity)

### **Alternative Next Steps** (lower priority):
- **JSON Resource Definitions**: Move hardcoded values to JSON files
- **Environment Config Files**: Replace env vars with config files  
- **Plan/Apply Pattern**: Add Terraform-like plan/apply commands
- **GitHub Actions**: Automate deployment pipeline

## 🧰 **Technical Foundation**

### **Dependencies**
- `curl` - HTTP requests to Monday.com API
- `jq` - JSON parsing and manipulation
- `bash` - Shell scripting (no Node.js required!)

### **API Integration**
- **Endpoint**: `https://api.monday.com/v2`
- **Protocol**: GraphQL over HTTP POST
- **Authentication**: Bearer token in Authorization header
- **API Version**: `2023-10` (specified in headers)

### **Key Learnings**
- Monday.com uses `ID!` type for workspace_id (not `Int!`)
- GraphQL variables must match exact type expectations
- Board creation returns board ID for further operations
- API naturally handles "state" - duplicate boards return errors
- Idempotent operations are achievable with existence checks

## 🔥 **Why This Matters**

Monday as Code could become a significant open-source project because:

1. **No competition**: No existing "Monday.com as Code" tools
2. **Large market**: 180k+ teams use Monday.com globally  
3. **Enterprise need**: Large organizations struggle with Monday.com consistency
4. **DevOps trend**: Everything-as-Code is the industry direction
5. **Extensible**: Can grow to manage views, automations, integrations

## 📞 **Current Status Summary**

**✅ What's proven to work:**
- Basic Monday.com API integration
- Board creation via GraphQL
- Environment variable configuration
- Error handling and validation

**🎯 Ready for next iteration:**
- Script foundation is solid
- API patterns are established  
- Lab workspace is configured
- Development workflow is proven

**🚀 Best next step:** Extend board creation to include columns, building on our working foundation while keeping everything simple and testable.
