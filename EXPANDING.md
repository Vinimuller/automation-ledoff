# Expanding this project

This repo is a general-purpose macOS automation scaffold. The core infrastructure — a Swift watcher registered to distributed notifications + a LaunchAgent that keeps it alive — can be extended to react to any macOS system event.

## How it works (the pattern)

```
macOS system event
       │
       ▼
DistributedNotificationCenter  ←─ lock-watcher.swift listens here
       │
       ▼
  bin/<action>                 ←─ any executable: shell, swift, python, binary
```

Adding a new automation means:
1. Add a handler in `lock-watcher.swift` for a new notification name.
2. Add a `bin/<action>` script that does the work.
3. Run `./install.sh` to reload the agent.

No new LaunchAgent needed — the existing one already runs the watcher forever.

## Available macOS distributed notifications

These are the most useful ones. All are received by `DistributedNotificationCenter`.

| Event | Notification name |
|---|---|
| Screen locked | `com.apple.screenIsLocked` |
| Screen unlocked | `com.apple.screenIsUnlocked` |
| Screen saver started | `com.apple.screensaver.started` |
| Screen saver stopped | `com.apple.screensaver.stopped` |
| Display did sleep | `com.apple.screensaver.started` (same as above) |

For power/sleep events (machine sleep, display off) that are not distributed notifications, use IOKit power source notifications — see the IOKit section below.

## Example: turn LEDs back on at unlock

Add a `bin/ledon` script:

```zsh
#!/bin/zsh
/usr/bin/curl -sS "http://192.168.15.178/win&A=255"
```

Then add a second observer in `lock-watcher.swift`:

```swift
DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("com.apple.screenIsUnlocked"),
    object: nil,
    queue: nil
) { _ in
    Process.launchedProcess(launchPath: "/usr/local/bin/ledon", arguments: [])
}
```

Run `./install.sh` to apply (it copies `ledon` to `/usr/local/bin/` and reloads the agent).

## Example: mute audio on lock

```zsh
#!/bin/zsh
# bin/muteaudio
/usr/bin/osascript -e 'set volume output muted true'
```

## Example: pause Spotify on lock

```zsh
#!/bin/zsh
# bin/pause-spotify
/usr/bin/osascript -e 'tell application "Spotify" to pause'
```

## Example: run multiple actions on lock

`bin/on-lock` becomes a dispatcher:

```zsh
#!/bin/zsh
SCRIPT_DIR="$(dirname "$0")"
"$SCRIPT_DIR/ledoff"
"$SCRIPT_DIR/muteaudio"
"$SCRIPT_DIR/pause-spotify"
```

And `lock-watcher.swift` calls `/usr/local/bin/on-lock` instead of `ledoff`.

## Adding IOKit power events (sleep/wake)

For machine sleep and wake, `DistributedNotificationCenter` is not enough — you need IOKit. Extend `lock-watcher.swift`:

```swift
import IOKit.pwr_mgt

let rootPort = IORegisterForSystemPower(
    nil,
    &notifyPortRef,
    { _, _, messageType, _ in
        if messageType == kIOMessageSystemWillSleep {
            Process.launchedProcess(launchPath: "/usr/local/bin/ledoff", arguments: [])
        }
    },
    &notifierObject
)
CFRunLoopAddSource(
    RunLoop.main.getCFRunLoop(),
    IONotificationPortGetRunLoopSource(notifyPortRef),
    .defaultMode
)
```

## Adding a new bin/ command: checklist

1. Create `bin/<name>` with `#!/bin/zsh` (or any interpreter).
2. Use full paths for all executables (launchd has a minimal PATH: `/usr/bin:/bin:/usr/sbin:/sbin`).
3. Add it to `install.sh`: `chmod +x` the repo copy, then `sudo cp "$REPO_DIR/bin/<name>" /usr/local/bin/<name>` and `sudo chmod +x`.
4. Add it to `uninstall.sh`: `sudo rm -f /usr/local/bin/<name>`.
5. Register it in `lock-watcher.swift`, then re-run `install.sh` — it also copies `lock-watcher.swift` to `/usr/local/bin/`, so the agent picks up the new observer.
6. Run `./install.sh`.

## Debugging

```zsh
# Watch live output from the agent
tail -f /tmp/lockwatcher.log /tmp/lockwatcher.err

# Confirm the agent is running
launchctl list | grep lockwatcher

# Test an action script directly
bin/ledoff

# Force-reload after editing lock-watcher.swift
launchctl unload ~/Library/LaunchAgents/com.user.lockwatcher.plist
launchctl load  ~/Library/LaunchAgents/com.user.lockwatcher.plist

# Or just re-run install
./install.sh
```

## Known constraints

- **`~/Documents` is TCC-protected** on macOS Sequoia. This applies to **everything** the LaunchAgent touches — action scripts AND `lock-watcher.swift` itself. Passing the watcher path as an argument to `/usr/bin/swift` in `ProgramArguments` does **not** bypass TCC; Swift still gets "Operation not permitted" at runtime. All files must be copied to `/usr/local/bin/` at install time.
- **`notifyutil` does not work** for `com.apple.screenIsLocked`. It uses Darwin Notifications; the lock event uses `NSDistributedNotificationCenter`. These are separate systems.
- **launchd does not expand `~` or env vars** in plist paths. Use absolute paths only — since everything lives in `/usr/local/bin/`, the plist needs no runtime substitution.
