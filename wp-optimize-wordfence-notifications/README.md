# wp-optimize-wordfence-notifications

> Deploy the `wordpress-scripts` plugin on every site and optimize its Wordfence notifications.

*Replaces the original `script_1.sh`.*

## What it does

1. Clones `${GITHUB_ORG}/wordpress-scripts` **once**.
2. For each site: swaps the plugin in (keeping the old version until the end), activates it, then runs `wp optimize_wordfence_notifications`.
3. If any step fails on a site, the previous version is restored.

## Requirements

- Master-user SSH access, WP-CLI, `git`
- A `GITHUB_TOKEN` that can read the repo (see the [root README](../README.md#security))
- The Wordfence plugin on the target sites

## Usage

```bash
cd wp-optimize-wordfence-notifications
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
2026-11-02 09:40:01 [INFO ] Cloning ${GITHUB_ORG}/wordpress-scripts (once; reused for every site)
2026-11-02 09:40:03 [INFO ] Processing 2 WordPress site(s)
2026-11-02 09:40:03 [INFO ] [kqzmvtxjdn] Working on https://client-one.com
Success: Plugin 'wordpress-scripts' activated.
Success: optimize_wordfence_notifications done.
2026-11-02 09:40:05 [INFO ] [kqzmvtxjdn] Deployed 'wordpress-scripts' and ran: wp optimize_wordfence_notifications
2026-11-02 09:40:05 [INFO ] Summary: 2 done, 0 skipped, 0 failed
```

## What changed from `script_1.sh`

- The original's banner said "Testing WP Plugin Install", which looks like a leftover from a template. The script is now named for what it actually does.
- **Removed a hardcoded GitHub token** (see the [root README](../README.md#security)).
- **Rollback instead of delete-first.** The original removed the plugin before cloning, so a failed clone left the site without it.
- Clones once instead of per site, isolates failures per site, and adds `--dry-run`, `--app` and a summary.

> This plugin is shared with [`wp-fix-number-flipper`](../wp-fix-number-flipper). Each script redeploys the latest version and then runs its own command.
