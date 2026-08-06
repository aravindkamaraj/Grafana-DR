#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../lib/bootstrap.sh"
source "${PROJECT_ROOT}/lib/git.sh"

initialize

git_sync