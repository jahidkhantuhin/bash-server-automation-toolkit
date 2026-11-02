#!/usr/bin/env bash
# wp-breeze-purge-all: purge the Breeze cache on every WordPress site.
# Replaces the original script.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# shellcheck disable=SC2034
SCRIPT_NAME="wp-breeze-purge-all"
# shellcheck disable=SC2034
SCRIPT_SUMMARY="Purge the Breeze cache on every WordPress site on this server."
# shellcheck disable=SC2034
SCRIPT_USAGE="./run.sh [options]"
# shellcheck disable=SC2034
NEEDS_CONFIRM=0   # a cache purge is harmless, so no prompt

process_site() {
  if ! breeze_is_active; then
    log_info "Breeze is not active, skipping"
    return "$EX_SKIP"
  fi
  log_info "Purging Breeze cache"
  mutate wp breeze purge --cache=all
}

parse_args "$@"
no_extra_args
preflight
for_each_wp_site process_site
exit $?
