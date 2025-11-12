#!/bin/bash
set -euo pipefail

GRAFANA_URL="${1:-}"
API_KEY="${2:-}"

if [ -z "$GRAFANA_URL" ] || [ -z "$API_KEY" ]; then
    echo "usage: $0 <grafana-url> <api-key>"
    echo ""
    echo "example:"
    echo "  $0 http://localhost:3000 eyJrIjoiYWJjZGVm..."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "verifying dashboards at $GRAFANA_URL"
echo ""

check_grafana_health() {
    echo "checking grafana health..."
    response=$(curl -s -w "\n%{http_code}" "$GRAFANA_URL/api/health")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" -eq 200 ]; then
        echo "  ✓ grafana is healthy"
        return 0
    else
        echo "  ✗ grafana health check failed (http $http_code)"
        echo "$body"
        return 1
    fi
}

check_datasource() {
    echo ""
    echo "checking prometheus datasource..."
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $API_KEY" \
        "$GRAFANA_URL/api/datasources")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" -eq 200 ]; then
        prometheus_count=$(echo "$body" | jq '[.[] | select(.type=="prometheus")] | length')
        if [ "$prometheus_count" -gt 0 ]; then
            echo "  ✓ found $prometheus_count prometheus datasource(s)"
            echo "$body" | jq -r '.[] | select(.type=="prometheus") | "    - \(.name) (\(.url))"'
            return 0
        else
            echo "  ✗ no prometheus datasource found"
            return 1
        fi
    else
        echo "  ✗ failed to check datasources (http $http_code)"
        return 1
    fi
}

validate_dashboard_json() {
    local dashboard_file="$1"
    local dashboard_name=$(basename "$dashboard_file" .json)

    echo ""
    echo "validating $dashboard_name..."

    if ! jq empty "$dashboard_file" 2>/dev/null; then
        echo "  ✗ invalid json"
        return 1
    fi

    if ! jq -e '.panels' "$dashboard_file" >/dev/null 2>&1; then
        echo "  ✗ missing panels"
        return 1
    fi

    panel_count=$(jq '.panels | length' "$dashboard_file")
    echo "  ✓ valid json with $panel_count panels"

    target_count=$(jq '[.panels[].targets[]? | select(.expr)] | length' "$dashboard_file")
    if [ "$target_count" -gt 0 ]; then
        echo "  ✓ found $target_count prometheus queries"
    else
        echo "  ⚠ no prometheus queries found"
    fi

    return 0
}

check_dashboard_exists() {
    local dashboard_uid="$1"
    local dashboard_name="$2"

    echo ""
    echo "checking if $dashboard_name exists in grafana..."
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $API_KEY" \
        "$GRAFANA_URL/api/dashboards/uid/$dashboard_uid")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" -eq 200 ]; then
        echo "  ✓ dashboard exists"
        dashboard_url=$(echo "$body" | jq -r '.meta.url')
        echo "    url: $GRAFANA_URL$dashboard_url"
        return 0
    elif [ "$http_code" -eq 404 ]; then
        echo "  ⚠ dashboard not found (not yet imported)"
        return 1
    else
        echo "  ✗ failed to check dashboard (http $http_code)"
        return 1
    fi
}

if ! check_grafana_health; then
    echo ""
    echo "grafana health check failed. exiting."
    exit 1
fi

if ! check_datasource; then
    echo ""
    echo "⚠ warning: no prometheus datasource configured"
    echo "  dashboards will not work without a prometheus datasource"
fi

echo ""
echo "validating dashboard files..."

valid_count=0
invalid_count=0

for dashboard in "$SCRIPT_DIR"/*.json; do
    if [ -f "$dashboard" ]; then
        if validate_dashboard_json "$dashboard"; then
            ((valid_count++))

            uid=$(jq -r '.uid' "$dashboard")
            name=$(jq -r '.title' "$dashboard")
            if [ "$uid" != "null" ]; then
                check_dashboard_exists "$uid" "$name" || true
            fi
        else
            ((invalid_count++))
        fi
    fi
done

echo ""
echo "validation complete"
echo "  valid: $valid_count"
echo "  invalid: $invalid_count"

if [ $invalid_count -gt 0 ]; then
    exit 1
fi
