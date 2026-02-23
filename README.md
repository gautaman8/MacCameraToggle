# CameraToggle

A lightweight macOS menu bar app to quickly enable or disable the built-in camera.

It works by installing/removing a macOS **configuration profile** that sets `allowCamera = false` (the same restriction available under Screen Time > Content & Privacy > App Restrictions).

---

## Requirements

- macOS 11.0 (Big Sur) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Admin password (prompted each time you toggle)

---

## Quick Start

```bash
# 1. Clone / download the project
cd CameraToggle

# 2. Build the app
chmod +x build.sh
./build.sh

# 3. Remove quarantine flag (unsigned app)
xattr -cr build/CameraToggle.app

# 4. Run
open build/CameraToggle.app
```

A camera icon will appear in your menu bar. Click it to toggle.

---

## Menu Bar Usage

| Icon | Meaning |
|------|---------|
| **camera.fill** (solid camera) | Camera is **enabled** |
| **camera.slash.fill** (slashed camera) | Camera is **disabled** |

Click the icon to open the menu:

- **Enable / Disable Camera** - toggles the restriction (prompts for admin password)
- **Quit CameraToggle** - exits the app

A macOS notification confirms each toggle.

---

## CLI Alternative

If you prefer the command line:

```bash
chmod +x toggle-camera.sh

./toggle-camera.sh              # toggle current state
./toggle-camera.sh disable      # disable camera
./toggle-camera.sh enable       # enable camera
./toggle-camera.sh status       # show current state
```

---

## Auto-Start on Login

1. Open **System Settings > General > Login Items**
2. Click **+** and select `build/CameraToggle.app`

Or move the `.app` to `/Applications` first:

```bash
cp -R build/CameraToggle.app /Applications/
```

---

## How It Works

1. **Disable camera**: A `.mobileconfig` configuration profile containing `allowCamera: false` is generated and installed via the `profiles` CLI tool with admin privileges.
2. **Enable camera**: The profile is removed via `profiles remove`.
3. **State tracking**: A sentinel file `~/.camera-toggle-disabled` tracks the current state so the menu bar icon stays in sync across launches.

The configuration profile uses the `com.apple.applicationaccess` payload, the same mechanism macOS Screen Time and MDM solutions use to restrict camera access.

---

## Troubleshooting

### "CameraToggle can't be opened because Apple cannot check it for malicious software"

Run once:
```bash
xattr -cr build/CameraToggle.app
```

### Toggle fails / password dialog doesn't appear

- Make sure you're running from a graphical session (not SSH).
- Check that `profiles` is available: `which profiles` should return `/usr/bin/profiles`.

### Camera still works after disabling

- Some apps may cache camera access. Try quitting and reopening the app that uses the camera.
- Verify the profile is installed: `profiles list` (may require `sudo`).

### State file out of sync

If the icon shows the wrong state, click the menu and toggle once. Or manually remove the state file:

```bash
rm ~/.camera-toggle-disabled
```

---

## Uninstall

1. Quit CameraToggle from the menu bar.
2. If camera is currently disabled, enable it first (or run `sudo profiles remove -identifier com.personal.camera-toggle`).
3. Delete the app and state file:

```bash
rm -rf build/CameraToggle.app
rm -f ~/.camera-toggle-disabled
rm -rf ~/Library/Application\ Support/CameraToggle
```

---

## Project Structure

```
CameraToggle/
  Sources/
    CameraToggle.swift      # Menu bar app (AppKit / NSStatusBar)
  Resources/
    Info.plist               # App bundle metadata (LSUIElement=true)
  build.sh                   # Compile & package into .app
  toggle-camera.sh           # Standalone CLI toggle script
  README.md
```

---

## License

Personal use. No warranty.
