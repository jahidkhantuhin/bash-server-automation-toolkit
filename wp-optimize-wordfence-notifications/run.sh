#!/usr/bin/env bash
# wp-optimize-wordfence-notifications: deploy example-wordpress-scripts and run
# its Wordfence notification optimizer. Replaces the original script_1.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

SCRIPT_NAME="wp-optimize-wordfence-notifications"
SCRIPT_SUMMARY="Deploy example-wordpress-scripts and optimize the Wordfence notifications on every site."
SCRIPT_USAGE="./run.sh [options]"

PLUGIN_REPO="example/example-wordpress-scripts"
PLUGIN_SLUG="example-wordpress-scripts"
WP_COMMAND="optimize_wordfence_notifications"

stage_repo() { stage_github_repo "$PLUGIN_REPO"; }

process_site() {
  deploy_plugin "$PLUGIN_SLUG" "$WP_COMMAND"
}

parse_args "$@"
no_extra_args
preflight git
for_each_wp_site process_site stage_repo
exit $?
