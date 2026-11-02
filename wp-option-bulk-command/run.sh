#!/usr/bin/env bash
# wp-option-bulk-command: run any `wp option ...` command on every site, then
# purge the Breeze cache. Replaces the original script_1dbafb.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# shellcheck disable=SC2034
SCRIPT_NAME="wp-option-bulk-command"
# shellcheck disable=SC2034
SCRIPT_SUMMARY="Run a 'wp option' command on every WordPress site, then purge the Breeze cache."
# shellcheck disable=SC2034
SCRIPT_USAGE="./run.sh [options] <wp-option-subcommand> [args...]"
# shellcheck disable=SC2034
SCRIPT_ALLOWS_NO_PURGE=1
# shellcheck disable=SC2034
SCRIPT_EXTRA_HELP="  --no-purge       Do not purge the Breeze cache afterwards
"

# Subcommands that never change anything: no prompt, no purge, run even in --dry-run.
read_only_subcommands=(get list pluck)
READ_ONLY=0

process_site() {
  if (( READ_ONLY )); then
    wp option "${ARGS[@]}"
    return
  fi
  mutate wp option "${ARGS[@]}"
  if (( ! NO_PURGE )); then
    purge_breeze_cache
  fi
}

parse_args "$@"
(( ${#ARGS[@]} )) || usage_error "missing subcommand, for example: ./run.sh update blogdescription 'New tagline'"
if in_list "${ARGS[0]}" "${read_only_subcommands[@]}"; then
  READ_ONLY=1
# shellcheck disable=SC2034
  NEEDS_CONFIRM=0
fi
preflight
for_each_wp_site process_site
exit $?
