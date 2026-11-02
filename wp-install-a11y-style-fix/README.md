# wp-install-a11y-style-fix

> Install the `accessibility-style-fix` plugin on sites that use a legacy or broken theme.

*Replaces the original `install.sh`.*

## What it does

1. Reads each site's active theme.
2. If the theme is a **legacy theme** (`leadhubtheme` or `onepageextendedtheme`) or **no active theme can be found** (a defective theme), the site needs the fix. Every other site is skipped.
3. Clones `example/accessibility-style-fix` **once**, then copies it into each site that needs it.
4. Activates the plugin.

Sites where the plugin is already active are skipped, so the script is safe to run again.

## Requirements

- Master-user SSH access, WP-CLI, `git`
- A `GITHUB_TOKEN` that can read the repo (see the [root README](../README.md#security))

## Usage

```bash
cd wp-install-a11y-style-fix
./run.sh --dry-run          # see which sites would get the plugin
./run.sh --app abcdefghij   # try one site first
./run.sh                    # apply everywhere it's needed
```

## Options

| Option | Description |
|---|---|
| `--dry-run` | Show what would change; modify nothing |
| `--app NAME` | Only process this app folder (repeatable) |
| `--force` | Redeploy even if the plugin is already active |
| `-y`, `--yes` | Skip the confirmation prompt |
| `-h`, `--help` | Show help |

To change which themes count as legacy:

```bash
LEGACY_THEMES="leadhubtheme onepageextendedtheme oldtheme" ./run.sh --dry-run
```

## Example output

```
2026-11-02 09:20:11 [INFO ] Cloning example/accessibility-style-fix (once; reused for every site)
2026-11-02 09:20:13 [INFO ] Processing 3 WordPress site(s)
2026-11-02 09:20:13 [INFO ] [kqzmvtxjdn] Working on https://client-one.com
2026-11-02 09:20:14 [INFO ] [kqzmvtxjdn] Active theme 'leadhubtheme' is a legacy theme
Success: Plugin 'accessibility-style-fix' activated.
2026-11-02 09:20:15 [INFO ] [kqzmvtxjdn] Deployed 'accessibility-style-fix'
2026-11-02 09:20:15 [INFO ] [rwbfhgycla] Working on https://client-two.com
2026-11-02 09:20:16 [INFO ] [rwbfhgycla] Active theme 'astra' is current, no fix needed
2026-11-02 09:20:16 [INFO ] Summary: 1 done, 2 skipped, 0 failed
```

## What changed from `install.sh`

- **Removed a hardcoded GitHub token.** The original embedded it in the script and in the clone URL, which also saved it in every site's `.git/config`. The token now comes from `GITHUB_TOKEN` and never touches a URL.
- **Safe to re-run.** The original failed with "destination path already exists" on sites that already had the plugin.
- **Clones once** instead of once per site, and fails before touching anything if GitHub can't be reached.
- Removed `--ignore-plugins --ignore-themes`, which aren't WP-CLI options.
- The legacy theme list is configurable, paths are quoted, and failures are isolated per site.
