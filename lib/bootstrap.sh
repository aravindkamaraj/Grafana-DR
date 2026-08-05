#!/usr/bin/env bash

###############################################################################
# Grafana-DR Bootstrap
#
# Responsible for:
#   - Locating the project root
#   - Loading project libraries
#
# Does NOT execute application logic.
###############################################################################

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${BOOTSTRAP_DIR}/.." && pwd)"

export PROJECT_ROOT

###############################################################################
# Load Libraries
###############################################################################

source "${PROJECT_ROOT}/lib/config.sh"
source "${PROJECT_ROOT}/lib/common.sh"
source "${PROJECT_ROOT}/lib/api.sh"
source "${PROJECT_ROOT}/lib/dashboard.sh"
source "${PROJECT_ROOT}/lib/file_utils.sh"
source "${PROJECT_ROOT}/lib/manifest.sh"
