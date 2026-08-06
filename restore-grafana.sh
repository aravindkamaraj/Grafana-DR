#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# Restore Entry Point
#
# Restores Grafana dashboards from the latest backup.
###############################################################################

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/bootstrap.sh"
source "${PROJECT_ROOT}/services/restore_service.sh"

###############################################################################
# Main
###############################################################################

main() {

    initialize

    restore_dashboards

}

main "$@"