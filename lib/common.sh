#!/usr/bin/env bash
# shellcheck shell=bash disable=SC2034
#
# lib/common.sh: shared helpers for the WordPress bulk scripts.
#
# Source this file; do not execute it. It provides:
#   - argument parsing (--dry-run, --app, --yes, ...)
#   - site discovery for the Cloudways layout: <APPS_ROOT>/<app>/public_html
#   - per-site execution with error isolation and a final summary
#   - private GitHub cloning where the token never lands in argv or .git/config
#   - plugin deployment with automatic rollback

if [[ -n "${_WPBULK_COMMON_LOADED:-}" ]]; then
  return 0
fi
_WPBULK_COMMON_LOADED=1

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
  echo "Bash 4.4 or newer is required (found ${BASH_VERSION})." >&2
  exit 1
fi

# Deliberately NOT using `set -e` in the main shell: one failing site must not
# abort the whole run. Each site's work runs in a subshell that enables it.
set -uo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$LIB_DIR")"

# A site callback returns this to say "nothing to do here" (not a failure).
readonly EX_SKIP=10

# ------------------------------------------------------------------ logging
LOG_CTX=""

_log() {
  local level="$1"
  shift
  printf '%s [%-5s] %s%s\n' "$(date '+%F %T')" "$level" "${LOG_CTX:+[$LOG_CTX] }" "$*"
}
log_info()  { _log INFO "$@"; }
log_warn()  { _log WARN "$@" >&2; }
log_error() { _log ERROR "$@" >&2; }
die()       { log_error "$@"; exit 1; }

# ------------------------------------------------------------------- config
# Loads KEY=VALUE pairs from <repo>/.env without executing anything. Variables
# that are already set in the environment always win.
_load_env_file() {
  local file="$REPO_ROOT/.env" mode key value
  [[ -f "$file" ]] || return 0

  mode="$(stat -c '%a' "$file" 2>/dev/null || true)"
  if [[ -n "$mode" && "$mode" != "600" && "$mode" != "400" ]]; then
    log_warn ".env is readable by others (mode $mode). Run: chmod 600 $file"
  fi

  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
    value="${value%\"}"; value="${value#\"}"
    value="${value%\'}"; value="${value#\'}"
    if [[ -z "${!key:-}" ]]; then
      export "$key=$value"
    fi
  done < "$file"
}
_load_env_file

APPS_ROOT="${APPS_ROOT:-/home/master/applications}"

# -------------------------------------------------------------------- state
DRY_RUN=0
FORCE=0
ASSUME_YES=0
NO_PURGE=0
NEEDS_CONFIRM=1           # scripts that only read or are harmless set this to 0
ONLY_APPS=()
ARGS=()
WP_APPS=()
COUNT_OK=0
COUNT_SKIPPED=0
COUNT_FAILED=0
FAILED_APPS=()
APP=""                    # set per site for callbacks
SITE_DIR=""
SITE_URL=""
STAGED_DIR=""
_CLEANUP_PATHS=()

_cleanup() {
  local path
  for path in "${_CLEANUP_PATHS[@]}"; do
    if [[ -n "$path" ]]; then
      rm -rf -- "$path"
    fi
  done
}
trap _cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ------------------------------------------------------------------ helpers
in_list() {
  local needle="$1" item
  shift
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
  done
}

# Checks the environment before anything is touched. Extra args = extra commands.
preflight() {
  if [[ "${EUID:-$(id -u)}" -eq 0 && -z "${ALLOW_ROOT:-}" ]]; then
    die "Don't run this as root. Use the Cloudways master user (WP-CLI refuses root, and files would end up root-owned)."
  fi
  require_cmd wp "$@"
}

# Runs a command, or only prints it when --dry-run is active.
# Use it for anything that changes state; plain calls are for read-only queries.
mutate() {
  if (( DRY_RUN )); then
    log_info "[dry-run] would run: $(printf '%q ' "$@")"
    return 0
  fi
  "$@"
}

# ------------------------------------------------------------- CLI handling
print_usage() {
  cat <<USAGE
${SCRIPT_NAME:-script}: ${SCRIPT_SUMMARY:-}

Usage:
  ${SCRIPT_USAGE:-./run.sh [options]}

Options:
  --dry-run        Show what would change; modify nothing
  --app NAME       Only process this app folder (repeatable)
  -y, --yes        Do not ask for confirmation before changing sites
${SCRIPT_EXTRA_HELP:-}  -h, --help       Show this help

Environment:
  APPS_ROOT        Applications directory (default: /home/master/applications)
USAGE
}

usage_error() {
  log_error "$*"
  echo "Try '${0##*/} --help' for usage." >&2
  exit 2
}

# Parses the common options. The first non-option argument (or "--") ends
# option parsing; everything after it is left in ARGS for the script.
parse_args() {
  while (( $# )); do
    case "$1" in
      --dry-run)   DRY_RUN=1 ;;
      -y|--yes)    ASSUME_YES=1 ;;
      --force)
        (( ${SCRIPT_ALLOWS_FORCE:-0} )) || usage_error "unknown option: $1"
        FORCE=1 ;;
      --no-purge)
        (( ${SCRIPT_ALLOWS_NO_PURGE:-0} )) || usage_error "unknown option: $1"
        NO_PURGE=1 ;;
      --app)
        (( $# >= 2 )) || usage_error "--app needs a value"
        ONLY_APPS+=("$2"); shift ;;
      --app=*)     ONLY_APPS+=("${1#--app=}") ;;
      -h|--help)   print_usage; exit 0 ;;
      --)          shift; ARGS=("$@"); return 0 ;;
      -*)          usage_error "unknown option: $1" ;;
      *)           ARGS=("$@"); return 0 ;;
    esac
    shift
  done
}

no_extra_args() {
  (( ${#ARGS[@]} == 0 )) || usage_error "unexpected argument: ${ARGS[0]}"
}

# -------------------------------------------------------- site orchestration
_discover_sites() {
  local dir app wanted
  local -a candidates=()

  [[ -d "$APPS_ROOT" ]] || die "Applications directory not found: $APPS_ROOT"

  shopt -s nullglob
  for dir in "$APPS_ROOT"/*/; do
    dir="${dir%/}"
    candidates+=("${dir##*/}")
  done
  shopt -u nullglob

  for wanted in "${ONLY_APPS[@]}"; do
    in_list "$wanted" "${candidates[@]}" || die "No such app in $APPS_ROOT: $wanted"
  done

  WP_APPS=()
  for app in "${candidates[@]}"; do
    if (( ${#ONLY_APPS[@]} )) && ! in_list "$app" "${ONLY_APPS[@]}"; then
      continue
    fi
    if [[ -f "$APPS_ROOT/$app/public_html/wp-config.php" ]]; then
      WP_APPS+=("$app")
    else
      LOG_CTX="$app" log_info "Not a WordPress app, skipping"
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    fi
  done
}

_confirm_run() {
  local answer
  (( NEEDS_CONFIRM )) || return 0
  (( DRY_RUN || ASSUME_YES )) && return 0
  if [[ ! -t 0 ]]; then
    die "Refusing to change ${#WP_APPS[@]} site(s) without confirmation in a non-interactive shell. Re-run with --yes."
  fi
  read -r -p "This will change ${#WP_APPS[@]} WordPress site(s) in $APPS_ROOT. Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]] || die "Aborted. Nothing was changed."
}

_print_summary() {
  local suffix=""
  (( DRY_RUN )) && suffix=" (dry run, nothing was changed)"
  log_info "Summary: ${COUNT_OK} done, ${COUNT_SKIPPED} skipped, ${COUNT_FAILED} failed${suffix}"
  if (( COUNT_FAILED )); then
    log_error "Failed apps: ${FAILED_APPS[*]}"
  fi
}

# for_each_wp_site CALLBACK [SETUP]
#
# Runs CALLBACK once per WordPress site, from inside its public_html, in a
# subshell with `set -e`. The callback signals its result with its exit code:
#   0 = done, $EX_SKIP = nothing to do, anything else = failed.
# SETUP (optional) runs once, after confirmation and before the first site.
# Available to the callback: APP, SITE_DIR, SITE_URL, DRY_RUN, FORCE, ARGS.
for_each_wp_site() {
  local callback="$1" setup="${2:-}" app rc

  _discover_sites
  if (( ${#WP_APPS[@]} == 0 )); then
    log_warn "No WordPress sites found under $APPS_ROOT"
    return 0
  fi

  _confirm_run
  if [[ -n "$setup" ]]; then
    "$setup" || die "Setup failed. No site was modified."
  fi
  if (( DRY_RUN )); then
    log_info "DRY RUN: no changes will be made"
  fi
  log_info "Processing ${#WP_APPS[@]} WordPress site(s)"

  for app in "${WP_APPS[@]}"; do
    APP="$app"
    SITE_DIR="$APPS_ROOT/$app/public_html"
    LOG_CTX="$app"

    if ! SITE_URL="$(cd "$SITE_DIR" && wp option get siteurl --skip-plugins --skip-themes 2>/dev/null)"; then
      log_error "WP-CLI could not read this site (broken install or database?)"
      COUNT_FAILED=$((COUNT_FAILED + 1))
      FAILED_APPS+=("$app")
      continue
    fi
    log_info "Working on $SITE_URL"

    # Not wrapped in `if`/`||`: that would silently disable `set -e` inside.
    (
      set -e
      cd "$SITE_DIR"
      "$callback"
    )
    rc=$?

    if (( rc == 0 )); then
      COUNT_OK=$((COUNT_OK + 1))
    elif (( rc == EX_SKIP )); then
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
      log_error "Failed (exit code $rc)"
      COUNT_FAILED=$((COUNT_FAILED + 1))
      FAILED_APPS+=("$app")
    fi
  done

  LOG_CTX=""
  _print_summary
  (( COUNT_FAILED == 0 ))
}

# -------------------------------------------------------------- Breeze cache
breeze_is_active() {
  wp plugin is-active breeze --skip-plugins --skip-themes >/dev/null 2>&1
}

# Purges Breeze after a change. A site without Breeze is not an error here.
purge_breeze_cache() {
  if ! breeze_is_active; then
    log_info "Breeze is not active, no cache to purge"
    return 0
  fi
  log_info "Purging Breeze cache"
  mutate wp breeze purge --cache=all
}

# ------------------------------------------------------------ private GitHub
require_github_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    return 0
  fi
  if (( DRY_RUN )); then
    log_warn "GITHUB_TOKEN is not set. A real run will need it."
    return 0
  fi
  die "GITHUB_TOKEN is not set. Export it or put it in $REPO_ROOT/.env (see .env.example)."
}

# stage_github_repo OWNER/REPO
#
# Clones the repo ONCE into a temp folder (removed on exit) and sets
# STAGED_DIR. Every site then gets a copy, so GitHub is contacted a single
# time and an outage is discovered before any site is touched.
#
# The token is handed to git through an inline credential helper that reads it
# from the environment, so it never appears in a URL, in `ps`, or in .git/config.
stage_github_repo() {
  local repo="$1" tmp name="${1##*/}"

  [[ "$repo" == */* && "$repo" != /* ]] || die "Set GITHUB_ORG in .env before running a script that clones a repository."

  require_github_token
  if (( DRY_RUN )); then
    log_info "[dry-run] would clone https://github.com/$repo.git once and reuse it for every site"
    return 0
  fi

  tmp="$(mktemp -d)" || die "Could not create a temporary directory"
  _CLEANUP_PATHS+=("$tmp")
  export GITHUB_TOKEN

  log_info "Cloning $repo (once; reused for every site)"
  if ! GIT_TERMINAL_PROMPT=0 git \
        -c credential.helper= \
        -c 'credential.helper=!f() { echo "username=x-access-token"; echo "password=${GITHUB_TOKEN}"; }; f' \
        clone --quiet "https://github.com/$repo.git" "$tmp/$name"; then
    die "Could not clone $repo. Check that GITHUB_TOKEN is valid and can read it."
  fi
  STAGED_DIR="$tmp/$name"
}

# --------------------------------------------------------- plugin deployment
# deploy_plugin SLUG [WP-COMMAND [ARGS...]]
#
# Replaces plugins/SLUG with the staged copy and activates it, then optionally
# runs `wp WP-COMMAND ...`. The old version is kept aside until everything has
# succeeded; if anything fails, it is restored (and re-activated if it was
# active), so a failed deploy never leaves a site without its plugin.
deploy_plugin() {
  local slug="$1"
  shift
  local plugins_dir="$SITE_DIR/wp-content/plugins"
  local target="$plugins_dir/$slug"
  local fresh="$plugins_dir/.$slug.new"
  local backup="$plugins_dir/.$slug.old"
  local was_active=0 had_old=0 post=""
  (( $# )) && post="wp $*"

  if (( DRY_RUN )); then
    log_info "[dry-run] would deploy '$slug' (swap in the staged copy, activate${post:+, then run: $post})"
    return 0
  fi

  [[ -d "$plugins_dir" ]] || { log_error "Plugins folder not found: $plugins_dir"; return 1; }
  [[ -n "$STAGED_DIR" && -d "$STAGED_DIR" ]] || { log_error "No staged copy available"; return 1; }

  rm -rf -- "$fresh" "$backup"
  cp -a -- "$STAGED_DIR" "$fresh" || { rm -rf -- "$fresh"; log_error "Could not copy plugin files"; return 1; }

  if wp plugin is-active "$slug" --skip-plugins --skip-themes >/dev/null 2>&1; then
    was_active=1
    wp plugin deactivate "$slug" || { rm -rf -- "$fresh"; return 1; }
  fi

  if [[ -d "$target" ]]; then
    if ! mv -- "$target" "$backup"; then
      rm -rf -- "$fresh"
      (( was_active )) && wp plugin activate "$slug"
      return 1
    fi
    had_old=1
  fi

  if ! mv -- "$fresh" "$target"; then
    rm -rf -- "$fresh"
    (( had_old )) && mv -- "$backup" "$target"
    (( was_active )) && wp plugin activate "$slug"
    return 1
  fi

  if wp plugin activate "$slug" && { (( $# == 0 )) || wp "$@"; }; then
    rm -rf -- "$backup"
    log_info "Deployed '$slug'${post:+ and ran: $post}"
    return 0
  fi

  log_error "Deploying '$slug' failed; restoring the previous version"
  rm -rf -- "$target"
  (( had_old )) && mv -- "$backup" "$target"
  (( was_active )) && wp plugin activate "$slug"
  return 1
}
