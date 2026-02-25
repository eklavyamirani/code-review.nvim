#!/usr/bin/env bash
# Run all tests via mini.test inside Neovim
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PLUGIN_DIR"

# Find all test files
TEST_FILES=$(find tests -name 'test_*.lua' -type f | sort)

FAILED=0
for test_file in $TEST_FILES; do
  echo "=== Running: ${test_file} ==="
  if nvim --headless \
    -c "lua vim.opt.runtimepath:prepend('.')" \
    -c "lua require('mini.test').setup()" \
    -c "lua require('mini.test').run_file('${test_file}')" 2>&1; then
    echo ""
  else
    FAILED=$((FAILED + 1))
  fi
  echo ""
done

if [ "$FAILED" -gt 0 ]; then
  echo "FAILED: ${FAILED} test file(s) had errors"
  exit 1
else
  echo "All test files passed"
fi
