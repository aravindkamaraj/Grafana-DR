#!/usr/bin/env bash

###############################################################################
# Grafana-DR
#
# Git Library
#
# Handles Git repository operations.
###############################################################################

git_is_repo() {

    git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1

}

git_has_changes() {

    [[ -n $(git -C "$PROJECT_ROOT" status --porcelain) ]]

}

git_stage() {

    git -C "$PROJECT_ROOT" add .

}

git_commit() {

    local MESSAGE="$1"

    git -C "$PROJECT_ROOT" commit -m "$MESSAGE"

}

git_push() {

    git -C "$PROJECT_ROOT" push

}

git_sync() {

    if ! git_is_repo; then
        log ERROR "Project is not a Git repository."
        return 1
    fi

    if ! git_has_changes; then
        log INFO "No Git changes detected."
        return 0
    fi

    git_stage

    git_commit "Grafana backup - $(date '+%Y-%m-%d %H:%M:%S')"

    git_push

    log INFO "Git synchronization completed."

}
