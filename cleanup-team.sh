#!/usr/bin/env bash
# Remove worktrees and worker branches created by spin-up-team.sh.
#
# Usage: cleanup-team.sh <repo-path>
#
# This will:
#   1. Kill the claude-team tmux session (and any running containers)
#   2. Remove all worker-* worktrees registered with git
#   3. Delete the corresponding worker-* branches
#   4. Remove the worktrees directory
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <repo-path>"
  echo ""
  echo "  repo-path  Path to the git repository used with spin-up-team.sh"
  exit 1
fi

REPO=$(realpath "$1")

if [ ! -d "$REPO/.git" ] && ! git -C "$REPO" rev-parse --git-dir &>/dev/null; then
  echo "Error: '$REPO' is not a git repository"
  exit 1
fi

REPO_NAME=$(basename "$REPO")
WORKTREE_DIR="$(dirname "$REPO")/${REPO_NAME}-worktrees"

# Kill tmux session and stop containers
echo "Stopping tmux session and containers..."
tmux kill-session -t claude-team 2>/dev/null && echo "  Killed tmux session: claude-team" || true
for cid in $(docker ps -q --filter "name=claude-worker-" 2>/dev/null); do
  docker stop "$cid" >/dev/null && echo "  Stopped container: $(docker inspect --format '{{.Name}}' "$cid")"
done

# Remove worktrees
echo ""
echo "Removing worktrees..."
for wt in $(git -C "$REPO" worktree list --porcelain | grep "^worktree " | sed 's/^worktree //' | grep "/worker-"); do
  echo "  Removing worktree: $wt"
  git -C "$REPO" worktree remove --force "$wt"
done

# Prune any stale worktree references
git -C "$REPO" worktree prune

# Delete worker branches
echo ""
echo "Deleting worker branches..."
for branch in $(git -C "$REPO" branch --list "worker-*" | sed 's/^[* +]*//'); do
  echo "  Deleting branch: $branch"
  git -C "$REPO" branch -D "$branch"
done

# Remove the worktrees directory if empty
if [ -d "$WORKTREE_DIR" ]; then
  if rmdir "$WORKTREE_DIR" 2>/dev/null; then
    echo ""
    echo "Removed directory: $WORKTREE_DIR"
  else
    echo ""
    echo "Note: $WORKTREE_DIR is not empty, not removing"
  fi
fi

echo ""
echo "Cleanup complete."
