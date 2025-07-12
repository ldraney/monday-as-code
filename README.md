# Monday as Code 🚀

> Infrastructure as Code for Monday.com - The first open-source tool to manage Monday.com workspaces, boards, and resources programmatically

## 🎯 **Project Vision**

Monday as Code brings the power of Infrastructure as Code (IaC) to Monday.com, similar to how Terraform manages cloud infrastructure. This allows teams to:

- **Version control** their Monday.com workspace configurations
- **Standardize** Monday.com setups across environments (dev/staging/production)
- **Scale** Monday.com management for enterprise teams with dozens of workspaces
- **Collaborate** on Monday.com changes through code reviews
- **Deploy connected board ecosystems** for complete project workflows

**Market Opportunity**: No existing "Monday.com as Code" product exists - this could become the Terraform for Monday.com.

## ✅ **Current Status - Milestone 3 Complete**

### **Working Infrastructure as Code System** ✅
- [x] Declarative JSON board definitions with environment variable support
- [x] Environment separation (`configs/lab.env`, `configs/production.env`)
- [x] Terraform-like `plan/apply/destroy` commands
- [x] Reusable Monday.com API library (`scripts/monday-api.sh`)
- [x] Comprehensive deploy script (`scripts/deploy.sh`)
- [x] Idempotent operations (running twice is safe)
- [x] Error handling and validation
- [x] Deployment logging
- [x] Successfully tested with "Development Tasks" board

### **Live Production Results** ✅
```bash
$ ./scripts/deploy.sh plan --env lab
✅ Connected as: Lucas Draney
📋 Existing boards: Development Tasks (+ 30 others)
📝 UPDATE Board 'Development Tasks' (resource: dev-tasks)
💡 Run 'apply' to make these changes

$ ./scripts/deploy.sh apply --env lab
✅ All columns already exist and were skipped (idempotent)
🎉 Deployment completed successfully
```

## 📁 **Repository Structure**

```
ldraney/monday-as-code/
├── README.md                    # This file
├── get-workspace-id.sh         # Script to discover workspace IDs
├── simple-create-board.sh      # Legacy board creation (kept for reference)
├── generate-workspace-docs.sh  # Generate workspace documentation
├── setup.sh                    # One-click repo setup
│
├── configs/                    # Environment configurations
│   ├── lab.env                 # Lab workspace settings
│   └── production.env          # Production workspace settings
│
├── resources/boards/           # JSON board definitions
│   ├── dev-tasks.json          # Development tasks board
│   ├── bug-tracker.json        # Bug tracking board
│   ├── project-planning.json   # Project planning board
│   ├── sales-pipeline.json     # Sales CRM board
│   └── content-calendar.json   # Content marketing board
│
├── scripts/                    # Deployment scripts
│   ├── monday-api.sh           # Monday.com API library functions
│   └── deploy.sh               # Main deployment script (Terraform-like)
│
├── logs/                       # Deployment logs (auto-generated)
│   └── deploy-YYYYMMDD.log     # Daily deployment logs
│
└── docs/
    └── workspaces.md           # Generated workspace documentation
```

## 🚀 **How to Use Monday as Code**

### **Quick Start**

```bash
# 1. Set your API token
export MONDAY_API_TOKEN='your_token_here'

# 2. Preview changes (read-only, safe)
./scripts/deploy.sh plan --env lab

# 3. Deploy resources
./scripts/deploy.sh apply --env lab

# 4. Test idempotency (should skip existing)
./scripts/deploy.sh apply --env lab
```

### **Adding New Boards**

Create JSON files in `resources/boards/`:

```json
{
  "resource_type": "board",
  "name": "my-board",
  "spec": {
    "board_name": "My Board",
    "board_kind": "public",
    "description": "Board description",
    "workspace_id": "${WORKSPACE_ID}",
    "columns": [
      {"title": "Task", "type": "name"},
      {"title": "Status", "type": "status"},
      {"title": "Due Date", "type": "date"},
      {"title": "Assignee", "type": "people"}
    ]
  }
}
```

### **Environment Management**

```bash
# Lab environment (testing)
./scripts/deploy.sh plan --env lab
./scripts/deploy.sh apply --env lab

# Production environment (with confirmations)
./scripts/deploy.sh plan --env production
./scripts/deploy.sh apply --env production
```

## 🎯 **Current Focus - Milestone 4**

### **Connected Board Ecosystems** ⭐ **NEXT PRIORITY**

Building systems of interconnected boards that work together:

1. **Multi-Board Deployments** - Deploy complete project workflows
2. **Board Dependencies** - Define relationships between boards
3. **Cross-Board Automation** - Connect boards with automations
4. **Workspace Templates** - Pre-configured workspace setups
5. **Board Collections** - Organize related boards together

**Why this next?**
- Creates complete project management ecosystems
- Demonstrates enterprise-scale Monday.com management
- Enables complex workflow automation
- Shows the true power of Infrastructure as Code for Monday.com

### **Target Connected Board System**
```bash
# Deploy an entire project management ecosystem
./scripts/deploy.sh apply --env lab --collection project-management

# This creates:
# - Project Planning board (high-level strategy)
# - Development Tasks board (detailed execution)
# - Bug Tracker board (issue management)
# - Sprint Planning board (agile workflows)
# - All connected with automations and dependencies
```

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
Based on successful production testing:
- `name` - Default name column (auto-created)
- `status` - Status/Priority columns
- `date` - Date picker columns
- `people` - People assignment columns  
- `numbers` - Numeric value columns
- `tags` - Tag selection columns
- `long_text` - Text area columns

## 🔥 **Why This Matters**

Monday as Code is becoming a significant open-source project because:

1. **✅ No competition**: First "Monday.com as Code" tool
2. **✅ Large market**: 180k+ teams use Monday.com globally  
3. **✅ Enterprise need**: Large organizations struggle with Monday.com consistency
4. **✅ DevOps trend**: Everything-as-Code is the industry direction
5. **✅ Proven foundation**: Complete API integration and deployment system working
6. **✅ Extensible**: Ready to grow to manage views, automations, integrations

## 📞 **Current Status Summary**

**✅ What's working perfectly:**
- Complete Infrastructure as Code system for Monday.com
- JSON resource definitions with environment variables
- Terraform-like plan/apply workflow
- Environment separation (lab/production)
- Idempotent deployments
- All major column types working in production
- Error handling and validation
- Deployment logging

**🎯 Ready for next iteration:**
- Core IaC platform is rock solid  
- JSON-based resource management proven
- Lab environment fully tested and operational
- Production environment configured and ready
- Development workflow established

**🚀 Next milestone:** Connected board ecosystems and multi-board deployments, completing the vision of full workspace automation through Infrastructure as Code.

---

*Monday as Code - Making Monday.com workspace management as powerful as `terraform apply`* 🚀
