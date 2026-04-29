# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A macOS automation scaffold. A Swift watcher (`bin/lock-watcher.swift`) subscribes to system distributed notifications via `DistributedNotificationCenter` and launches action scripts in `bin/` when events fire. A LaunchAgent (`launchd/com.user.lockwatcher.plist`) keeps the watcher alive across reboots.

The two built-in automations control a WLED LED strip: `bin/ledoff` (screen lock → LEDs off) and `bin/ledon` (screen unlock → LEDs on).

## Installing / reloading

```zsh
./install.sh     # copies scripts to /usr/local/bin/, loads the LaunchAgent (requires sudo)
./uninstall.sh   # unloads agent, removes /usr/local/bin/ copies
```

Run `./install.sh` any time `lock-watcher.swift` or an action script changes — it copies everything and reloads the agent.

## Debugging

```zsh
tail -f /tmp/lockwatcher.log /tmp/lockwatcher.err   # live agent output
launchctl list | grep lockwatcher                    # confirm agent is running (PID shown, not -)
bin/ledoff                                           # test an action script directly
```

## Adding a new automation (`/add-automation`)

Use the `/add-automation` Claude Code slash command — it reads the current setup, asks what you want, presents a plan, and implements after approval.

To add manually, see `EXPANDING.md`. The checklist:
1. Create `bin/<name>` — use full executable paths (launchd PATH is minimal: `/usr/bin:/bin:/usr/sbin:/sbin`).
2. Add an observer block in `bin/lock-watcher.swift`.
3. Add `sudo cp` + `sudo chmod +x` lines in `install.sh`.
4. Add `sudo rm -f /usr/local/bin/<name>` in `uninstall.sh`.
5. Run `./install.sh`.

## Key constraints (macOS Sequoia)

- **TCC blocks `~/Documents` at LaunchAgent runtime.** All files — including `lock-watcher.swift` itself — must be copied to `/usr/local/bin/` at install time. Passing a `~/Documents` path in `ProgramArguments` does NOT bypass TCC.
- **`notifyutil` does not work for lock events.** Lock/unlock use `NSDistributedNotificationCenter`; `notifyutil` targets Darwin Notifications — a separate system.
- **No `~` or env vars in plist paths.** launchd does not expand them. Since everything is in `/usr/local/bin/`, the plist uses absolute paths with no substitution needed.
- **IOKit required for machine sleep/wake.** `DistributedNotificationCenter` only covers screen lock, unlock, and screen saver events. See `EXPANDING.md` for the IOKit pattern.

## File map

| File | Role |
|---|---|
| `bin/lock-watcher.swift` | The watcher process — add new `addObserver` blocks here |
| `bin/ledoff`, `bin/ledon` | Example action scripts |
| `launchd/com.user.lockwatcher.plist` | LaunchAgent template (paths already absolute) |
| `launchd/com.user.lockwatcher.resolved.plist` | Generated copy symlinked into `~/Library/LaunchAgents/` |
| `install.sh` | Copies scripts, creates symlink, loads agent |
| `uninstall.sh` | Unloads agent, removes installed files |
| `EXPANDING.md` | Notification names reference, IOKit pattern, full add-command checklist |
| `.claude/commands/add-automation.md` | Prompt for the `/add-automation` slash command |
