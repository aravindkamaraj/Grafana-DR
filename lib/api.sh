#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# Generic HTTP API Library
#
# This library contains generic HTTP helper functions.
# It does NOT know anything about Grafana dashboards.

###############################################################################
# api_request
#
# Description:
#   Sends an HTTP request to the Grafana API.
#
# Arguments:
#   $1 - HTTP Method (GET, POST, PUT, DELETE)
#   $2 - API Endpoint
#   $3 - JSON payload file (optional)
#
# Returns:
#   Response body on stdout.
#   curl exit status.
###############################################################################

api_request() {

    local METHOD="$1"
    local ENDPOINT="$2"
    local DATA_FILE="${3:-}"

    local CURL_ARGS=()

    CURL_ARGS+=(--silent)
    CURL_ARGS+=(--show-error)
    CURL_ARGS+=(--fail)
    CURL_ARGS+=(--retry "$API_RETRIES")
    CURL_ARGS+=(--connect-timeout "$API_TIMEOUT")
    CURL_ARGS+=(--max-time "$API_MAX_TIME")
    CURL_ARGS+=(-X "$METHOD")
    CURL_ARGS+=(-H "Authorization: Bearer $TOKEN")


    if [[ "$METHOD" != "GET" ]]; then
        local CONTENT_TYPE="application/json"
	CURL_ARGS+=(-H "Content-Type: ${CONTENT_TYPE}")
    fi

    if [[ -n "$DATA_FILE" ]]; then
        CURL_ARGS+=(
            --data @"$DATA_FILE"
        )
    fi

    local URL="${GRAFANA_URL}${ENDPOINT}"

    curl "${CURL_ARGS[@]}" "$URL"

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
###############################################################################
# grafana_health
#
# Returns:
#   0 - Grafana is reachable
#   1 - Grafana is unreachable
###############################################################################

grafana_health() {

    api_get "/api/health" >/dev/null

}


###############################################################################
# Return Grafana version
###############################################################################

grafana_version() {

    api_get "/api/health" \
        | jq -r '.version'

}
