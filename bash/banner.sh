#!/usr/bin/env bash
set -Eeuo pipefail

DESCRIPTION="${1:-DESCRIBE}"
NO_COLOR_EFFECTIVE="${NO_COLOR:-}"

credits=(
  "Innovation at its core."
  "Powered by passion."
  "Crafting excellence."
  "Engineering the future."
  "Code with purpose."
  "Open source. Open minds."
  "Together, we build better."
  "By devs, for devs."
)
boxes=(default dashed dash2 round double heavy simple shell plus comment php chain)

credit="${credits[$RANDOM % ${#credits[@]}]}"
box="${boxes[$RANDOM % ${#boxes[@]}]}"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT INT TERM HUP
plain="$work/plain"
styled="$work/styled"

render_plain() {
  if command -v figlet >/dev/null 2>&1; then
    if ! figlet -f slant INFOCYPH > "$plain" 2>/dev/null; then
      printf 'INFOCYPH\n' > "$plain"
    fi
  else
    printf 'INFOCYPH\n' > "$plain"
  fi

  if [[ -n "$DESCRIPTION" ]]; then
    printf '\n[ %s ]\n' "$DESCRIPTION" >> "$plain"
  fi
  printf '%s\n' "$credit" >> "$plain"
}

render_plain

# Non-interactive output is intentionally stable/plain. NO_COLOR also disables styling.
if [[ ! -t 1 || -n "$NO_COLOR_EFFECTIVE" || ! -x "$(command -v chromacat 2>/dev/null || true)" ]]; then
  cat "$plain"
  exit 0
fi

if chromacat -b -B "$box" -O d < "$plain" > "$styled" 2>/dev/null; then
  cat "$styled"
else
  cat "$plain"
fi
