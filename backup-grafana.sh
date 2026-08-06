#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# Backup Entry Point
#
# Creates a Grafana dashboard backup and synchronizes it to Git.
###############################################################################

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/bootstrap.sh"
source "${PROJECT_ROOT}/services/backup_service.sh"
source "${PROJECT_ROOT}/lib/git.sh"

###############################################################################
# Main
###############################################################################

main() {

    initialize

    backup_dashboards

    git_sync

}

main "$@"