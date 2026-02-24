# CameraToggle

A lightweight macOS menu bar app to quickly enable or disable the built-in camera.

It works by **automating System Settings via AppleScript** to toggle the Screen Time "Allow Camera" setting (Screen Time > Content & Privacy > App Restrictions).

---

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- **Accessibility permission** for CameraToggle (System Settings > Privacy & Security > Accessibility)
- Screen Time enabled with Content & Privacy turned on

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

- **Enable / Disable Camera** - toggles the Screen Time Allow Camera setting
- **Debug: Dump UI Elements** - prints UI hierarchy to Terminal (for troubleshooting)
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

1. **Toggle**: The app uses **AppleScript UI automation** to open System Settings, navigate to Screen Time > Content & Privacy > App Restrictions, and click the "Allow Camera" toggle.
2. **State tracking**: Camera state is persisted via `UserDefaults` so the menu bar icon stays in sync across launches.
3. **System Settings**: Opens briefly during toggle, then closes automatically.

This approach directly toggles the same Screen Time setting you would change manually.

---

## First-Time Setup

1. **Grant Accessibility permission**:
   - System Settings > Privacy & Security > Accessibility
   - Click "+" and add `CameraToggle.app` (or `Terminal` if running the binary directly)
   - This is required for the app to interact with System Settings UI

2. **Enable Screen Time Content & Privacy**:
   - System Settings > Screen Time > Content & Privacy
   - Make sure the Content & Privacy toggle is ON

---

## Troubleshooting

### "CameraToggle can't be opened because Apple cannot check it for malicious software"

Run once:
```bash
xattr -cr build/CameraToggle.app
```

### Toggle doesn't work / no visible change

1. **Check Accessibility permission** is granted (see First-Time Setup above)
2. **Run from Terminal** to see debug output:
   ```bash
   ./build/CameraToggle.app/Contents/MacOS/CameraToggle
   ```
3. **Use the Debug menu**: Click "Debug: Dump UI Elements" in the menu bar dropdown, then check Terminal output. This shows the exact UI element names System Settings exposes.
4. The UI element names may vary by macOS version. If the auto-detection fails, share the debug dump output so the script can be adjusted.

### State icon out of sync

If the icon shows the wrong state, toggle once to resync. The state is stored in UserDefaults.

---

## Uninstall

1. Quit CameraToggle from the menu bar.
2. If camera is currently disabled, re-enable it via Screen Time settings manually.
3. Delete the app:

```bash
rm -rf build/CameraToggle.app
# If moved to Applications:
rm -rf /Applications/CameraToggle.app
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
