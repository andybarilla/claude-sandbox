#!/usr/bin/env bash
# Launch multiple isolated Claude Code instances in tmux, one per worktree.
# Edit the WORKTREES array below to list your worktree paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

WORKTREES=(
  ~/project/worktree-feature-a
  ~/project/worktree-feature-b
  ~/project/worktree-bugfix-c
)

SESSION="claude-team"

# Kill existing session if present
tmux kill-session -t "$SESSION" 2>/dev/null || true

tmux new-session -d -s "$SESSION"

for i in "${!WORKTREES[@]}"; do
  WT="${WORKTREES[$i]}"
  NAME=$(basename "$WT")
  if [ "$i" -eq 0 ]; then
    tmux send-keys -t "$SESSION" "$SCRIPT_DIR/claude-worktree.sh $WT $NAME" Enter
  else
    tmux split-window -t "$SESSION"
    tmux send-keys -t "$SESSION" "$SCRIPT_DIR/claude-worktree.sh $WT $NAME" Enter
  fi
  tmux select-layout -t "$SESSION" tiled
done

tmux attach -t "$SESSION"
