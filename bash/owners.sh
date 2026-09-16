#!/usr/bin/env bash
set -euo pipefail

command -v git >/dev/null 2>&1 || {
  echo "Error: git is not installed!" >&2
  exit 127
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: Not a git repository!" >&2
  exit 1
}

if ! git fame --help >/dev/null 2>&1; then
  echo "Error: git-fame is not installed!" >&2
  exit 127
fi

while IFS= read -r -d '' file; do
  printf '%s ' "$file"
  git fame -esnwMC --incl "$file" \
    | tr '/' '|' \
    | awk -F '|' '(NR>6 && $6>=30) {print $2}' \
    | paste -sd ' ' -
  printf '\n'
done < <(git ls-files -z)
