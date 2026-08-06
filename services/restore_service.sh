#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# Restore Service
#
# Restores Grafana dashboards from backup files.
###############################################################################

###############################################################################
# Restore all dashboards from the manifest.
###############################################################################

restore_dashboards() {

    local MANIFEST
    local DASHBOARD

    if ! manifest_validate; then
        log ERROR "Invalid manifest."
        return 1
    fi

    MANIFEST=$(manifest_read)

    TOTAL=$(echo "$MANIFEST" | jq '.dashboard_count')

    SUCCESS=0
    FAILED=0

    while read -r DASHBOARD
    do
        if _restore_dashboard "$DASHBOARD"; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done < <(
        echo "$MANIFEST" |
        jq -c '.dashboards[]'
    )

    print_summary
}

###############################################################################
# Restore a single dashboard.
###############################################################################

_restore_dashboard() {

    local DASHBOARD="$1"

    local DASHBOARD_UID
    local DASHBOARD_TITLE
    local FILE_NAME
    local JSON_FILE

    DASHBOARD_UID=$(echo "$DASHBOARD" | jq -r '.uid')
    DASHBOARD_TITLE=$(echo "$DASHBOARD" | jq -r '.title')
    FILE_NAME=$(echo "$DASHBOARD" | jq -r '.file')

    JSON_FILE="${DASHBOARD_DIR}/${FILE_NAME}"

    log INFO "Restoring dashboard: ${DASHBOARD_TITLE}"

    if [[ ! -f "$JSON_FILE" ]]; then
        log ERROR "Backup file not found: ${FILE_NAME}"
        return 1
    fi

    if ! file_validate_json "$JSON_FILE"; then
        log ERROR "Invalid JSON: ${FILE_NAME}"
        return 1
    fi

    local EXPECTED_SHA
    local ACTUAL_SHA

    EXPECTED_SHA=$(echo "$DASHBOARD" | jq -r '.sha256')
    ACTUAL_SHA=$(file_sha256 "$JSON_FILE")

    if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
        log ERROR "Checksum mismatch: ${FILE_NAME}"
        return 1
    fi

    if ! grafana_import_dashboard "$JSON_FILE" >/dev/null; then
        log ERROR "Failed to restore: ${DASHBOARD_TITLE}"
        return 1
    fi

    log INFO "Restored: ${DASHBOARD_TITLE}"

    return 0
}
