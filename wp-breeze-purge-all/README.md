# wp-breeze-purge-all

> Purge the Breeze cache on every WordPress site on a Cloudways server.

*Replaces the original `script.sh`.*

## What it does

1. Finds every WordPress app under the applications folder.
2. Skips sites where Breeze isn't active.
3. Runs `wp breeze purge --cache=all` on the rest.
4. Prints a summary.

Purging a cache is harmless, so this script does not ask for confirmation.

## Requirements

- Master-user SSH access on the Cloudways server
- WP-CLI
- The Breeze plugin on the sites you want purged

## Usage

```bash
cd wp-breeze-purge-all
./run.sh --dry-run        # preview
./run.sh                  # purge everywhere
./run.sh --app abcdefghij # purge one app only
```

## Options

| Option | Description |
|---|---|
| `--dry-run` | Show what would be purged; purge nothing |
| `--app NAME` | Only process this app folder (repeatable) |
| `-h`, `--help` | Show help |

## Example output

```
2026-11-02 09:14:07 [INFO ] [staging-static] Not a WordPress app, skipping
2026-11-02 09:14:07 [INFO ] Processing 3 WordPress site(s)
2026-11-02 09:14:07 [INFO ] [kqzmvtxjdn] Working on https://client-one.com
2026-11-02 09:14:08 [INFO ] [kqzmvtxjdn] Purging Breeze cache
Success: Cache purged.
2026-11-02 09:14:09 [INFO ] [rwbfhgycla] Working on https://client-two.com
2026-11-02 09:14:09 [INFO ] [rwbfhgycla] Breeze is not active, skipping
2026-11-02 09:14:09 [INFO ] Summary: 1 done, 2 skipped, 0 failed
```

## What changed from `script.sh`

- Skips apps that aren't WordPress and sites without Breeze, instead of printing errors.
- Quotes every path. The original `cd $SITE_DIR` ran later commands in the *wrong folder* if the `cd` failed.
- One failing site no longer affects the rest; a summary and exit code report the result.
- Added `--dry-run` and `--app`.

> Looking for the version that deletes the cache folder from disk instead? That's `wp-breeze-cache-clear` in the Node.js toolkit. This one uses Breeze's own purge command.
