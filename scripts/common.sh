#!/usr/bin/env bash

###############################################################################
# Common Library
###############################################################################

source "$(dirname "$0")/config.sh"

#######################################
# Colours
#######################################

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

#######################################
# Logging
#######################################

log() {

    local LEVEL="$1"
    shift

    local MESSAGE="$*"

    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$LOG_DIR"

    printf "[%s] [%s] %s\n" \
        "$TIMESTAMP" \
        "$LEVEL" \
        "$MESSAGE" \
        | tee -a "$LOG_FILE"
}

#######################################
# Banner
#######################################

banner() {

cat <<EOF

==========================================
        Grafana-DR Toolkit
        Version ${VERSION}
==========================================

EOF

}


require() {

    local CMD="$1"

    if ! command -v "$CMD" >/dev/null 2>&1
    then

        log ERROR "$CMD is not installed."

        exit 1

    fi

}


load_token() {

    if [[ ! -f "$TOKEN_FILE" ]]
    then

        log ERROR "Token file not found."

        exit 1

    fi

    TOKEN=$(<"$TOKEN_FILE")

}


api_get() {

    local ENDPOINT="$1"

    curl \
        --silent \
        --show-error \
        --fail \
        --retry "$API_RETRIES" \
        --connect-timeout "$API_TIMEOUT" \
        -H "Authorization: Bearer $TOKEN" \
        "${GRAFANA_URL}${ENDPOINT}"

}

validate_json() {

    jq empty >/dev/null 2>&1

}


api_post() {

    local ENDPOINT="$1"
    local JSON_FILE="$2"

    curl \
        --silent \
        --show-error \
        --fail \
        --retry "$API_RETRIES" \
        --connect-timeout "$API_TIMEOUT" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data @"$JSON_FILE" \
        "${GRAFANA_URL}${ENDPOINT}"

}


check_dependencies() {

    require curl
    require jq
    require git

}


ensure_directories() {

    mkdir -p "$DASHBOARD_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DOCS_DIR"

}

check_grafana() {

    if ! api_get "/api/health" >/dev/null
    then
        log ERROR "Unable to connect to Grafana."

        exit 2
    fi

}

print_summary() {

    echo
    echo "===================================="
    echo "Grafana-DR Summary"
    echo "===================================="
    echo "Dashboards Processed : $TOTAL"
    echo "Successful           : $SUCCESS"
    echo "Failed               : $FAILED"
    echo
}
