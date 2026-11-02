#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
require_cmd wp
[[ -d "$APPS_ROOT" ]] || die "Applications directory not found: $APPS_ROOT"

printf 'Listing WordPress site URLs under %s\n' "$APPS_ROOT"
shopt -s nullglob
app_dirs=("$APPS_ROOT"/*/)
shopt -u nullglob

site_count=0
failure_count=0
for dir in "${app_dirs[@]}"; do
  site_dir="${dir%/}/public_html"
  [[ -f "$site_dir/wp-config.php" ]] || continue
  site_count=$((site_count + 1))

  if ! site_url="$(wp --path="$site_dir" option get siteurl --skip-plugins --skip-themes)"; then
    printf 'Warning: could not read site URL from %s\n' "$site_dir" >&2
    failure_count=$((failure_count + 1))
    continue
  fi
  printf '%s\n' "$site_url"
done

printf 'Found %d WordPress site(s); %d read failure(s).\n' "$site_count" "$failure_count"
(( failure_count == 0 ))
