#!/usr/bin/env bash
# wp-enable-user-registration: turn on user registration and install the
# anti-spam plugin that protects the registration page. Replaces fix.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# shellcheck disable=SC2034
SCRIPT_NAME="wp-enable-user-registration"
# shellcheck disable=SC2034
SCRIPT_SUMMARY="Enable user registration on every WordPress site, protected by an anti-spam plugin."
# shellcheck disable=SC2034
SCRIPT_USAGE="./run.sh [options]"

PLUGIN_SLUG="disable-wp-registration-page-spam"

process_site() {
  local role

  if wp plugin is-installed "$PLUGIN_SLUG" --skip-plugins --skip-themes; then
    log_info "'$PLUGIN_SLUG' is already installed"
  else
    mutate wp plugin install "$PLUGIN_SLUG"
  fi
  mutate wp plugin activate "$PLUGIN_SLUG"
  mutate wp option update users_can_register 1

  # Open registration hands every new user this role, so make noise if it's powerful.
  role="$(wp option get default_role --skip-plugins --skip-themes 2>/dev/null)" || role=""
  if [[ -n "$role" && "$role" != "subscriber" ]]; then
    log_warn "default_role is '$role', not 'subscriber'. New registrants will get that role!"
  fi
}

parse_args "$@"
no_extra_args
preflight
for_each_wp_site process_site
exit $?
