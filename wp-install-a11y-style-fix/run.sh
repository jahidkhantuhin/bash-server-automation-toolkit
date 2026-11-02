#!/usr/bin/env bash
# wp-install-a11y-style-fix: install the accessibility-style-fix plugin on
# sites that use a legacy or broken theme. Replaces the original install.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

SCRIPT_NAME="wp-install-a11y-style-fix"
SCRIPT_SUMMARY="Install the accessibility-style-fix plugin on sites with a legacy or defective theme."
SCRIPT_USAGE="./run.sh [options]"
SCRIPT_ALLOWS_FORCE=1
SCRIPT_EXTRA_HELP="  --force          Redeploy even if the plugin is already active
"

PLUGIN_REPO="example/accessibility-style-fix"
PLUGIN_SLUG="accessibility-style-fix"
# Space-separated theme slugs that count as "legacy". Override via the environment.
read -ra legacy_themes <<< "${LEGACY_THEMES:-leadhubtheme onepageextendedtheme}"

stage_repo() { stage_github_repo "$PLUGIN_REPO"; }

process_site() {
  local theme
  # An empty result means no usable active theme, i.e. a defective theme.
  theme="$(wp theme list --status=active --field=name 2>/dev/null)" || theme=""

  if [[ -n "$theme" ]] && ! in_list "$theme" "${legacy_themes[@]}"; then
    log_info "Active theme '$theme' is current, no fix needed"
    return "$EX_SKIP"
  fi
  if [[ -z "$theme" ]]; then
    log_warn "No active theme found (defective theme)"
  else
    log_info "Active theme '$theme' is a legacy theme"
  fi

  if (( ! FORCE )) && wp plugin is-active "$PLUGIN_SLUG" --skip-plugins --skip-themes >/dev/null 2>&1; then
    log_info "'$PLUGIN_SLUG' is already active (use --force to redeploy)"
    return "$EX_SKIP"
  fi
  deploy_plugin "$PLUGIN_SLUG"
}

parse_args "$@"
no_extra_args
preflight git
for_each_wp_site process_site stage_repo
exit $?
