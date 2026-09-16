#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"

cat > "$work/bin/chromacat" <<EOF_CHROMA
#!/usr/bin/env sh
printf called > '$work/chromacat-called'
exit 1
EOF_CHROMA
chmod +x "$work/bin/chromacat"

out="$(NO_COLOR=1 PATH="$work/bin:$PATH" bash "$ROOT/bash/banner.sh" 'Hello 🌍')"
assert_contains "$out" 'INFOCYPH' "plain heading"
assert_contains "$out" 'Hello 🌍' "Unicode description"
assert_not_file "$work/chromacat-called"
pass "NO_COLOR/non-TTY path stays plain and does not invoke chromacat"

out="$(PATH="$work/bin:$PATH" bash "$ROOT/bash/banner.sh" '')"
assert_contains "$out" 'INFOCYPH' "empty description heading"
pass "empty description renders safely without presentation dependency"

# If util-linux script is available, allocate a pseudo-TTY and prove a failing chromacat falls back to plain output.
if command -v script >/dev/null 2>&1; then
  rm -f "$work/chromacat-called"
  tty_out="$(script -qec "PATH='$work/bin:$PATH' bash '$ROOT/bash/banner.sh' 'TTY fallback'" /dev/null | tr -d '\r')"
  assert_file "$work/chromacat-called"
  assert_contains "$tty_out" 'TTY fallback' "TTY plain fallback"
  pass "failing chromacat cannot break TTY banner output"
fi
