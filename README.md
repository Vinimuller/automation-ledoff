# automation-ledoff

Turns off a WLED strip whenever macOS locks the screen.

## Prerequisites

- macOS (tested on Sequoia 15.5)
- WLED reachable at `192.168.15.178`

## Install

```zsh
./install.sh
```

## Test

Lock the screen with **Ctrl+Cmd+Q** — the LEDs should go off.

## Troubleshoot

```zsh
# Check for errors
cat /tmp/lockwatcher.err
cat /tmp/lockwatcher.log

# Verify the endpoint works directly
bin/ledoff

# Confirm the agent is loaded
launchctl list | grep lockwatcher
```

## Change the WLED IP

Edit `bin/ledoff` and update the IP in the `curl` line. No reinstall needed — the script is read on every invocation.

## Uninstall

```zsh
./uninstall.sh
```
