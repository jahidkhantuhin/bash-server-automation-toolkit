# wp-install-example-connector

> Install or update the **example-Connector** plugin on every site and set its default webhook.

*Replaces the original `install_1.sh`.*

## What it does

1. Clones `example/example-Connector` **once** and runs `composer install` **once**.
2. For each site:
   1. Deactivates the existing plugin (if active).
   2. Moves the old version aside and swaps in the freshly built one.
   3. Activates it and runs `wp set_example_connector_webhook_default`.
3. If any step fails on a site, the **previous version is restored** and re-activated, so the site is never left without its connector.

## Requirements

- Master-user SSH access, WP-CLI, `git`, `composer`
- A `GITHUB_TOKEN` that can read the repo (see the [root README](../README.md#security))

## Usage

```bash
cd wp-install-example-connector
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

Composer flags can be overridden through the environment:

```bash
COMPOSER_FLAGS="--no-interaction --prefer-dist" ./run.sh   # keep dev dependencies, like the old script
```

## Example output

```
2026-11-02 09:31:02 [INFO ] Cloning example/example-Connector (once; reused for every site)
2026-11-02 09:31:05 [INFO ] Installing PHP dependencies (once)
2026-11-02 09:31:19 [INFO ] Processing 2 WordPress site(s)
2026-11-02 09:31:19 [INFO ] [kqzmvtxjdn] Working on https://client-one.com
Success: Plugin 'example-Connector' deactivated.
Success: Plugin 'example-Connector' activated.
Success: set_example_connector_webhook_default done.
2026-11-02 09:31:21 [INFO ] [kqzmvtxjdn] Deployed 'example-Connector' and ran: wp set_example_connector_webhook_default
2026-11-02 09:31:21 [INFO ] Summary: 2 done, 0 skipped, 0 failed
```

## What changed from `install_1.sh`

- **Removed a hardcoded GitHub token** (it was in the script and in every site's `.git/config`). It now comes from `GITHUB_TOKEN`.
- **No more "delete first, clone second".** The original ran `rm -rf` on the plugin *before* cloning, so a network or token failure left every site without the connector. Now the old version is only removed after the new one works.
- **Builds once, not per site.** One clone and one `composer install`, then a copy to each site. Faster, and every site gets an identical build.
- `composer install` now defaults to production flags (`--no-dev --optimize-autoloader`). If the plugin needs its dev packages at runtime, set `COMPOSER_FLAGS` as shown above.
- Failures are isolated per site, with a summary and exit code.
