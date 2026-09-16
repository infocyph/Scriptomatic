#!/usr/bin/env bash
set -Eeuo pipefail

command -v git >/dev/null 2>&1 || { printf 'owners: git not found\n' >&2; exit 127; }
command -v git-fame >/dev/null 2>&1 || { printf 'owners: git-fame not found\n' >&2; exit 127; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf 'owners: not inside a git repository\n' >&2; exit 1; }

owners_for_file() {
  local file="$1"
  git fame -esnwMC --incl "$file" 2>/dev/null |
    tr '/' '|' |
    awk -F '|' '
      NR > 6 && ($6 + 0) >= 30 {
        owner=$2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", owner)
        if (owner != "") {
          if (out != "") out=out " "
          out=out owner
        }
      }
      END { print out }
    '
}

while IFS= read -r -d '' file; do
  owners="$(owners_for_file "$file")"
  display="$file"
  display="${display//$'\n'/\\n}"
  display="${display//$'\t'/\\t}"
  printf '%s %s\n' "$display" "$owners"
done < <(git ls-files -z)
