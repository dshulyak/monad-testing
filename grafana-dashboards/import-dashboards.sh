#!/bin/bash
set -euo pipefail

GRAFANA_URL="${1:-}"
API_KEY="${2:-}"

if [ -z "$GRAFANA_URL" ] || [ -z "$API_KEY" ]; then
    echo "usage: $0 <grafana-url> <api-key>"
    echo ""
    echo "example:"
    echo "  $0 http://localhost:3000 eyJrIjoiYWJjZGVm..."
    echo ""
    echo "to create an api key in grafana:"
    echo "  1. navigate to configuration > api keys"
    echo "  2. click 'add api key'"
    echo "  3. set role to 'admin'"
    echo "  4. copy the generated key"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "importing dashboards to grafana at $GRAFANA_URL"
echo ""

import_dashboard() {
    local dashboard_file="$1"
    local dashboard_name=$(basename "$dashboard_file" .json)

    echo "importing $dashboard_name..."

    local dashboard_json=$(cat "$dashboard_file")

    local payload=$(jq -n \
        --argjson dashboard "$dashboard_json" \
        '{
            dashboard: $dashboard,
            overwrite: true,
            message: "imported via script"
        }')

    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$GRAFANA_URL/api/dashboards/db")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" -eq 200 ]; then
        dashboard_url=$(echo "$body" | jq -r '.url')
        echo "  ✓ success: $GRAFANA_URL$dashboard_url"
    else
        echo "  ✗ failed (http $http_code)"
        echo "$body" | jq '.'
        return 1
    fi
}

success_count=0
fail_count=0

for dashboard in "$SCRIPT_DIR"/*.json; do
    if [ -f "$dashboard" ]; then
        if import_dashboard "$dashboard"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo ""
    fi
done

echo "import complete"
echo "  success: $success_count"
echo "  failed: $fail_count"

if [ $fail_count -gt 0 ]; then
    exit 1
fi
