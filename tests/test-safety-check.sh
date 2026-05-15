#!/bin/bash
# Test harness for safety-check.sh
# Each test pipes a JSON payload to safety-check.sh and asserts on exit code.
#
# Usage: bash tests/test-safety-check.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$SCRIPT_DIR/safety-check.sh"
PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
  local name="$1"
  local cmd="$2"
  local expected="$3"  # 0 = allow, 2 = block

  local payload
  payload=$(jq -nc --arg c "$cmd" '{tool_input:{command:$c}}')
  local actual
  actual=$(echo "$payload" | bash "$HOOK" >/dev/null 2>&1; echo $?)

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS+1))
    printf '  \033[32m✓\033[0m %s\n' "$name"
  else
    FAIL=$((FAIL+1))
    FAILED_TESTS+=("$name (expected exit $expected, got $actual)")
    printf '  \033[31m✗\033[0m %s — expected exit %s, got %s\n' "$name" "$expected" "$actual"
  fi
}

echo "=== Issue #1 regression tests: gh body exemption ==="

# Each destructive rule × body-bearing gh form should NOT block
DESTRUCTIVE_BODIES=(
  'rm -rf ~/.bun/install'
  '&& rm -rf /tmp/foo'
  'git push --force origin main'
  'git push --force-with-lease'
  'git push -f origin x'
  'git reset --hard HEAD~1'
  'git commit --amend -m "fix"'
  'git checkout -- file.txt'
  'git restore .'
  'git clean -fd'
  'git branch -D feature'
  'git stash drop'
  'git stash clear'
  'git commit --no-verify -m "x"'
)

for body in "${DESTRUCTIVE_BODIES[@]}"; do
  run_test "gh issue create body contains: $body" \
    "gh issue create -R foo/bar --title 't' --body \"$body\"" \
    0
done

# Heredoc body forms
run_test "gh issue create heredoc body w/ rm -rf" \
"gh issue create -R foo/bar --title 't' --body \"\$(cat <<'EOF'
## Workaround

&& rm -rf ~/.bun/install/global/node_modules
EOF
)\"" \
  0

run_test "gh pr create heredoc body w/ --force" \
"gh pr create --title 'x' --body \"\$(cat <<'EOF'
Document the bug: someone ran git push --force.
EOF
)\"" \
  0

run_test "gh issue comment with --no-verify in body" \
  "gh issue comment 42 --body 'we tried --no-verify but it broke'" \
  0

run_test "gh gist create with destructive text" \
  "gh gist create --desc 'rm -rf demo' file.txt" \
  0

run_test "gh release create heredoc body" \
"gh release create v1.0 --notes \"\$(cat <<'EOF'
breaking: removed --force flag
EOF
)\"" \
  0

run_test "rtk gh issue create (wrapper form)" \
  "rtk gh issue create -R o/r --title 't' --body 'rm -rf'" \
  0

echo ""
echo "=== Bypass-attempt tests: chained destructive commands should still block ==="

run_test "gh issue create chained with rm -rf via &&" \
  "gh issue create -R foo/bar --title 't' --body 'x' && rm -rf /tmp/foo" \
  2

run_test "gh issue create chained with rm -rf via ;" \
  "gh issue create -R foo/bar --title 't' --body 'x' ; rm -rf /tmp/foo" \
  2

run_test "gh issue create chained with git push --force" \
  "gh issue create -R foo/bar --title 't' --body 'x' && git push --force" \
  2

echo ""
echo "=== Existing safety still works (regressions) ==="

run_test "bare rm -rf still blocked" \
  "rm -rf /tmp/danger" \
  2

run_test "bare git push --force still blocked" \
  "git push --force origin main" \
  2

run_test "bare git reset --hard still blocked" \
  "git reset --hard HEAD~1" \
  2

run_test "bare git commit --amend still blocked" \
  "git commit --amend -m 'fix'" \
  2

run_test "bare git push origin main still blocked" \
  "git push origin main" \
  2

run_test "bare git checkout -- still blocked" \
  "git checkout -- file.txt" \
  2

run_test "bare git restore . still blocked" \
  "git restore ." \
  2

run_test "bare git clean -f still blocked" \
  "git clean -fd" \
  2

run_test "bare git branch -D still blocked" \
  "git branch -D feature" \
  2

run_test "bare git stash drop still blocked" \
  "git stash drop" \
  2

run_test "bare --no-verify still blocked" \
  "git commit --no-verify -m 'x'" \
  2

echo ""
echo "=== Edge cases ==="

run_test "gh issue list (not body-bearing) — rm -rf in arg still blocked" \
  "gh issue list && rm -rf /tmp" \
  2

run_test "gh repo view (not body-bearing) does not trigger exemption" \
  "gh repo view foo/bar" \
  0

run_test "title containing && and rm -rf (single line, no real chain)" \
  "gh issue create -R o/r --title 'fix: x && rm -rf y' --body 'b'" \
  0

run_test "simple ls is allowed" \
  "ls -la" \
  0

echo ""
echo "================================================"
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - $t"
  done
  exit 1
fi
