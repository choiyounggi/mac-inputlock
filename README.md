# mac-inputlock

**English** | [한국어](README.ko.md)

A personal macOS lock daemon that **globally blocks keyboard and mouse input
while keeping the screen on**. Not the lock screen (login screen) — a "lock of
your own" where input goes dead but the display stays visible.

For stepping away, cleaning the keyboard, preventing accidents — or cats. One
toggle hotkey locks and unlocks.

## Toggle hotkey

**⌃⌥⌘L** (Control + Option + Command + L) — every press toggles lock ↔ unlock.

While locked, the keyboard and mouse (movement/clicks/scrolling/trackpad) are
all blocked; only this hotkey passes through, so it is the one way to unlock.

## Install

### 1) Homebrew (when ready)

```bash
brew install --cask choiyounggi/tap/inputlock
```

### 2) From a release

Grab `InputLock-<version>.zip` from
[Releases](https://github.com/choiyounggi/mac-inputlock/releases), unzip, and
move `InputLock.app` into `/Applications`.

### 3) Build from source

```bash
git clone https://github.com/choiyounggi/mac-inputlock.git
cd mac-inputlock
./build.sh 1.0.0          # produces InputLock.app + InputLock-1.0.0.zip
```

## Permission (required)

Intercepting input requires the **Accessibility** permission.
Go to **System Settings → Privacy & Security → Accessibility**, add
`InputLock.app`, and toggle it ON.

> For macOS security reasons this permission must be granted by you manually —
> it cannot be automated.

## Auto-start (resident at login)

After granting the permission, one line registers a LaunchAgent so it is always
resident at login:

```bash
/Applications/InputLock.app/Contents/MacOS/inputlock --install-agent
```

Remove:

```bash
/Applications/InputLock.app/Contents/MacOS/inputlock --uninstall-agent
```

## Escape hatches (if input won't come back)

- Even while locked, **⌃⌥⌘L** always passes through.
- If that fails, SSH in from another device and `killall inputlock`.
  When the process dies, the event tap is released automatically and input
  recovers **immediately**. (With auto-start on, it comes back ~10 seconds
  later — **in the unlocked state**.)

## Limits (not a security lock)

Not a 100% block. The OS may take priority on a forced power-button shutdown,
some system shortcuts during secure-input (password field) situations, and some
multitouch system gestures. Plenty for accidents/pranks/stepping away — not a
security lock against a determined intruder.

## How it works

A session-level `CGEventTap` (Quartz global event tap) swallows (suppresses)
keyboard and mouse events while locked. The toggle hotkey alone is intercepted
in either state and used as the toggle trigger.

## License

MIT — [LICENSE](LICENSE)
