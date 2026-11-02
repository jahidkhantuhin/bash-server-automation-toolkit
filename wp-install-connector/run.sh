#!/usr/bin/env bash
# wp-install-connector: (re)install the connector-plugin plugin on every
# site and set its default webhook. Replaces the original install_1.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# These variables are read by functions from the sourced common library.
# shellcheck disable=SC2034
SCRIPT_NAME="wp-install-connector"
SCRIPT_SUMMARY="Install or update a connector plugin on every WordPress site and set its default webhook."
SCRIPT_USAGE="./run.sh [options]"

PLUGIN_REPO="${GITHUB_ORG:-}/${CONNECTOR_REPO_NAME:-connector-plugin}"
PLUGIN_SLUG="${CONNECTOR_PLUGIN_SLUG:-connector-plugin}"
POST_COMMAND="${CONNECTOR_POST_COMMAND:-set_connector_webhook_default}"
COMPOSER_FLAGS="${COMPOSER_FLAGS:---no-dev --no-interaction --prefer-dist --optimize-autoloader}"

# Clone and build once; every site then gets a copy of the finished plugin.
stage_repo() {
  stage_github_repo "$PLUGIN_REPO" || return 1
  if (( DRY_RUN )); then
    log_info "[dry-run] would run once: composer install $COMPOSER_FLAGS"
    return 0
  fi
  log_info "Installing PHP dependencies (once)"
  # shellcheck disable=SC2086  # COMPOSER_FLAGS is intentionally word-split
  ( cd "$STAGED_DIR" && composer install $COMPOSER_FLAGS ) || { log_error "composer install failed"; return 1; }
}

process_site() {
  deploy_plugin "$PLUGIN_SLUG" "$POST_COMMAND"
}

parse_args "$@"
no_extra_args
preflight git composer
for_each_wp_site process_site stage_repo
exit $?
