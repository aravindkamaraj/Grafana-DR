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
# grafana_import_dashboard
#
# Arguments:
#   $1 - JSON file
###############################################################################

grafana_import_dashboard() {

    local JSON_FILE="$1"

    api_post "/api/dashboards/db" "$JSON_FILE"

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
