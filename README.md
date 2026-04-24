```
███╗   ███╗ █████╗  ██████╗ ██████╗ ███████╗
████╗ ████║██╔══██╗██╔════╝██╔═══██╗██╔════╝
██╔████╔██║███████║██║     ██║   ██║███████╗
██║╚██╔╝██║██╔══██║██║     ██║   ██║╚════██║
██║ ╚═╝ ██║██║  ██║╚██████╗╚██████╔╝███████║
╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
  A U T O M A T I O N S   O N   M A C O S
```

A scaffold for building macOS event-driven automations using Claude Code.

The pattern: a Swift watcher listens for system notifications via `DistributedNotificationCenter` and calls shell scripts when events fire. A LaunchAgent keeps it running forever.

**Two automations ship out of the box**, both controlling a [WLED](https://kno.wled.ge/) LED strip via HTTP:

| Event | Script | Action |
|---|---|---|
| Screen locked | `bin/ledoff` | `curl .../win&A=0` — LEDs off |
| Screen unlocked | `bin/ledon` | `curl .../win&A=255` — LEDs on |

---

## How it works

```
macOS system event  (lock, unlock, sleep, screen saver, ...)
        │
        ▼
DistributedNotificationCenter   ← lock-watcher.swift
        │
        ▼
   bin/<action>                 ← any executable: zsh, python, swift, binary
```

Adding a new automation is just two steps:
1. Add a new observer in `bin/lock-watcher.swift`
2. Add a `bin/<action>` script that does the work

See [`EXPANDING.md`](EXPANDING.md) for available notification names, IOKit sleep/wake events, and the full checklist.

---

## Using Claude Code to add automations

This repo ships a `/add-automation` command for [Claude Code](https://claude.ai/code).

Open the repo in Claude Code and run:

```
/add-automation
```

It reads the current setup, asks what event and action you want, presents a plan, and implements it after your approval.

---

## Prerequisites

- macOS Sequoia 15+
- Xcode Command Line Tools — `xcode-select --install`
- A WLED device (or swap `bin/ledoff` / `bin/ledon` for any action you want)

## Install

```zsh
./install.sh
```

Copies scripts to `/usr/local/bin/`, loads the LaunchAgent. Requires `sudo` for the copy step.

## Troubleshoot

```zsh
# Watch live output
tail -f /tmp/lockwatcher.err /tmp/lockwatcher.log

# Confirm agent is running (should show a PID, not -)
launchctl list | grep lockwatcher

# Test scripts directly
bin/ledoff
bin/ledon
```

## Uninstall

```zsh
./uninstall.sh
```

---

## Key constraints (macOS Sequoia)

- **TCC blocks `~/Documents`** — LaunchAgents cannot read files there at runtime, even if the path is in `ProgramArguments`. All scripts (including `lock-watcher.swift`) are copied to `/usr/local/bin/` at install time.
- **`notifyutil` won't work** for lock events — those use `NSDistributedNotificationCenter`, not Darwin Notifications.
- **No `~` or env vars in plist paths** — all paths must be absolute. Since everything lives in `/usr/local/bin/`, no substitution is needed.
