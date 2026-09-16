#!/usr/bin/env bash
set -Eeuo pipefail

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

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_not_file() {
  [[ ! -e "$1" ]] || fail "unexpected path exists: $1"
}

assert_contains() {
  local haystack="$1" needle="$2" message="${3:-missing expected text}"
  [[ "$haystack" == *"$needle"* ]] || fail "$message: $needle"
}

assert_not_contains() {
  local haystack="$1" needle="$2" message="${3:-unexpected text present}"
  [[ "$haystack" != *"$needle"* ]] || fail "$message: $needle"
}

assert_success() {
  "$@" || fail "command failed: $*"
}

assert_failure() {
  if "$@"; then
    fail "command unexpectedly succeeded: $*"
  fi
}
