#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h}
target="$HOME/.local/bin/geeklets"
source_dir="$repo_root/geeklets"
backup="$HOME/.local/bin/geeklets.backup.$(date +%Y%m%d-%H%M%S)"

if [[ ! -d "$source_dir" ]]; then
  echo "Missing repo geeklets directory: $source_dir" >&2
  exit 1
fi

mkdir -p "${target:h}"

if [[ -L "$target" ]]; then
  current_target=$(readlink "$target")
  if [[ "$current_target" == "$source_dir" ]]; then
    echo "Geeklets already point to repo: $source_dir"
    exit 0
  fi
fi

if [[ -e "$target" ]]; then
  mv "$target" "$backup"
  echo "Backed up existing geeklets to: $backup"
fi

ln -s "$source_dir" "$target"
echo "GeekTool geeklets now point to: $source_dir"
