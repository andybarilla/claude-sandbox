#!/bin/bash
# Apply firewall rules, copy host config to the claude user, then run
# as non-root. Host files are mounted read-only at /mnt/ to avoid any
# ownership changes on the host filesystem.
set -e

firewall-init.sh || true

# Copy host Claude config directory to the claude user's home
if [ -d /mnt/.claude ]; then
  cp -a /mnt/.claude /home/claude/.claude
  # Auto-accept the bypass permissions dialog for sandboxed containers
  SETTINGS=/home/claude/.claude/settings.json
  if [ -f "$SETTINGS" ]; then
    TMP=$(mktemp)
    jq '. + {skipDangerousModePermissionPrompt: true}' "$SETTINGS" > "$TMP" \
      && mv "$TMP" "$SETTINGS"
  else
    echo '{"skipDangerousModePermissionPrompt":true}' > "$SETTINGS"
  fi
  chown -R claude:claude /home/claude/.claude
fi

# Copy host Claude config file (~/.claude.json) and ensure onboarding
# is marked complete so Claude starts directly at the prompt
CONFIG=/home/claude/.claude.json
if [ -f /mnt/.claude.json ]; then
  cp /mnt/.claude.json "$CONFIG"
  TMP=$(mktemp)
  jq '. + {hasCompletedOnboarding: true, theme: (.theme // "dark"), installMethod: "npm", autoUpdates: false}' "$CONFIG" > "$TMP" \
    && mv "$TMP" "$CONFIG"
else
  echo '{"hasCompletedOnboarding":true,"theme":"dark"}' > "$CONFIG"
fi
chown claude:claude "$CONFIG"

# Configure git identity
[ -n "${GIT_USER:-}" ] && su claude -c "git config --global user.name '$GIT_USER'"
[ -n "${GIT_EMAIL:-}" ] && su claude -c "git config --global user.email '$GIT_EMAIL'"

# Configure gh/git authentication
if [ -n "${GH_TOKEN:-}" ]; then
  su claude -c "gh auth setup-git"
fi

chown -R claude:claude /workspace

exec su claude -c "$*"
