# wp-fix-number-flipper

> Deploy the `example-wordpress-scripts` plugin on every site and run its Number Flipper fix.

*Replaces the original `fix_flipper.sh`.*

## What it does

1. Clones `example/example-wordpress-scripts` **once**.
2. For each site: swaps the plugin in (keeping the old version until the end), activates it, then runs `wp fix_number_flipper`.
3. If any step fails on a site, the previous version is restored.

## Requirements

- Master-user SSH access, WP-CLI, `git`
- A `GITHUB_TOKEN` that can read the repo (see the [root README](../README.md#security))

## Usage

```bash
cd wp-fix-number-flipper
./run.sh --dry-run
./run.sh --app abcdefghij   # one site first
./run.sh
```

## Options

| Option | Description |
|---|---|
| `--dry-run` | Show what would change; modify nothing |
| `--app NAME` | Only process this app folder (repeatable) |
| `-y`, `--yes` | Skip the confirmation prompt |
| `-h`, `--help` | Show help |

## Example output

```
2026-11-02 09:48:10 [INFO ] Cloning example/example-wordpress-scripts (once; reused for every site)
2026-11-02 09:48:12 [INFO ] Processing 2 WordPress site(s)
2026-11-02 09:48:12 [INFO ] [kqzmvtxjdn] Working on https://client-one.com
Success: Plugin 'example-wordpress-scripts' activated.
Success: fix_number_flipper done.
2026-11-02 09:48:14 [INFO ] [kqzmvtxjdn] Deployed 'example-wordpress-scripts' and ran: wp fix_number_flipper
2026-11-02 09:48:14 [INFO ] Summary: 2 done, 0 skipped, 0 failed
```

## What changed from `fix_flipper.sh`

- **Removed a hardcoded GitHub token** (see the [root README](../README.md#security)).
- **Rollback instead of delete-first.** The original removed the plugin before cloning, so a failed clone left the site without it.
- Clones once instead of per site, isolates failures per site, and adds `--dry-run`, `--app` and a summary.

> This plugin is shared with [`wp-optimize-wordfence-notifications`](../wp-optimize-wordfence-notifications). Each script redeploys the latest version and then runs its own command.
