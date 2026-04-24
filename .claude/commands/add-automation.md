Enter plan mode, then help me add a new macOS automation to this project.

Read these files first to understand the current state of the infra:
- `bin/lock-watcher.swift` — the running watcher; new observers go here
- `bin/ledoff` — example of an action script
- `install.sh` — copies action scripts to /usr/local/bin/ and reloads the agent
- `uninstall.sh` — removes installed scripts
- `EXPANDING.md` — guide covering available notifications, IOKit sleep/wake, and the checklist for adding a new command

Then ask me:
1. What event should trigger the automation? (e.g. screen lock, unlock, screen saver, sleep — refer to the notification table in EXPANDING.md)
2. What should happen when it triggers? (e.g. turn LEDs on, mute audio, pause an app)
3. Any parameters needed? (e.g. IP address, brightness value, app name)

Once I answer, present a plan covering:
- The new `bin/<name>` script (full content)
- The new observer block to add in `lock-watcher.swift`
- The `install.sh` lines to add (sudo cp + chmod)
- The `uninstall.sh` line to add

Wait for my approval before writing any files. After approval, implement everything and run `./install.sh` to apply.

User hint (may be empty): $ARGUMENTS
