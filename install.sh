#!/bin/zsh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_TEMPLATE="$REPO_DIR/launchd/com.user.lockwatcher.plist"
PLIST_RESOLVED="$REPO_DIR/launchd/com.user.lockwatcher.resolved.plist"
AGENTS_DIR="$HOME/Library/LaunchAgents"
AGENT_LINK="$AGENTS_DIR/com.user.lockwatcher.plist"

chmod +x "$REPO_DIR/bin/ledoff"

sudo cp "$REPO_DIR/bin/ledoff" /usr/local/bin/ledoff
sudo chmod +x /usr/local/bin/ledoff

chmod +x "$REPO_DIR/bin/ledon"
sudo cp "$REPO_DIR/bin/ledon" /usr/local/bin/ledon
sudo chmod +x /usr/local/bin/ledon

sudo cp "$REPO_DIR/bin/lock-watcher.swift" /usr/local/bin/lock-watcher.swift
cp "$PLIST_TEMPLATE" "$PLIST_RESOLVED"

mkdir -p "$AGENTS_DIR"

if [[ -e "$AGENT_LINK" || -L "$AGENT_LINK" ]]; then
  launchctl unload "$AGENT_LINK" 2>/dev/null || true
  rm -f "$AGENT_LINK"
fi

ln -s "$PLIST_RESOLVED" "$AGENT_LINK"

launchctl load "$AGENT_LINK"

echo "Installed. Lock your screen (Ctrl+Cmd+Q) to test."
echo "  stdout: /tmp/lockwatcher.log"
echo "  stderr: /tmp/lockwatcher.err"
