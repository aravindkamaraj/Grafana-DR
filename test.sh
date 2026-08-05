#!/usr/bin/env bash

source lib/config.sh
source lib/common.sh
source lib/api.sh

load_token

api_health && echo "Grafana is reachable"

echo "Grafana Version: $(api_version)"
