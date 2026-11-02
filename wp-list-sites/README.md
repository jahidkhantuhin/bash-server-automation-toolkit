# wp-list-sites

Lists the blog name and site URL for each WordPress installation under
`APPS_ROOT` (default `/home/master/applications`). A site is included when
`public_html/wp-config.php` exists. Output is tab-separated.

## Requirements

- Bash 4.4 or newer
- WP-CLI available as `wp`
- Read access to the applications directory and WordPress sites

## Usage

```bash
bash ./wp-list-sites/run.sh
```

Set `APPS_ROOT` in the root `.env` file or environment to select another
applications directory. The script continues after an individual WP-CLI
failure and exits nonzero if any site could not be read.
