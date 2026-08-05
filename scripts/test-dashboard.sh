#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

initialize

grafana_health

echo "Grafana Version: $(grafana_version)"
echo

echo "Dashboard List:"
grafana_list_dashboards | jq .

echo

DASHBOARD_UID=$(grafana_list_dashboards | jq -r '.[0].uid')

echo "Exporting dashboard with UID: ${DASHBOARD_UID}"
echo

grafana_export_dashboard "$DASHBOARD_UID" | jq '.dashboard.title'
