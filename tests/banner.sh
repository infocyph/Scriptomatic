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
assert_contains "$out" '| Hello 🌍 |' "original three-row description middle"
assert_contains "$out" '+' "original description top/bottom borders"
assert_not_file "$work/chromacat-called"
pass "NO_COLOR/non-TTY keeps the original inner banner layout without invoking chromacat"

out="$(PATH="$work/bin:$PATH" bash "$ROOT/bash/banner.sh" '')"
assert_contains "$out" '| DESCRIBE |' "empty argument preserves original DESCRIBE fallback"
pass "empty description preserves original default label"

source_text="$(cat "$ROOT/bash/banner.sh")"
assert_contains "$source_text" 'Where sharing sparks growth.' "full original credit pool"
assert_contains "$source_text" 'parchment' "original parchment box style"
assert_contains "$source_text" 'html' "original html box style"
pass "banner credit and ChromaCat style pools are preserved"

# If util-linux script is available, allocate a pseudo-TTY and prove a failing
# chromacat falls back to the same original plain layout rather than breaking shell startup.
if command -v script >/dev/null 2>&1; then
  rm -f "$work/chromacat-called"
  tty_out="$(script -qec "PATH='$work/bin:$PATH' bash '$ROOT/bash/banner.sh' 'TTY fallback'" /dev/null | tr -d '\r')"
  assert_file "$work/chromacat-called"
  assert_contains "$tty_out" '| TTY fallback |' "TTY original-layout fallback"
  pass "failing chromacat cannot break the original TTY banner presentation"
fi
