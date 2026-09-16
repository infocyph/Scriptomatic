#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

assert_eq() {
  local expected="$1" actual="$2" message="${3:-values differ}"
  [[ "$actual" == "$expected" ]] || fail "$message (expected='$expected' actual='$actual')"
}

assert_file_exists() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_executable() {
  [[ -x "$1" ]] || fail "expected executable: $1"
}

assert_contains() {
  local file="$1" needle="$2"
  grep -Fq -- "$needle" "$file" || fail "$file does not contain: $needle"
}

assert_not_contains() {
  local file="$1" needle="$2"
  if grep -Fq -- "$needle" "$file"; then
    fail "$file unexpectedly contains: $needle"
  fi
}

assert_success() {
  "$@" || fail "command failed: $*"
}
