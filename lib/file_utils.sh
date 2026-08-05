#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# File Utility Library
#
# Generic filesystem helper functions.
# This library contains no Grafana-specific logic.
###############################################################################

file_create_temp() {

    mktemp "${TMPDIR:-/tmp}/grafana-dr.XXXXXX"

}

file_remove_temp() {

    local TEMP_FILE="$1"

    if [[ -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
    fi

}

file_validate_json() {

    local JSON_FILE="$1"

    [[ -f "$JSON_FILE" ]] || return 1

    jq empty "$JSON_FILE" >/dev/null 2>&1

}

file_compare() {

    local FILE1="$1"
    local FILE2="$2"

    cmp -s "$FILE1" "$FILE2"

}

file_sha256() {

    local JSON_FILE="$1"

    sha256sum "$JSON_FILE" | awk '{print $1}'

}


file_generate_name() {

    local DASHBOARD_TITLE="$1"
    local DASHBOARD_UID="$2"

    local SAFE_TITLE

    SAFE_TITLE=$(
        echo "$DASHBOARD_TITLE" |
        tr '[:upper:]' '[:lower:]' |
        tr ' ' '-' |
        tr -cd '[:alnum:]-'
    )

    printf "%s__%s.json\n" \
        "$SAFE_TITLE" \
        "$DASHBOARD_UID"

}

###############################################################################
# file_safe_write
#
# Safely replaces a destination file with a validated temporary file.
#
# Arguments:
#   $1 - Temporary file
#   $2 - Destination file
#
# Returns:
#   0  - File created or updated successfully
#   10 - No changes detected
#   20 - Invalid JSON
#   30 - Temporary file missing
###############################################################################

file_safe_write() {

    local TEMP_FILE="$1"
    local DEST_FILE="$2"

    #
    # Ensure temporary file exists.
    #
    if [[ ! -f "$TEMP_FILE" ]]; then
        return $FILE_TEMP_MISSING
    fi

    #
    # Validate JSON before replacing anything.
    #
    if ! file_validate_json "$TEMP_FILE"; then
        file_remove_temp "$TEMP_FILE"
        return $FILE_INVALID_JSON
    fi

    #
    # Destination does not exist.
    #
    if [[ ! -f "$DEST_FILE" ]]; then
        mv "$TEMP_FILE" "$DEST_FILE"
        return $FILE_SUCCESS
    fi

    #
    # Files are identical.
    #
    if file_compare "$TEMP_FILE" "$DEST_FILE"; then
        file_remove_temp "$TEMP_FILE"
        return $FILE_NO_CHANGE
    fi

    #
    # Replace atomically.
    #
    mv "$TEMP_FILE" "$DEST_FILE"

    return $FILE_SUCCESS
}
