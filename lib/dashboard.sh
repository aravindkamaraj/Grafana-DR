###############################################################################
# grafana_list_dashboards
#
# Returns:
#   JSON array containing all dashboards.
###############################################################################

grafana_list_dashboards() {

    api_get "/api/search?type=dash-db"

}

###############################################################################
# grafana_export_dashboard
#
# Arguments:
#   $1 - Dashboard UID
#
# Returns:
#   Dashboard JSON
###############################################################################

grafana_export_dashboard() {

    local DASHBOARD_UID="$1"

    api_get "/api/dashboards/uid/${DASHBOARD_UID}"

}

###############################################################################
# Import a Grafana dashboard.
#
# Arguments:
#   $1 - Dashboard backup JSON file
#
# Returns:
#   0 - Dashboard imported successfully
#   1 - Import failed
###############################################################################

grafana_import_dashboard() {

    local JSON_FILE="$1"
    local TEMP_FILE

    TEMP_FILE=$(file_create_temp)

    if ! jq \
        '{
            dashboard: .dashboard,
            folderUid: null,
            overwrite: true
        }' \
        "$JSON_FILE" > "$TEMP_FILE"
    then
        file_remove_temp "$TEMP_FILE"
        return 1
    fi

    api_post "/api/dashboards/db" "$TEMP_FILE"

    local RESULT=$?

    file_remove_temp "$TEMP_FILE"

    return $RESULT

}

###############################################################################
# grafana_delete_dashboard
#
# Arguments:
#   $1 - Dashboard UID
###############################################################################

grafana_delete_dashboard() {

    local DASHBOARD_UID="$1"

    api_delete "/api/dashboards/uid/${DASHBOARD_UID}"

}

grafana_dashboard_exists() {

    local DASHBOARD_UID="$1"

    if grafana_export_dashboard "$DASHBOARD_UID" >/dev/null 2>&1
    then
        return 0
    fi

    return 1

}

grafana_dashboard_title() {

    local DASHBOARD_UID="$1"

    grafana_export_dashboard "$DASHBOARD_UID" \
        | jq -r '.dashboard.title'

}
