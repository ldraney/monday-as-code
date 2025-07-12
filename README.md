# Monday as Code

Infrastructure as Code for Monday.com

## Quick Test

1. Set your API token:
   ```bash
   export MONDAY_API_TOKEN='your_token_here'
   ```

2. Find your workspace ID:
   ```bash
   ./get-workspace-id.sh
   ```

3. Set your workspace ID:
   ```bash
   export WORKSPACE_ID='your_workspace_id'
   ```

4. Create your first board:
   ```bash
   ./simple-create-board.sh
   ```

## Requirements

- `curl` (for API calls)
- `jq` (for JSON parsing)

Install jq on macOS: `brew install jq`
Install jq on Ubuntu: `sudo apt-get install jq`
