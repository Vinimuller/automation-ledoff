#!/bin/zsh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_RESOLVED="$REPO_DIR/launchd/com.user.lockwatcher.resolved.plist"
AGENT_LINK="$HOME/Library/LaunchAgents/com.user.lockwatcher.plist"

launchctl unload "$AGENT_LINK" 2>/dev/null || true
rm -f "$AGENT_LINK"
rm -f "$PLIST_RESOLVED"
sudo rm -f /usr/local/bin/ledoff
sudo rm -f /usr/local/bin/ledon
sudo rm -f /usr/local/bin/lock-watcher.swift

echo "Uninstalled com.user.lockwatcher."
