# WLED Lock Automation — Build Spec

## Goal

When macOS locks the screen, automatically call the WLED endpoint to turn the LEDs off.

WLED off command:
```
curl -sS "http://192.168.15.178/win&A=0"
```

## Target environment

- macOS 15.5 (Sequoia)
- Shell: zsh
- Repo root: `~/Documents/git/automation-ledoff/`
- User's home: use `$HOME` — do not hardcode `/Users/<name>`

## Architecture

These pieces live in the repo and are version-controlled:

1. `bin/ledoff` — turns the LEDs off (called on lock).
2. `bin/ledon` — turns the LEDs on (called on unlock).
3. `bin/lock-watcher.swift` — a long-running Swift script that registers for `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked` via `DistributedNotificationCenter` and invokes the appropriate script each time.
4. `launchd/com.user.lockwatcher.plist` — LaunchAgent that keeps `lock-watcher.swift` alive at login.

The LaunchAgent is **symlinked** from `~/Library/LaunchAgents/com.user.lockwatcher.plist` → a copy of the plist inside the repo. `install.sh` copies action scripts and the watcher to `/usr/local/bin/`, copies the plist, symlinks it, and loads it. `uninstall.sh` reverses it.

## Critical implementation notes

### Use `DistributedNotificationCenter`, not `notifyutil`

`com.apple.screenIsLocked` is posted via **`NSDistributedNotificationCenter`** (Cocoa-level), not via Darwin Notifications. `notifyutil` only listens to Darwin Notifications — it will never receive this event. The watcher must use `DistributedNotificationCenter` (Swift) or `NSDistributedNotificationCenter` (ObjC/Python with pyobjc).

### `~/Documents` is TCC-protected — copy everything to `/usr/local/bin/`

On macOS Sequoia, LaunchAgent subprocesses cannot read files under `~/Documents`. This applies to **all** files the agent touches, including the watcher script itself. Passing a `~/Documents` path as an argument to `/usr/bin/swift` in `ProgramArguments` does **not** sidestep TCC — Swift still gets "Operation not permitted" at runtime.

The fix: `install.sh` copies `lock-watcher.swift`, `ledoff`, and `ledon` to `/usr/local/bin/`. The plist references `/usr/local/bin/lock-watcher.swift` (a fixed, absolute path — no placeholder substitution needed).

### launchd does not expand `~` or env vars in plist paths

All paths in `ProgramArguments` must be absolute. Since all executables now live in `/usr/local/bin/`, the committed plist needs no runtime substitution.

## Files

### `bin/ledoff`

```zsh
#!/bin/zsh
/usr/bin/curl -sS "http://192.168.15.178/win&A=0"
```

Must be `chmod +x`. Uses the full path to `curl` because launchd jobs run with a minimal `PATH`.

### `bin/ledon`

```zsh
#!/bin/zsh
/usr/bin/curl -sS "http://192.168.15.178/win&A=255"
```

Must be `chmod +x`.

### `bin/lock-watcher.swift`

```swift
#!/usr/bin/swift
import Foundation

DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("com.apple.screenIsLocked"),
    object: nil,
    queue: nil
) { _ in
    Process.launchedProcess(launchPath: "/usr/local/bin/ledoff", arguments: [])
}

DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("com.apple.screenIsUnlocked"),
    object: nil,
    queue: nil
) { _ in
    Process.launchedProcess(launchPath: "/usr/local/bin/ledon", arguments: [])
}

RunLoop.main.run()
```

Requires Swift (ships with Xcode Command Line Tools). Copied to `/usr/local/bin/lock-watcher.swift` at install time; launchd invokes it as `/usr/bin/swift /usr/local/bin/lock-watcher.swift`.

### `launchd/com.user.lockwatcher.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.lockwatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/swift</string>
        <string>/usr/local/bin/lock-watcher.swift</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lockwatcher.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockwatcher.err</string>
</dict>
</plist>
```

All paths are fixed — no placeholder substitution. `install.sh` copies this file verbatim as the resolved plist (gitignored).

### `install.sh`

Responsibilities, in order:

1. Resolve the repo's absolute path.
2. `chmod +x` and `sudo cp` each action script (`ledoff`, `ledon`) to `/usr/local/bin/`.
3. `sudo cp bin/lock-watcher.swift /usr/local/bin/lock-watcher.swift` — required because TCC blocks launchd from reading files under `~/Documents`, including the watcher script itself.
4. Copy `launchd/com.user.lockwatcher.plist` verbatim as the resolved plist (no substitution needed).
5. Ensure `~/Library/LaunchAgents/` exists.
6. If the agent link already exists, `launchctl unload` and remove it.
7. Symlink `~/Library/LaunchAgents/com.user.lockwatcher.plist` → the resolved plist.
8. `launchctl load` the symlink.
9. Print confirmation with log paths.

Must be `chmod +x` and begin with `#!/bin/zsh` and `set -euo pipefail`.

### `uninstall.sh`

1. `launchctl unload` the agent link (ignore errors).
2. Remove the symlink.
3. Remove the resolved plist.
4. `sudo rm /usr/local/bin/ledoff`, `ledon`, and `lock-watcher.swift`.
5. Print confirmation.

### `.gitignore`

```
launchd/com.user.lockwatcher.resolved.plist
```

## Final repo layout

```
automation-ledoff/
├── .gitignore
├── README.md
├── spec.md
├── EXPANDING.md
├── install.sh
├── uninstall.sh
├── bin/
│   ├── ledoff
│   ├── ledon
│   └── lock-watcher.swift
└── launchd/
    └── com.user.lockwatcher.plist   # resolved copy is gitignored
```

## Acceptance checks

After `./install.sh` completes:

1. `launchctl list | grep lockwatcher` shows `com.user.lockwatcher` with a live PID.
2. `readlink ~/Library/LaunchAgents/com.user.lockwatcher.plist` points into the repo.
3. `ls /usr/local/bin/ledoff /usr/local/bin/ledon /usr/local/bin/lock-watcher.swift` — all exist.
4. Running `bin/ledoff` directly turns the LEDs off (validates endpoint reachability).
5. Locking the screen with Ctrl+Cmd+Q turns the LEDs off.
6. Unlocking the screen turns the LEDs on.
7. `/tmp/lockwatcher.err` contains no errors after a lock/unlock cycle.

## Non-goals (do not implement)

- Shortcuts.app integration — macOS Shortcuts has no lock trigger on desktop.
- Sourcing `~/.zshrc` or dealing with shell aliases.
