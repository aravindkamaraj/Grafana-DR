#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# Manifest Library
#
# Creates and manages the backup manifest.
###############################################################################

MANIFEST_ITEMS=()

###############################################################################
# Initialize a new manifest.
###############################################################################

manifest_begin() {

    MANIFEST_ITEMS=()

}

###############################################################################
# Add a dashboard to the manifest.
#
# Arguments:
#   $1 - Dashboard UID
#   $2 - Dashboard Title
#   $3 - Backup Filename
#   $4 - SHA256
#   $5 - File Size
###############################################################################

manifest_add() {

    local DASHBOARD_UID="$1"
    local DASHBOARD_TITLE="$2"
    local FILE_NAME="$3"
    local SHA256="$4"
    local FILE_SIZE="$5"

    local ITEM

    ITEM=$(
        jq -n \
            --arg uid "$DASHBOARD_UID" \
            --arg title "$DASHBOARD_TITLE" \
            --arg file "$FILE_NAME" \
            --arg sha256 "$SHA256" \
            --argjson size "$FILE_SIZE" \
            '{
                uid: $uid,
                title: $title,
                file: $file,
                sha256: $sha256,
                size: $size
            }'
    )

    MANIFEST_ITEMS+=("$ITEM")

}

###############################################################################
# Write manifest.json
###############################################################################

manifest_finish() {

    local GRAFANA_VERSION
    local GENERATED_AT

    GRAFANA_VERSION=$(grafana_version)
    GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if ! printf '%s\n' "${MANIFEST_ITEMS[@]}" |
    jq -s \
        --arg generated_at "$GENERATED_AT" \
        --arg grafana_version "$GRAFANA_VERSION" \
        '{
            generated_at: $generated_at,
            grafana_version: $grafana_version,
            dashboard_count: length,
            dashboards: .
        }' > "$MANIFEST_FILE"
then
    return 1
fi

return 0
}

###############################################################################
# Validate manifest.json
###############################################################################

manifest_validate() {

    file_validate_json "$MANIFEST_FILE"

}

###############################################################################
# Read manifest.json
###############################################################################

manifest_read() {

    cat "$MANIFEST_FILE"

}
