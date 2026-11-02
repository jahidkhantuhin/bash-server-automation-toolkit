# wp-plugin-bulk-command

> Run any `wp plugin` command on every WordPress site, then purge the Breeze cache.

*Replaces the original `script_44e708.sh`.*

## What it does

Everything after the options is handed to `wp plugin`, on every site:

1. Runs `wp plugin <your command>` on each site.
2. Purges the Breeze cache (if Breeze is active there).

**Read-only commands** (`list`, `get`, `status`, `is-active`, `is-installed`, `path`, `search`, `verify-checksums`) run immediately: no confirmation, no cache purge, and they still run during `--dry-run`.

## Requirements

- Master-user SSH access and WP-CLI

## Usage

Put this script's options **before** the WP-CLI subcommand:

```bash
cd wp-plugin-bulk-command

bash ./run.sh list                              # read-only, runs right away
bash ./run.sh --dry-run update --all            # preview
bash ./run.sh --yes update --all                # update every plugin everywhere
bash ./run.sh --yes deactivate hello-dolly
bash ./run.sh --yes --no-purge install akismet --activate
bash ./run.sh --app abcdefghij update --all     # one site only
bash ./run.sh --yes -- update --all             # "--" also separates the two
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
$ bash ./run.sh --yes update --all
2026-11-02 10:15:30 [INFO ] Processing 2 WordPress site(s)
2026-11-02 10:15:30 [INFO ] [kqzmvtxjdn] Working on https://client-one.com
Success: Plugins updated.
2026-11-02 10:15:41 [INFO ] [kqzmvtxjdn] Purging Breeze cache
Success: Cache purged.
2026-11-02 10:15:42 [INFO ] [rwbfhgycla] Working on https://client-two.com
Success: Plugins updated.
2026-11-02 10:15:51 [INFO ] [rwbfhgycla] Breeze is not active, no cache to purge
2026-11-02 10:15:51 [INFO ] Summary: 2 done, 0 skipped, 0 failed
```

## Notes

- This runs whatever WP-CLI command you give it, on every site, so `delete` and `uninstall` really do delete. Use `--dry-run` and `--app` first.
- Anything after the subcommand goes straight to WP-CLI. For example, `update --all --dry-run` passes WP-CLI's own `--dry-run`, not this script's.

## What changed from `script_44e708.sh`

- The original purged the cache even after read-only commands like `list`. Now it doesn't.
- Added a confirmation prompt, `--dry-run`, `--app`, `--no-purge`, per-site failure isolation, a summary and exit codes.
- Skips non-WordPress apps and sites without Breeze instead of printing errors.
- Quotes every path (the original `cd $SITE_DIR` could run commands in the wrong folder if the `cd` failed).
