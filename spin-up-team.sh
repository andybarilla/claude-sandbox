#!/usr/bin/env bash
# Launch multiple isolated Claude Code instances in tmux, each with its own
# git worktree created from an existing repository.
#
# Usage: spin-up-team.sh <repo-path> <num-worktrees> [base-branch]
#
# Arguments:
#   repo-path      Path to the existing git repository
#   num-worktrees  Number of worktrees (and Claude instances) to create
#   base-branch    Branch to base worktrees on (default: current HEAD)
#
# Worktrees are created under <repo-parent>/<repo-name>-worktrees/
# and named worker-1, worker-2, etc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <repo-path> <num-worktrees> [base-branch]"
  echo ""
  echo "  repo-path      Path to an existing git repository"
  echo "  num-worktrees  Number of worktrees to create (1-10)"
  echo "  base-branch    Branch to base worktrees on (default: HEAD)"
  exit 1
fi

REPO=$(realpath "$1")
NUM_WORKTREES="$2"
BASE_BRANCH="${3:-}"

if ! git -C "$REPO" rev-parse --git-dir &>/dev/null; then
  echo "Error: '$REPO' is not a git repository"
  exit 1
fi

if ! [[ "$NUM_WORKTREES" =~ ^[0-9]+$ ]] || [ "$NUM_WORKTREES" -lt 1 ] || [ "$NUM_WORKTREES" -gt 10 ]; then
  echo "Error: num-worktrees must be a number between 1 and 10"
  exit 1
fi

# Strip .git suffix for bare repos so worktree dir is named cleanly
REPO_NAME=$(basename "$REPO" .git)
WORKTREE_DIR="$(dirname "$REPO")/${REPO_NAME}-worktrees"

# Resolve the base commit so every worktree starts from the same point
if [ -n "$BASE_BRANCH" ]; then
  BASE_REF=$(git -C "$REPO" rev-parse --verify "$BASE_BRANCH" 2>/dev/null) \
    || { echo "Error: branch '$BASE_BRANCH' not found in repo"; exit 1; }
else
  BASE_REF=$(git -C "$REPO" rev-parse HEAD)
  BASE_BRANCH=$(git -C "$REPO" symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")
fi

echo "Repository:  $REPO"
echo "Base branch: $BASE_BRANCH ($BASE_REF)"
echo "Worktrees:   $NUM_WORKTREES (in $WORKTREE_DIR)"
echo ""

mkdir -p "$WORKTREE_DIR"

WORKTREES=()
for i in $(seq 1 "$NUM_WORKTREES"); do
  WT_NAME="worker-${i}"
  WT_PATH="${WORKTREE_DIR}/${WT_NAME}"
  BRANCH_NAME="${WT_NAME}"

  if [ -d "$WT_PATH" ]; then
    echo "Worktree already exists: $WT_PATH (reusing)"
  else
    echo "Creating worktree: $WT_PATH (branch: $BRANCH_NAME)"
    git -C "$REPO" worktree add -b "$BRANCH_NAME" "$WT_PATH" "$BASE_REF"
  fi

  WORKTREES+=("$WT_PATH")
done

echo ""
echo "Starting tmux session..."

SESSION="claude-team"

# Kill existing session if present
tmux kill-session -t "$SESSION" 2>/dev/null || true

for i in "${!WORKTREES[@]}"; do
  WT="${WORKTREES[$i]}"
  NAME=$(basename "$WT")
  if [ "$i" -eq 0 ]; then
    tmux new-session -d -s "$SESSION" -n "$NAME"
    tmux send-keys -t "$SESSION:$NAME" "$SCRIPT_DIR/claude-worktree.sh $WT $NAME" Enter
  else
    tmux new-window -t "$SESSION" -n "$NAME"
    tmux send-keys -t "$SESSION:$NAME" "$SCRIPT_DIR/claude-worktree.sh $WT $NAME" Enter
  fi
done

tmux attach -t "$SESSION"
