#!/usr/bin/env bash
# Launch Neovim inside Docker with the plugin loaded for exploratory testing.
#
# Usage:
#   ./scripts/dev.sh                          # open in the plugin repo dir
#   ./scripts/dev.sh /path/to/worktree        # open in a specific directory
#   ./scripts/dev.sh test/sample-pr           # open in a worktree by branch name
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"

TARGET=""

if [ $# -ge 1 ]; then
  ARG="$1"
  if [ -d "$ARG" ]; then
    # Argument is a directory path
    TARGET="$(cd "$ARG" && pwd)"
  else
    # Try to resolve as a branch name via git worktree list
    MATCH=$(git -C "$PLUGIN_DIR" worktree list --porcelain 2>/dev/null \
      | awk -v branch="$ARG" '
        /^worktree / { wt=$2 }
        /^branch /   { sub(/^refs\/heads\//, "", $2); if ($2 == branch) print wt }
      ')
    if [ -n "$MATCH" ]; then
      TARGET="$MATCH"
    else
      echo "Error: '$ARG' is not a directory or a known worktree branch."
      echo ""
      echo "Available worktrees:"
      git -C "$PLUGIN_DIR" worktree list
      exit 1
    fi
  fi
fi

# Build volume mounts and working directory
VOLUMES=("-v" "${PLUGIN_DIR}:/plugin")
WORKDIR="/plugin"

if [ -n "$TARGET" ] && [ "$TARGET" != "$PLUGIN_DIR" ]; then
  # Mount worktree at its original host path so .git file references resolve
  VOLUMES+=("-v" "${TARGET}:${TARGET}")
  # Also mount the main repo's .git at its host path (worktree .git files use absolute paths)
  VOLUMES+=("-v" "${PLUGIN_DIR}/.git:${PLUGIN_DIR}/.git")
  WORKDIR="${TARGET}"
fi

echo "Plugin:    ${PLUGIN_DIR}"
[ -n "$TARGET" ] && echo "Worktree:  ${TARGET}"
echo "Launching Neovim..."

cd "$PLUGIN_DIR"
docker compose run --rm \
  "${VOLUMES[@]}" \
  -w "$WORKDIR" \
  dev \
  bash -c "
    git config --global --add safe.directory '${PLUGIN_DIR}' 2>/dev/null
    git config --global --add safe.directory '${TARGET:-${PLUGIN_DIR}}' 2>/dev/null
    nvim --cmd 'set runtimepath^=/plugin'
  "
