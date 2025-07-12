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

### **Milestone 2: Column Creation** ✅ COMPLETE
- [x] Enhanced board creation script with column support
- [x] 7 different column types: status, priority, date, people, numbers, tags, text
- [x] Smart duplicate detection (skips existing columns)
- [x] Proper Monday.com API type mapping
- [x] Individual column error handling
- [x] Idempotent column operations
- [x] Real-world testing with Lab workspace

### **Successfully Tested**
- ✅ API connection to Monday.com
- ✅ Workspace ID discovery (`./get-workspace-id.sh`)
- ✅ Board creation in Lab workspace (ID: 9736208)
- ✅ Column creation with all major types
- ✅ Idempotent operations (board + columns already exist = skip creation)
- ✅ GraphQL type handling (ID vs Int types)
- ✅ Error handling for invalid column types

### **Live Test Results** (Board ID: 9576159441)
```
✅ Created 'Status' column (ID: color_mksss7dw)
✅ Created 'Priority' column (ID: color_mkssmegx) 
✅ Created 'Due Date' column (ID: date_mkssxc26)
✅ Created 'Assignee' column (ID: multiple_person_mkssvk5m)
✅ Created 'Progress' column (ID: numeric_mkss3jem)
✅ Created 'Tags' column (ID: tag_mksstzej)
✅ Created 'Notes' column (ID: long_text_mkssxp01)
```

## 📁 **Current Repository Structure**

```
ldraney/monday-as-code/
├── README.md                 # This file
├── get-workspace-id.sh      # Script to discover workspace IDs
├── simple-create-board.sh   # Enhanced board + column creation script
├── generate-workspace-docs.sh # Generate workspace documentation
├── setup.sh                 # One-click repo setup (already run)
├── docs/
│   └── workspaces.md        # Generated workspace documentation
├── resources/boards/        # (Empty - for future JSON definitions)
├── scripts/                 # (Empty - for future deploy scripts)
└── configs/                 # (Empty - for future env configs)
```

## 🧪 **How to Test Current System**

```bash
# 1. Set your API token
export MONDAY_API_TOKEN='your_token_here'

# 2. Find workspace ID (if needed)
./get-workspace-id.sh

# 3. Set workspace ID (Lab = 9736208)
export WORKSPACE_ID='9736208'

# 4. Create a board with columns
./simple-create-board.sh
```

**Expected Output:**
```
🚀 Creating Monday.com board with columns via API...
✅ Connected as: Lucas Draney
✅ Board already exists with ID: 9576159441
✅ Created 'Priority' column (ID: color_mkssmegx)
✅ Created 'Due Date' column (ID: date_mkssxc26)
... (creates all missing columns)
🎉 Success! Board with columns created/updated!
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
│   ├── dev-tasks.json          # Development task board
│   ├── project-tickets.json    # Project tickets board
│   └── team-planning.json      # Sprint planning board
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
  "name": "dev-tasks", 
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
        "type": "status"
      },
      {
        "title": "Priority", 
        "type": "status"
      },
      {
        "title": "Due Date",
        "type": "date"
      },
      {
        "title": "Assignee",
        "type": "people"
      },
      {
        "title": "Progress",
        "type": "numbers"
      }
    ]
  }
}
```

## 🚀 **Recommended Next Steps**

Based on our successful board and column creation, the best next step is:

### **Milestone 3: JSON Resource Definitions** ⭐ **RECOMMENDED**
Move from hardcoded scripts to declarative JSON configuration files:

1. **Design JSON schema** for board definitions
2. **Create `scripts/deploy.sh`** that reads JSON files and uses our proven API calls
3. **Add environment config files** (`configs/lab.env`, etc.)
4. **Implement plan/apply pattern** (preview changes, then deploy)
5. **Test with multiple board types** using different JSON definitions

**Why this next?**
- Natural progression from hardcoded → declarative
- Brings us to the core "Terraform for Monday.com" experience
- Enables version control of Monday.com configurations
- Sets foundation for CI/CD automation
- Validates our API foundation scales to multiple resources

### **Alternative Next Steps** (lower priority):
- **Column Settings API**: Configure Status/Priority labels programmatically
- **GitHub Actions**: Automate deployment pipeline  
- **Multiple Board Templates**: Create different board types (tasks, tickets, projects)
- **Board Views**: Add support for managing board views

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

### **Proven Column Types**
Based on successful testing, these Monday.com column types work:
- `status` - Status/Priority columns (customize labels in UI)
- `date` - Date picker columns
- `people` - People assignment columns  
- `numbers` - Numeric value columns
- `tags` - Tag selection columns
- `long_text` - Text area columns

### **Key Learnings**
- Monday.com uses `ID!` type for workspace_id (not `Int!`)
- Priority columns use `status` type, not `priority` type
- Text columns should use `long_text` type in API
- GraphQL variables must match exact type expectations
- Board creation returns board ID for further operations
- API naturally handles "state" - duplicate boards/columns return errors
- Idempotent operations are achievable with existence checks
- Column settings are best configured in UI after API creation

## 🔥 **Why This Matters**

Monday as Code could become a significant open-source project because:

1. **No competition**: No existing "Monday.com as Code" tools
2. **Large market**: 180k+ teams use Monday.com globally  
3. **Enterprise need**: Large organizations struggle with Monday.com consistency
4. **DevOps trend**: Everything-as-Code is the industry direction
5. **Proven foundation**: We've validated the core API integration works
6. **Extensible**: Can grow to manage views, automations, integrations

## 📞 **Current Status Summary**

**✅ What's proven to work:**
- Complete Monday.com API integration (boards + columns)
- All major column types working in production
- Idempotent operations for both boards and columns
- Error handling and validation
- Environment variable configuration

**🎯 Ready for next iteration:**
- API foundation is rock solid  
- Column creation pipeline proven
- Lab workspace configured and tested
- Development workflow established

**🚀 Best next step:** Create JSON resource definitions and deploy script, moving from hardcoded scripts to declarative Infrastructure as Code - the core vision of "Terraform for Monday.com."
