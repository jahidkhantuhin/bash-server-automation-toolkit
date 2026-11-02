#!/usr/bin/env bash
# wp-plugin-bulk-command: run any `wp plugin ...` command on every site, then
# purge the Breeze cache. Replaces the original script_44e708.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# These variables are read by functions from the sourced common library.
# shellcheck disable=SC2034
SCRIPT_NAME="wp-plugin-bulk-command"
SCRIPT_SUMMARY="Run a 'wp plugin' command on every WordPress site, then purge the Breeze cache."
SCRIPT_USAGE="./run.sh [options] <wp-plugin-subcommand> [args...]"
SCRIPT_ALLOWS_NO_PURGE=1
SCRIPT_EXTRA_HELP="  --no-purge       Do not purge the Breeze cache afterwards
"

# Subcommands that never change anything: no prompt, no purge, run even in --dry-run.
read_only_subcommands=(get is-active is-installed list path search status verify-checksums)
READ_ONLY=0

process_site() {
  if (( READ_ONLY )); then
    wp plugin "${ARGS[@]}"
    return
  fi
  mutate wp plugin "${ARGS[@]}"
  if (( ! NO_PURGE )); then
    purge_breeze_cache
  fi
}

parse_args "$@"
(( ${#ARGS[@]} )) || usage_error "missing subcommand, for example: ./run.sh update --all"
if in_list "${ARGS[0]}" "${read_only_subcommands[@]}"; then
  READ_ONLY=1
  NEEDS_CONFIRM=0
fi
preflight
for_each_wp_site process_site
exit $?
