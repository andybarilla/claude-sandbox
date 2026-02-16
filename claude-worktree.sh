#!/usr/bin/env bash
# Launch an isolated Claude Code instance for a git worktree.
# Usage: claude-worktree.sh <worktree-path> [session-name]
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <worktree-path> [session-name]"
  exit 1
fi

WORKTREE=$(realpath "$1")
SESSION=${2:-$(basename "$WORKTREE")}

if [ ! -d "$WORKTREE" ]; then
  echo "Error: worktree path '$WORKTREE' does not exist"
  exit 1
fi

docker run -it --rm \
  --name "claude-$SESSION" \
  --cap-add NET_ADMIN \
  --memory=4g \
  --cpus=2 \
  -v "$WORKTREE:/workspace" \
  -v "$HOME/.claude:/mnt/.claude:ro" \
  -v "$HOME/.claude.json:/mnt/.claude.json:ro" \
  claude-sandbox \
  "claude --dangerously-skip-permissions"
