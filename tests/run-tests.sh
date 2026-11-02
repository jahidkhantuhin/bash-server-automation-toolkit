#!/usr/bin/env bash
# Offline test suite. Runs every script against stubbed wp/git/composer binaries
# and a fake Cloudways applications folder, so nothing real is ever touched.
#
#   ./tests/run-tests.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
TOKEN="ghp_TESTTOKEN1234567890"
PASS=0
FAIL=0
WORK=""

# ---------------------------------------------------------------- helpers
check() {  # check "description" command...
  local desc="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1)); printf '  ok    %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$desc"
  fi
}
out_has()  { [[ "$OUT" == *"$1"* ]]; }
out_lacks(){ [[ "$OUT" != *"$1"* ]]; }
rc_is()    { [[ "$RC" -eq "$1" ]]; }
exists()   { [[ -e "$SITES/$1" ]]; }
missing()  { [[ ! -e "$SITES/$1" ]]; }
file_has() { grep -qF -- "$2" "$SITES/$1" 2>/dev/null; }
file_lacks(){ ! grep -qF -- "$2" "$SITES/$1" 2>/dev/null; }
log_has()  { grep -qF -- "$2" "$1" 2>/dev/null; }
log_lacks(){ ! grep -qF -- "$2" "$1" 2>/dev/null; }

mk_site() {  # mk_site app theme [breeze]
  local d="$SITES/$1/public_html"
  mkdir -p "$d/wp-content/plugins" "$d/.active"
  : > "$d/wp-config.php"
  printf '%s' "$2" > "$d/.theme"
  [[ -n "${3:-}" ]] && touch "$d/.active/breeze"
  return 0
}

new_fixture() {
  [[ -n "$WORK" ]] && rm -rf "$WORK"
  WORK="$(mktemp -d)"
  SITES="$WORK/applications"
  export WP_STUB_LOG="$WORK/wp.log" GIT_STUB_LOG="$WORK/git.log" COMPOSER_STUB_LOG="$WORK/composer.log"
  : > "$WP_STUB_LOG"; : > "$GIT_STUB_LOG"; : > "$COMPOSER_STUB_LOG"
  mk_site modern modern breeze
  mk_site legacy leadhubtheme
  mk_site defective "" breeze
  mkdir -p "$SITES/static/public_html"
}

run() {  # run <folder> [args...]   (stdin is not a TTY, like cron or CI)
  local folder="$1"
  shift
  OUT="$(PATH="$HERE/stubs:$PATH" APPS_ROOT="$SITES" ALLOW_ROOT=1 \
         "$REPO/$folder/run.sh" "$@" < /dev/null 2>&1)"
  RC=$?
}

export GITHUB_TOKEN="$TOKEN"
trap '[[ -n "$WORK" ]] && rm -rf "$WORK"' EXIT

# ------------------------------------------------------------------ tests
echo "wp-breeze-purge-all"
new_fixture
run wp-breeze-purge-all --dry-run
check "dry run exits 0"                       rc_is 0
check "dry run purges nothing"                missing modern/public_html/.purged
run wp-breeze-purge-all
check "real run exits 0 without a prompt"     rc_is 0
check "purges sites where Breeze is active"   exists modern/public_html/.purged
check "purges every Breeze site"              exists defective/public_html/.purged
check "skips sites without Breeze"            missing legacy/public_html/.purged
check "ignores non-WordPress apps"            out_has "Not a WordPress app"
check "prints a summary"                      out_has "Summary: 2 done, 2 skipped, 0 failed"

echo "failure isolation"
mk_site broken modern breeze
touch "$SITES/broken/public_html/.broken"
rm -f "$SITES"/*/public_html/.purged
run wp-breeze-purge-all
check "exits 1 when a site fails"             rc_is 1
check "names the failed app"                  out_has "Failed apps: broken"
check "still processes the healthy sites"     exists modern/public_html/.purged

echo "--app and --help"
new_fixture
run wp-breeze-purge-all --app modern
check "--app limits the run"                  exists modern/public_html/.purged
check "--app leaves other sites alone"        missing defective/public_html/.purged
run wp-breeze-purge-all --app nope
check "unknown --app is an error"             rc_is 1
run wp-breeze-purge-all --help
check "--help exits 0 and shows usage"        out_has "Usage:"
run wp-breeze-purge-all --bogus
check "unknown option exits 2"                rc_is 2
run wp-breeze-purge-all extra
check "unexpected argument exits 2"           rc_is 2

echo "wp-install-a11y-style-fix"
new_fixture
run wp-install-a11y-style-fix --dry-run
check "dry run exits 0"                       rc_is 0
check "dry run installs nothing"              missing legacy/public_html/wp-content/plugins/accessibility-style-fix
check "dry run does not call git"             log_lacks "$GIT_STUB_LOG" "clone"
run wp-install-a11y-style-fix
check "refuses to change sites non-interactively without --yes"  out_has "--yes"
check "...and exits 1"                        rc_is 1
check "...and changed nothing"                missing legacy/public_html/wp-content/plugins/accessibility-style-fix
run wp-install-a11y-style-fix --yes
check "real run exits 0"                      rc_is 0
check "installs on a legacy theme"            exists legacy/public_html/wp-content/plugins/accessibility-style-fix/plugin.php
check "installs on a defective theme"         exists defective/public_html/wp-content/plugins/accessibility-style-fix/plugin.php
check "activates the plugin"                  exists legacy/public_html/.active/accessibility-style-fix
check "skips a modern theme"                  missing modern/public_html/wp-content/plugins/accessibility-style-fix
check "clones exactly once for all sites"     [ "$(grep -c 'ARGV:.*clone' "$GIT_STUB_LOG")" -eq 1 ]
check "token is NOT on the command line"      log_lacks "$GIT_STUB_LOG" "$TOKEN"
check "clone URL has no credentials"          log_has "$GIT_STUB_LOG" "https://github.com/example/accessibility-style-fix.git"
check "token reaches git via the environment" log_has "$GIT_STUB_LOG" "TOKEN_IN_ENV: yes"
check "token is not saved in the site's .git/config" file_lacks legacy/public_html/wp-content/plugins/accessibility-style-fix/.git/config "ghp_"
run wp-install-a11y-style-fix --yes
check "second run skips already-fixed sites"  out_has "already active"
check "second run exits 0"                    rc_is 0
GITHUB_TOKEN="" run wp-install-a11y-style-fix --yes --app legacy
check "missing token fails with a clear message" out_has "GITHUB_TOKEN is not set"

echo "wp-install-a11y-style-fix: GitHub failure"
new_fixture
GIT_STUB_FAIL=1 run wp-install-a11y-style-fix --yes
check "clone failure aborts before any site changes" missing legacy/public_html/wp-content/plugins/accessibility-style-fix
check "clone failure exits 1"                 rc_is 1

echo "wp-install-a11y-style-fix: .env file"
new_fixture
printf 'GITHUB_TOKEN=from_env_file\n' > "$REPO/.env"; chmod 600 "$REPO/.env"
GITHUB_TOKEN="" run wp-install-a11y-style-fix --yes --app legacy
rm -f "$REPO/.env"
check "token is read from .env"               rc_is 0

echo "wp-install-example-connector"
new_fixture
old="$SITES/legacy/public_html/wp-content/plugins/example-Connector"
mkdir -p "$old"; echo "old-version" > "$old/plugin.php"; touch "$SITES/legacy/public_html/.active/example-Connector"
run wp-install-example-connector --yes
check "run exits 0"                           rc_is 0
check "replaces the old version"              file_has legacy/public_html/wp-content/plugins/example-Connector/plugin.php "new-version"
check "ships composer dependencies"           exists legacy/public_html/wp-content/plugins/example-Connector/vendor/autoload.php
check "composer runs once, not per site"      [ "$(wc -l < "$COMPOSER_STUB_LOG")" -eq 1 ]
check "uses production composer flags"        log_has "$COMPOSER_STUB_LOG" "--no-dev"
check "runs the webhook command on every site" [ "$(cat "$SITES"/*/public_html/.cmdlog 2>/dev/null | grep -c set_example_connector_webhook_default)" -eq 3 ]
check "no backup folders left behind"         [ -z "$(ls -A "$SITES/legacy/public_html/wp-content/plugins" | grep '^\.')" ]

echo "wp-install-example-connector: automatic rollback"
new_fixture
old="$SITES/legacy/public_html/wp-content/plugins/example-Connector"
mkdir -p "$old"; echo "old-version" > "$old/plugin.php"; touch "$SITES/legacy/public_html/.active/example-Connector"
touch "$SITES/legacy/public_html/.fail_cmd"
run wp-install-example-connector --yes
check "exits 1 when the post-command fails"   rc_is 1
check "names the failed app"                  out_has "Failed apps: legacy"
check "restores the previous plugin files"    file_has legacy/public_html/wp-content/plugins/example-Connector/plugin.php "old-version"
check "re-activates the previous plugin"      exists legacy/public_html/.active/example-Connector
check "other sites still get the new version" file_has modern/public_html/wp-content/plugins/example-Connector/plugin.php "new-version"
run wp-install-example-connector --dry-run
check "dry run mentions composer"             out_has "composer install"

echo "wp-optimize-wordfence-notifications / wp-fix-number-flipper"
new_fixture
run wp-optimize-wordfence-notifications --yes
check "deploys the scripts plugin"            exists modern/public_html/wp-content/plugins/example-wordpress-scripts/plugin.php
check "runs optimize_wordfence_notifications" file_has modern/public_html/.cmdlog "optimize_wordfence_notifications"
new_fixture
run wp-fix-number-flipper --yes
check "runs fix_number_flipper"               file_has modern/public_html/.cmdlog "fix_number_flipper"
check "fix_number_flipper exits 0"            rc_is 0

echo "wp-enable-user-registration"
new_fixture
echo "administrator" > "$SITES/legacy/public_html/.opt_default_role"
run wp-enable-user-registration --dry-run
check "dry run changes nothing"               missing modern/public_html/.opt_users_can_register
run wp-enable-user-registration --yes
check "exits 0"                               rc_is 0
check "enables registration"                  file_has modern/public_html/.opt_users_can_register "1"
check "installs the anti-spam plugin"         exists modern/public_html/wp-content/plugins/disable-wp-registration-page-spam
check "activates the anti-spam plugin"        exists modern/public_html/.active/disable-wp-registration-page-spam
check "warns about a risky default role"      out_has "default_role is 'administrator'"

echo "wp-plugin-bulk-command"
new_fixture
run wp-plugin-bulk-command
check "no subcommand exits 2"                 rc_is 2
run wp-plugin-bulk-command --dry-run update --all
check "dry run does not run the command"      log_lacks "$WP_STUB_LOG" "plugin update --all"
run wp-plugin-bulk-command list
check "read-only command needs no --yes"      rc_is 0
check "read-only command runs"                log_has "$WP_STUB_LOG" "plugin list"
check "read-only command does not purge"      missing modern/public_html/.purged
: > "$WP_STUB_LOG"
run wp-plugin-bulk-command --dry-run list
check "read-only command runs even in dry run" log_has "$WP_STUB_LOG" "plugin list"
run wp-plugin-bulk-command update --all
check "mutating command needs --yes"         rc_is 1
run wp-plugin-bulk-command --yes update --all
check "mutating command runs"                 log_has "$WP_STUB_LOG" "plugin update --all"
check "...then purges Breeze"                 exists modern/public_html/.purged
rm -f "$SITES"/*/public_html/.purged
run wp-plugin-bulk-command --yes --no-purge update --all
check "--no-purge skips the purge"            missing modern/public_html/.purged
run wp-plugin-bulk-command --yes -- update --all
check "-- separates options from wp args"     rc_is 0

echo "wp-option-bulk-command"
new_fixture
run wp-option-bulk-command --yes update blogdescription "Hello there"
check "updates the option on every site"      file_has modern/public_html/.opt_blogdescription "Hello there"
check "...then purges Breeze"                 exists modern/public_html/.purged
run wp-option-bulk-command get blogdescription
check "get is read-only and needs no --yes"   rc_is 0
check "get prints the value"                  out_has "Hello there"
run wp-option-bulk-command --force get x
check "unsupported flag is rejected"          rc_is 2

echo
echo "Passed: $PASS   Failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
