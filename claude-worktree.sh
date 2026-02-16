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

# Resolve the main repo's .git dir so worktree references work inside the container
GITDIR_MOUNT=""
if [ -f "$WORKTREE/.git" ]; then
  # This is a worktree — .git is a file pointing to the main repo
  MAIN_GITDIR=$(git -C "$WORKTREE" rev-parse --git-common-dir 2>/dev/null)
  MAIN_GITDIR=$(realpath "$MAIN_GITDIR")
  GITDIR_MOUNT="-v $MAIN_GITDIR:$MAIN_GITDIR"
fi

GOMODCACHE_MOUNT=""
if [ -d "$HOME/go/pkg/mod" ]; then
  GOMODCACHE_MOUNT="-v $HOME/go/pkg/mod:/home/claude/go/pkg/mod:ro"
fi

GH_TOKEN=$(gh auth token 2>/dev/null || true)
GIT_USER=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)

docker run -it --rm \
  --name "claude-$SESSION" \
  --cap-add NET_ADMIN \
  --memory=4g \
  --cpus=2 \
  -e GH_TOKEN="$GH_TOKEN" \
  -e GIT_USER="$GIT_USER" \
  -e GIT_EMAIL="$GIT_EMAIL" \
  -v "$WORKTREE:/workspace" \
  $GITDIR_MOUNT \
  $GOMODCACHE_MOUNT \
  -v "$HOME/.claude:/mnt/.claude:ro" \
  -v "$HOME/.claude.json:/mnt/.claude.json:ro" \
  claude-sandbox \
  "claude --dangerously-skip-permissions"
