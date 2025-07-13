#!/bin/bash
# Simple connection analyzer - just for Lab boards we already have

set -e
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔍 Analyzing Lab board connections..."

# Create analysis directory
mkdir -p analysis/simple

# Count total boards
TOTAL_BOARDS=$(find "$PROJECT_ROOT/modules/lab/boards" -name "*.json" | wc -l)
echo "📋 Found $TOTAL_BOARDS boards in Lab workspace"

# Find boards with connections (no API calls - just JSON analysis)
echo ""
echo "🔗 Boards with connections:"

CONNECTED=0
ORPHANED=0

for board_file in "$PROJECT_ROOT/modules/lab/boards"/*.json; do
  if [[ -f "$board_file" ]]; then
    BOARD_NAME=$(jq -r '.spec.board_name' "$board_file")
    CONNECTIONS=$(jq '[.spec.columns[]? | select(.type == "board_relation" or .type == "mirror")] | length' "$board_file")
    
    if [[ "$CONNECTIONS" -gt 0 ]]; then
      echo "  ✅ $BOARD_NAME ($CONNECTIONS connections)"
      ((CONNECTED++))
    else
      echo "  🔍 $BOARD_NAME (no connections - orphaned)"
      ((ORPHANED++))
    fi
  fi
done

echo ""
echo "📊 Summary:"
echo "  Total boards: $TOTAL_BOARDS"
echo "  Connected: $CONNECTED"
echo "  Orphaned: $ORPHANED"

# Save simple results
cat > analysis/simple/lab_analysis.json << JSONEOF
{
  "analyzed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "workspace": "lab",
  "total_boards": $TOTAL_BOARDS,
  "connected_boards": $CONNECTED,
  "orphaned_boards": $ORPHANED
}
JSONEOF

echo ""
echo "✅ Simple analysis complete! Results saved to analysis/simple/lab_analysis.json"
