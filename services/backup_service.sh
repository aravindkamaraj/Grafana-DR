#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# Backup Service
#
# Implements the dashboard backup workflow.
###############################################################################

###############################################################################
# Backup all Grafana dashboards.
###############################################################################

backup_dashboards() {

    local DASHBOARD_LIST
    local DASHBOARD

    DASHBOARD_LIST=$(grafana_list_dashboards)

    TOTAL=$(echo "$DASHBOARD_LIST" | jq length)

    SUCCESS=0
    FAILED=0

    manifest_begin

    while read -r DASHBOARD
    do
        if _backup_dashboard "$DASHBOARD"; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done < <(echo "$DASHBOARD_LIST" | jq -c '.[]')

    if ! manifest_finish; then
       log ERROR "Failed to generate manifest."
       exit 1
    fi

    if ! manifest_validate; then
       log ERROR "Manifest validation failed."
       exit 1
    fi

    print_summary
}

###############################################################################
# Backup a single dashboard.
###############################################################################

_backup_dashboard() {

    local DASHBOARD="$1"

    local DASHBOARD_UID
    local DASHBOARD_TITLE
    local EXPORT_JSON
    local TEMP_FILE
    local FILE_NAME
    local DEST_FILE
    local RESULT
    local SHA256
    local FILE_SIZE

    DASHBOARD_UID=$(echo "$DASHBOARD" | jq -r '.uid')
    DASHBOARD_TITLE=$(echo "$DASHBOARD" | jq -r '.title')

    log INFO "Backing up dashboard: ${DASHBOARD_TITLE}"

    EXPORT_JSON=$(grafana_export_dashboard "$DASHBOARD_UID") || return 1

    TEMP_FILE=$(file_create_temp)

    printf '%s\n' "$EXPORT_JSON" > "$TEMP_FILE"

    FILE_NAME=$(file_generate_name \
        "$DASHBOARD_TITLE" \
        "$DASHBOARD_UID")

    DEST_FILE="${DASHBOARD_DIR}/${FILE_NAME}"

    file_safe_write "$TEMP_FILE" "$DEST_FILE"
    RESULT=$?

    case "$RESULT" in

        $FILE_SUCCESS)
            log INFO "Saved: ${FILE_NAME}"
            SHA256=$(file_sha256 "$DEST_FILE")
	    FILE_SIZE=$(stat -c%s "$DEST_FILE")

	    manifest_add \
    		"$DASHBOARD_UID" \
    		"$DASHBOARD_TITLE" \
    		"$FILE_NAME" \
    		"$SHA256" \
    		"$FILE_SIZE"
            return 0
            ;;

        $FILE_NO_CHANGE)
            log INFO "No changes: ${FILE_NAME}"
	    SHA256=$(file_sha256 "$DEST_FILE")
            FILE_SIZE=$(stat -c%s "$DEST_FILE")

            manifest_add \
                "$DASHBOARD_UID" \
                "$DASHBOARD_TITLE" \
                "$FILE_NAME" \
                "$SHA256" \
                "$FILE_SIZE"
            return 0
            ;;

        $FILE_INVALID_JSON)
            log ERROR "Invalid JSON received for '${DASHBOARD_TITLE}'"
            return 1
            ;;

        $FILE_TEMP_MISSING)
            log ERROR "Temporary file missing."
            return 1
            ;;

        *)
            log ERROR "Unknown file write error."
            return 1
            ;;

    esac
}
