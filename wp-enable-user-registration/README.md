# wp-enable-user-registration

> Turn on user registration on every WordPress site, protected by an anti-spam plugin.

*Replaces the original `fix.sh`.*

## What it does

For each site:

1. Installs the `disable-wp-registration-page-spam` plugin from WordPress.org (skipped if already present).
2. Activates it.
3. Sets the `users_can_register` option to `1`.
4. Warns if the site's default role for new users is anything other than `subscriber`.

If any step fails, the remaining steps for that site don't run. A site is never left with open registration but no spam protection.

## Requirements

- Master-user SSH access and WP-CLI
- Outbound access to wordpress.org (to install the plugin)

## Usage

```bash
cd wp-enable-user-registration
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
2026-11-02 10:02:44 [INFO ] Processing 2 WordPress site(s)
2026-11-02 10:02:44 [INFO ] [kqzmvtxjdn] Working on https://client-one.com
Success: Installed 'disable-wp-registration-page-spam'.
Success: Plugin 'disable-wp-registration-page-spam' activated.
Success: Updated 'users_can_register' option.
2026-11-02 10:02:49 [INFO ] [rwbfhgycla] Working on https://client-two.com
2026-11-02 10:02:49 [INFO ] [rwbfhgycla] 'disable-wp-registration-page-spam' is already installed
Success: Plugin 'disable-wp-registration-page-spam' activated.
Success: Updated 'users_can_register' option.
2026-11-02 10:02:50 [WARN ] [rwbfhgycla] default_role is 'editor', not 'subscriber'. New registrants will get that role!
2026-11-02 10:02:50 [INFO ] Summary: 2 done, 0 skipped, 0 failed
```

## Security note

Open registration lets anyone create an account. The anti-spam plugin helps with bots, but the **default role** decides what those accounts can do. Treat any `default_role` warning from this script as something to fix.

## What changed from `fix.sh`

- Skips the install when the plugin is already there, so re-running is clean.
- Stops a site's remaining steps if one fails.
- Added the default-role warning, `--dry-run`, `--app`, a confirmation prompt, per-site failure isolation and a summary.
