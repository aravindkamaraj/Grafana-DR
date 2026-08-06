#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/bootstrap.sh"

initialize

JSON_FILE="${DASHBOARD_DIR}/host-temperature__adpj4mw.json"

grafana_import_dashboard "$JSON_FILE"
