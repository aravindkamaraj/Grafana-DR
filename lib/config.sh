#!/usr/bin/env bash

###############################################################################
# Grafana-DR Configuration
###############################################################################

#######################################
# Grafana Configuration
#######################################

GRAFANA_URL="http://localhost:3000"

TOKEN_FILE="$HOME/.config/grafana-dr/token"

#######################################
# Repository Paths
#######################################

: "${PROJECT_ROOT:?PROJECT_ROOT is not set}"

DASHBOARD_DIR="${PROJECT_ROOT}/dashboards"

LOG_DIR="${PROJECT_ROOT}/logs"

DOCS_DIR="${PROJECT_ROOT}/docs"

#######################################
# Log File
#######################################

LOG_FILE="${LOG_DIR}/grafana-dr.log"

#######################################
# API Configuration
#######################################

API_TIMEOUT=30

API_RETRIES=3

API_MAX_TIME=60
#######################################
# Script Version
#######################################

VERSION="1.0.0"
