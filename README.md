# GeekTool config backup

This repository tracks the GeekTool setup currently used on this Mac.

## What is stored here

- `geeklets/`: shell scripts and HTML files referenced by GeekTool
- `exports/preferences/`: exported GeekTool preference plists in XML format
- `exports/plugins/`: copied `GeekTool Plugins` directory contents
- `scripts/`: helper scripts for syncing and optionally switching GeekTool to the repo-managed files

## Sync the latest local state

```sh
./scripts/sync_geektool.sh
```

This exports:

- `org.tynsoe.geektool3`
- `org.tynsoe.geeklet.shell`
- `org.tynsoe.geeklet.web`
- `org.tynsoe.GeekTool`

and copies the current `~/.local/bin/geeklets` files plus installed GeekTool plugins.

## Optional: make GeekTool read files from this repo

Right now GeekTool is still reading files from `~/.local/bin/geeklets`.
If you want the repo files to become the live source, run:

```sh
./scripts/install_repo_symlinks.sh
```

That script backs up `~/.local/bin/geeklets` and replaces it with a symlink to this repository's `geeklets/` directory.
