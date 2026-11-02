# bash-server-automation-toolkit

> Safe, repeatable Bash tools for running one job across **every WordPress site on a Cloudways server**.

![Bash](https://img.shields.io/badge/Bash-4.4%2B-4EAA25?logo=gnubash&logoColor=white)
![WP-CLI](https://img.shields.io/badge/requires-WP--CLI-0073aa?logo=wordpress&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Cloudways-1d4ed8)
![Scripts](https://img.shields.io/badge/scripts-8-informational)

---

## Overview

Each folder is one focused script. They all share a small library (`lib/common.sh`) that gives every script the same safe behavior:

- **Finds the sites for you.** Walks `/home/master/applications/<app>/public_html` and ignores anything that isn't WordPress.
- **Previews before changing.** `--dry-run` shows exactly what would happen.
- **Asks before changing sites.** A confirmation prompt (skip it with `--yes`).
- **Isolates failures.** One broken site never stops the others; you get a summary and a proper exit code.
- **Handles secrets properly.** The GitHub token lives in your environment or an untracked `.env`, never in code, in `ps`, or in any site's `.git/config`.
- **Rolls back failed plugin deploys.** The old version is restored if anything goes wrong.

## Scripts

| Folder | What it does | Replaces |
|---|---|---|
| [`wp-breeze-purge-all`](wp-breeze-purge-all) | Purges the Breeze cache on every site | `script.sh` |
| [`wp-install-a11y-style-fix`](wp-install-a11y-style-fix) | Installs the accessibility style fix plugin on sites with a legacy or defective theme | `install.sh` |
| [`wp-install-example-connector`](wp-install-example-connector) | Installs or updates the example Connector plugin and sets its default webhook | `install_1.sh` |
| [`wp-optimize-wordfence-notifications`](wp-optimize-wordfence-notifications) | Deploys example-wordpress-scripts and optimizes Wordfence notifications | `script_1.sh` |
| [`wp-fix-number-flipper`](wp-fix-number-flipper) | Deploys example-wordpress-scripts and fixes the Number Flipper | `fix_flipper.sh` |
| [`wp-enable-user-registration`](wp-enable-user-registration) | Enables user registration, protected by an anti-spam plugin | `fix.sh` |
| [`wp-plugin-bulk-command`](wp-plugin-bulk-command) | Runs any `wp plugin` command on every site, then purges Breeze | `script_44e708.sh` |
| [`wp-option-bulk-command`](wp-option-bulk-command) | Runs any `wp option` command on every site, then purges Breeze | `script_1dbafb.sh` |

## Requirements

- A Cloudways server, with SSH access as the **master user** (not root)
- [WP-CLI](https://wp-cli.org) as `wp` (preinstalled on Cloudways)
- Bash 4.4 or newer
- `git` and a GitHub token, for the scripts that clone private repos
- `composer`, for `wp-install-example-connector`

## Quick start

```bash
git clone https://github.com/<your-username>/bash-server-automation-toolkit.git
cd bash-server-automation-toolkit

# Only needed for scripts that clone private repos
cp .env.example .env && chmod 600 .env
nano .env                     # paste your GITHUB_TOKEN

# Always preview first
./wp-install-example-connector/run.sh --dry-run

# Then run for real
./wp-install-example-connector/run.sh
```

Keep a record of any run with:

```bash
./wp-breeze-purge-all/run.sh 2>&1 | tee breeze-purge.log
```

## Common options

Every script supports these (some add a few of their own; see each README):

| Option | Description |
|---|---|
| `--dry-run` | Show what would change; modify nothing |
| `--app NAME` | Only process this app folder. Repeat it for several apps. Handy for a first test on one site |
| `-y`, `--yes` | Don't ask for confirmation before changing sites |
| `-h`, `--help` | Show help for that script |

## Configuration

Settings come from environment variables, or from an untracked `.env` file in the repo root (see `.env.example`). Real environment variables always win over `.env`.

| Variable | Used by | Default | Description |
|---|---|---|---|
| `GITHUB_TOKEN` | scripts that clone private repos | none | Read-only token for the example repos |
| `APPS_ROOT` | all | `/home/master/applications` | Where the apps live |
| `COMPOSER_FLAGS` | `wp-install-example-connector` | `--no-dev --no-interaction --prefer-dist --optimize-autoloader` | Flags for `composer install` |
| `LEGACY_THEMES` | `wp-install-a11y-style-fix` | `leadhubtheme onepageextendedtheme` | Space-separated theme slugs that count as legacy |
| `ALLOW_ROOT` | all | unset | Escape hatch used by the test suite; don't set it on a server |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Finished with no failures (skipped sites are fine) |
| `1` | At least one site failed, or a fatal error or aborted confirmation |
| `2` | Invalid usage, such as an unknown option |

## Security

- **Tokens never go in code.** The original scripts embedded a GitHub personal access token in the source and in every clone URL. Cloning that way also wrote the token into `.git/config` in each site's plugin folder. These scripts pass the token to git through its credential helper instead, so the clone URL stays clean.
- **Revoke any token that was ever pasted into a script, chat or repo,** and create a fine-grained token with read-only access to just the three repositories listed in `.env.example`.
- `.env` is git-ignored, and the scripts warn if its permissions are looser than `600`.
- Scripts refuse to run as root.

## How it works

```
parse options → preflight checks → find WordPress apps → confirm
      → (one-time setup, e.g. clone a private repo once)
      → for each site, in its own subshell:  run the script's process_site()
      → summary + exit code
```

Per site, a script's `process_site()` ends with one of three outcomes: done, skipped (nothing to do), or failed. Inside it, any failing command stops that site's remaining steps, and the run carries on with the next site.

## Repository structure

```
bash-server-automation-toolkit/
├── lib/
│   └── common.sh                 # shared library
├── wp-breeze-purge-all/          # each folder: run.sh + README.md
├── wp-install-a11y-style-fix/
├── wp-install-example-connector/
├── wp-optimize-wordfence-notifications/
├── wp-fix-number-flipper/
├── wp-enable-user-registration/
├── wp-plugin-bulk-command/
├── wp-option-bulk-command/
├── tests/
│   ├── run-tests.sh              # offline test suite
│   └── stubs/                    # fake wp, git, composer
├── .github/workflows/ci.yml
├── .env.example
├── .gitignore
└── README.md
```

## Testing

The suite runs every script against fake `wp`, `git` and `composer` binaries and a fake applications folder, so it needs no server, network or token:

```bash
./tests/run-tests.sh
```

It covers dry runs, confirmation, failure isolation, the token never appearing in git's arguments or `.git/config`, rollback of a failed deploy, and the read-only shortcuts in the bulk-command scripts. CI runs it together with ShellCheck on every push.

> The suite proves the logic and the safety behavior. It cannot prove how your real sites, plugins and WP-CLI version respond, which is why `--dry-run` and `--app` exist: try one site first.

## Adding a new script

Create a folder with a `run.sh` shaped like this:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

SCRIPT_NAME="wp-my-task"
SCRIPT_SUMMARY="One line describing what it does."
SCRIPT_USAGE="./run.sh [options]"

process_site() {
  # Runs inside the site's public_html. Use `mutate` for anything that changes state.
  mutate wp option update blogdescription "Hello"
}

parse_args "$@"
no_extra_args
preflight
for_each_wp_site process_site
exit $?
```

Then add a README, a test in `tests/run-tests.sh`, and a row in the table above.
