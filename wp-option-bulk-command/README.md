# wp-option-bulk-command

> Run any `wp option` command on every WordPress site, then purge the Breeze cache.

*Replaces the original `script_1dbafb.sh`.*

## What it does

Everything after the options is handed to `wp option`, on every site:

1. Runs `wp option <your command>` on each site.
2. Purges the Breeze cache (if Breeze is active there).

**Read-only commands** (`get`, `list`, `pluck`) run immediately: no confirmation, no cache purge, and they still run during `--dry-run`.

## Requirements

- Master-user SSH access and WP-CLI

## Usage

Put this script's options **before** the WP-CLI subcommand:

```bash
cd wp-option-bulk-command

./run.sh get blogname                                  # read it on every site
./run.sh --dry-run update blogdescription "New tagline"
./run.sh --yes update blogdescription "New tagline"
./run.sh --yes --no-purge update timezone_string "Asia/Dhaka"
./run.sh --app abcdefghij --yes update admin_email you@example.com
```

## Options

| Option | Description |
|---|---|
| `--dry-run` | Show the commands that would run; run nothing (read-only commands still run) |
| `--app NAME` | Only process this app folder (repeatable) |
| `--no-purge` | Don't purge the Breeze cache afterwards |
| `-y`, `--yes` | Skip the confirmation prompt |
| `-h`, `--help` | Show help |

## Example output

```
$ ./run.sh --yes update blogdescription "New tagline"
2026-11-02 10:24:05 [INFO ] Processing 2 WordPress site(s)
2026-11-02 10:24:05 [INFO ] [kqzmvtxjdn] Working on https://client-one.com
Success: Updated 'blogdescription' option.
2026-11-02 10:24:06 [INFO ] [kqzmvtxjdn] Purging Breeze cache
Success: Cache purged.
2026-11-02 10:24:06 [INFO ] [rwbfhgycla] Working on https://client-two.com
Success: Updated 'blogdescription' option.
2026-11-02 10:24:07 [INFO ] [rwbfhgycla] Breeze is not active, no cache to purge
2026-11-02 10:24:07 [INFO ] Summary: 2 done, 0 skipped, 0 failed
```

## Notes

- Options change live site settings, so try `--dry-run` and `--app` first.
- To change only the admin email on every site, the Node.js toolkit has a dedicated tool, `wp-mailshift`, with its own dry run and per-site report.

## What changed from `script_1dbafb.sh`

- The original purged the cache even after read-only commands like `get`. Now it doesn't.
- Added a confirmation prompt, `--dry-run`, `--app`, `--no-purge`, per-site failure isolation, a summary and exit codes. Every log line now carries a timestamp, replacing the single start-time header.
- Skips non-WordPress apps and sites without Breeze instead of printing errors.
- Quotes every path (the original `cd $SITE_DIR` could run commands in the wrong folder if the `cd` failed).
