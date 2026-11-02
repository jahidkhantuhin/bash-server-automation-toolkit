#!/usr/bin/env bash
# wp-fix-number-flipper: deploy wordpress-scripts and run its Number
# Flipper fix. Replaces the original fix_flipper.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# shellcheck disable=SC2034
SCRIPT_NAME="wp-fix-number-flipper"
# shellcheck disable=SC2034
SCRIPT_SUMMARY="Deploy wordpress-scripts and fix the Number Flipper on every site."
# shellcheck disable=SC2034
SCRIPT_USAGE="./run.sh [options]"

PLUGIN_REPO="${GITHUB_ORG:-}/${WORDPRESS_SCRIPTS_REPO_NAME:-wordpress-scripts}"
PLUGIN_SLUG="${WORDPRESS_SCRIPTS_PLUGIN_SLUG:-wordpress-scripts}"
WP_COMMAND="fix_number_flipper"

stage_repo() { stage_github_repo "$PLUGIN_REPO"; }

process_site() {
  deploy_plugin "$PLUGIN_SLUG" "$WP_COMMAND"
}

parse_args "$@"
no_extra_args
preflight git
for_each_wp_site process_site stage_repo
exit $?
