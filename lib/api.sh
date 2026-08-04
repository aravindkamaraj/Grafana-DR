#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# Generic HTTP API Library
#
# This library contains generic HTTP helper functions.
# It does NOT know anything about Grafana dashboards.
###############################################################################

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

###############################################################################
# Generic HTTP Request
#
# Usage:
# api_request METHOD ENDPOINT [DATA_FILE]
#
# Example:
# api_request GET "/api/search"
# api_request POST "/api/dashboards/db" dashboard.json
###############################################################################

api_request() {

    local METHOD="$1"
    local ENDPOINT="$2"
    local DATA_FILE="${3:-}"

    local CURL_ARGS=(
        --silent
        --show-error
        --fail
        --retry "$API_RETRIES"
        --connect-timeout "$API_TIMEOUT"
        -X "$METHOD"
        -H "Authorization: Bearer $TOKEN"
    )

    if [[ "$METHOD" != "GET" ]]; then
        CURL_ARGS+=(
            -H "Content-Type: application/json"
        )
    fi

    if [[ -n "$DATA_FILE" ]]; then
        CURL_ARGS+=(
            --data @"$DATA_FILE"
        )
    fi

    curl "${CURL_ARGS[@]}" \
        "${GRAFANA_URL}${ENDPOINT}"
}

###############################################################################
# HTTP GET
###############################################################################

api_get() {

    local ENDPOINT="$1"

    api_request "GET" "$ENDPOINT"

}

###############################################################################
# HTTP POST
###############################################################################

api_post() {

    local ENDPOINT="$1"
    local DATA_FILE="$2"

    api_request "POST" "$ENDPOINT" "$DATA_FILE"

}

###############################################################################
# HTTP PUT
###############################################################################

api_put() {

    local ENDPOINT="$1"
    local DATA_FILE="$2"

    api_request "PUT" "$ENDPOINT" "$DATA_FILE"

}


###############################################################################
# HTTP DELETE
###############################################################################

api_delete() {

    local ENDPOINT="$1"

    api_request "DELETE" "$ENDPOINT"

}

###############################################################################
# Verify Grafana API is reachable
###############################################################################

api_health() {

    api_get "/api/health" >/dev/null

}

###############################################################################
# Return Grafana version
###############################################################################

api_version() {

    api_get "/api/health" \
        | jq -r '.version'

}
