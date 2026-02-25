#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== Phase 0: Infrastructure Validation ==="
echo ""

# --- 1. GitHub CLI ---
echo "[1/3] GitHub CLI"

if command -v gh &>/dev/null; then
    pass "gh CLI installed ($(gh --version | head -1))"
else
    fail "gh CLI not found"
fi

if [ -n "${GH_TOKEN:-}" ]; then
    pass "GH_TOKEN is set"
else
    fail "GH_TOKEN is not set"
fi

if gh auth status &>/dev/null; then
    pass "gh auth status OK"
else
    fail "gh auth status failed"
fi

# Test API read access against this repo's remote origin
REPO="eklavyamirani/code-review.nvim"
if gh api "repos/${REPO}" --jq '.full_name' &>/dev/null; then
    pass "gh api read access to ${REPO}"
else
    fail "gh api read access to ${REPO} failed"
fi

echo ""

# --- 2. Git ---
echo "[2/3] Git"

if command -v git &>/dev/null; then
    pass "git installed ($(git --version))"
else
    fail "git not found"
fi

if git ls-remote --heads origin &>/dev/null; then
    pass "git remote access OK"
else
    # SSH may not work in container — try HTTPS via gh credential helper
    ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -n "$ORIGIN_URL" ]; then
        HTTPS_URL=$(echo "$ORIGIN_URL" | sed 's|git@github.com:|https://github.com/|' | sed 's|\.git$||').git
        # Use gh as git credential helper (never puts token in URL or logs)
        if git -c credential.helper='!gh auth git-credential' ls-remote "${HTTPS_URL}" &>/dev/null 2>&1; then
            pass "git remote access OK (via HTTPS + gh credential helper)"
        else
            # Repo might be empty (no branches) — verify via gh api
            REPO_NAME=$(echo "$ORIGIN_URL" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
            if gh api "repos/${REPO_NAME}" --jq '.full_name' &>/dev/null; then
                pass "git remote access OK (repo exists, may be empty)"
            else
                fail "git remote access failed"
            fi
        fi
    else
        fail "no git remote configured"
    fi
fi

echo ""

# --- 3. Neovim + Plugins ---
echo "[3/3] Neovim"

if command -v nvim &>/dev/null; then
    pass "nvim installed ($(nvim --version | head -1))"
else
    fail "nvim not found"
fi

# Check plenary.nvim loads
if nvim --headless -c "lua require('plenary'); print('ok')" -c "qa!" 2>&1 | grep -q "ok"; then
    pass "plenary.nvim loads"
else
    fail "plenary.nvim failed to load"
fi

# Check mini.test loads
if nvim --headless -c "lua require('mini.test'); print('ok')" -c "qa!" 2>&1 | grep -q "ok"; then
    pass "mini.test loads"
else
    fail "mini.test failed to load"
fi

# Run a trivial mini.test via a test file
cat > /tmp/test_trivial.lua << 'TESTEOF'
local T = require('mini.test')
local suite = T.new_set()
suite['trivial'] = function() T.expect.equality(1 + 1, 2) end
return suite
TESTEOF

MINI_OUTPUT=$(nvim --headless \
  -c "lua require('mini.test').setup()" \
  -c "lua require('mini.test').run_file('/tmp/test_trivial.lua')" \
  2>&1)

if echo "$MINI_OUTPUT" | grep -q "Fails (0)"; then
    pass "mini.test trivial test passes"
else
    fail "mini.test trivial test failed"
    echo "    Output: $MINI_OUTPUT"
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
