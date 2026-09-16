#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$ROOT/tests/lib/assert.sh"

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/home" "$work/bin"
bashrc="$work/home/.bashrc"
printf '# existing user content\n' > "$bashrc"
chmod 0640 "$bashrc"

BASHRC="$bashrc" HOME="$work/home" bash "$ROOT/bash/alias-maker.sh" >/dev/null
BASHRC="$bashrc" HOME="$work/home" bash "$ROOT/bash/alias-maker.sh" >/dev/null

assert_eq 1 "$(grep -c '^# >>> scriptomatic-aliases >>>$' "$bashrc")" "alias block count"
assert_eq 1 "$(grep -c '^# >>> scriptomatic-utils >>>$' "$bashrc")" "utility block count"
assert_eq 1 "$(grep -c '^alias g=\"git\"$' "$bashrc")" "git alias duplication"
assert_contains "$(cat "$bashrc")" '# existing user content' "existing bashrc content retained"
assert_eq 640 "$(stat -c '%a' "$bashrc")" "bashrc mode preservation"
pass "alias-maker is idempotent and preserves unmanaged content/mode"

cat > "$work/bin/lsd" <<'EOF_LSD'
#!/usr/bin/env sh
exit 0
EOF_LSD
chmod +x "$work/bin/lsd"
PATH="$work/bin:$PATH" BASHRC="$bashrc" HOME="$work/home" bash "$ROOT/bash/alias-maker.sh" >/dev/null
assert_eq 1 "$(grep -c '^alias l=\"lsd -l\"$' "$bashrc")" "lsd alias update"
assert_eq 1 "$(grep -c '^# >>> scriptomatic-aliases >>>$' "$bashrc")" "alias block remains singular after capability change"
pass "optional lsd capability updates the managed block cleanly"
