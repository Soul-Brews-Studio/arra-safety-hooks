#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/safety-check.sh"
TMP_ROOT="/tmp/arra-safety-hooks-tests"

failures=0

assert_exit_code() {
  local expected="$1"
  local repo_dir="$2"
  local label="$3"
  local actual
  set +e
  (
    cd "$repo_dir" || exit 99
    printf '%s\n' '{"tool_input":{"command":"git push origin main"}}' | "$HOOK" >/dev/null 2>&1
  )
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    echo "FAIL: $label (expected $expected, got $actual)"
    failures=$((failures + 1))
  else
    echo "PASS: $label"
  fi
}

if [ -z "$TMP_ROOT" ] || ! echo "$TMP_ROOT" | grep -qE '^/tmp/'; then
  echo "Refusing to delete unexpected TMP_ROOT: '$TMP_ROOT'"
  exit 1
fi
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT/non-oracle" "$TMP_ROOT/oracle" "$TMP_ROOT/no-origin"

git -C "$TMP_ROOT/non-oracle" init -q
git -C "$TMP_ROOT/non-oracle" remote add origin git@github.com:Soul-Brews-Studio/maw-js.git
assert_exit_code 2 "$TMP_ROOT/non-oracle" "non-oracle repo blocks direct main push"

git -C "$TMP_ROOT/oracle" init -q
git -C "$TMP_ROOT/oracle" remote add origin git@github.com:Soul-Brews-Studio/xiaoer-oracle.git
assert_exit_code 0 "$TMP_ROOT/oracle" "oracle SSH remote allows direct main push"
git -C "$TMP_ROOT/oracle" remote set-url origin https://github.com/Soul-Brews-Studio/xiaoer-oracle.git
assert_exit_code 0 "$TMP_ROOT/oracle" "oracle HTTPS remote allows direct main push"
git -C "$TMP_ROOT/oracle" remote set-url origin https://github.com/Soul-Brews-Studio/xiaoer-oracle.git/
assert_exit_code 0 "$TMP_ROOT/oracle" "oracle HTTPS trailing slash allows direct main push"

git -C "$TMP_ROOT/no-origin" init -q
assert_exit_code 2 "$TMP_ROOT/no-origin" "missing origin blocks direct main push"

if [ "$failures" -gt 0 ]; then
  exit 1
fi
