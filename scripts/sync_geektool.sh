#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
src_geeklets="$HOME/.local/bin/geeklets"
src_plugins="$HOME/Library/Application Support/GeekTool Plugins"

dest_geeklets="$repo_root/geeklets"
dest_prefs="$repo_root/exports/preferences"
dest_plugins="$repo_root/exports/plugins"

mkdir -p "$dest_geeklets" "$dest_prefs" "$dest_plugins"

if [[ -d "$src_geeklets" ]]; then
  rsync -a --delete "$src_geeklets"/ "$dest_geeklets"/
fi

if [[ -d "$src_plugins" ]]; then
  rsync -a --delete "$src_plugins"/ "$dest_plugins"/
fi

defaults export org.tynsoe.geektool3 "$dest_prefs/org.tynsoe.geektool3.plist"
defaults export org.tynsoe.geeklet.shell "$dest_prefs/org.tynsoe.geeklet.shell.plist"
defaults export org.tynsoe.geeklet.web "$dest_prefs/org.tynsoe.geeklet.web.plist"
defaults export org.tynsoe.GeekTool "$dest_prefs/org.tynsoe.GeekTool.plist"

for plist in "$dest_prefs"/*.plist; do
  plutil -convert xml1 "$plist"
done

printf 'Synced GeekTool files into %s\n' "$repo_root"
