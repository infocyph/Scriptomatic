#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/fake"
cat >"$tmp/fake/figlet" <<'EOF'
#!/usr/bin/env bash
printf 'INFOCYPH\n'
EOF
chmod +x "$tmp/fake/figlet"
output="$(PATH="$tmp/fake:/usr/bin:/bin" bash "$ROOT/bash/banner.sh" 'Demo Service')"
[[ "$output" == *INFOCYPH* ]] || fail 'banner lost INFOCYPH title'
[[ "$output" == *'Demo Service'* ]] || fail 'banner lost description'
cat >"$tmp/fake/figlet" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
output="$(PATH="$tmp/fake:/usr/bin:/bin" bash "$ROOT/bash/banner.sh" 'Fallback')"
[[ "$output" == *INFOCYPH* && "$output" == *Fallback* ]] || fail 'banner fallback failed'
pass 'banner presentation fallback contract'
