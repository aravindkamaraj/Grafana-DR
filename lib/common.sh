#!/usr/bin/env bash

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


validate_json() {

    jq empty >/dev/null 2>&1

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


###############################################################################
# Project Initialization
###############################################################################

initialize() {

    banner

    log INFO "Checking dependencies..."
    check_dependencies

    log INFO "Ensuring project directories..."
    ensure_directories

    log INFO "Loading Grafana API token..."
    load_token

    log INFO "Initialization completed."

}
