#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/bootstrap.sh"
source "${PROJECT_ROOT}/services/backup_service.sh"

initialize

backup_dashboards
