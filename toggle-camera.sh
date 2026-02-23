#!/bin/bash
#
# toggle-camera.sh - CLI alternative to toggle camera on/off using
#                    a macOS configuration profile.
#
# Usage:
#   ./toggle-camera.sh              # toggles current state
#   ./toggle-camera.sh disable      # disable camera
#   ./toggle-camera.sh enable       # enable camera
#   ./toggle-camera.sh status       # show current state
#

set -euo pipefail

PROFILE_ID="com.personal.camera-toggle"
STATE_FILE="$HOME/.camera-toggle-disabled"
PROFILE_FILE="/tmp/DisableCamera.mobileconfig"

create_profile() {
    cat > "$PROFILE_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.applicationaccess</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.personal.camera-toggle.restriction</string>
            <key>PayloadUUID</key>
            <string>A1B2C3D4-E5F6-4A90-ABCD-EF1234567890</string>
            <key>PayloadEnabled</key>
            <true/>
            <key>allowCamera</key>
            <false/>
        </dict>
    </array>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadIdentifier</key>
    <string>com.personal.camera-toggle</string>
    <key>PayloadUUID</key>
    <string>F1E2D3C4-B5A6-4C90-1234-567890ABCDEF</string>
    <key>PayloadDisplayName</key>
    <string>Camera Toggle</string>
    <key>PayloadDescription</key>
    <string>Disables the built-in camera.</string>
    <key>PayloadOrganization</key>
    <string>Personal</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
</dict>
</plist>
EOF
}

disable_camera() {
    echo "Disabling camera..."
    create_profile
    sudo profiles install -path "$PROFILE_FILE"
    touch "$STATE_FILE"
    rm -f "$PROFILE_FILE"
    echo "Camera disabled."
}

enable_camera() {
    echo "Enabling camera..."
    sudo profiles remove -identifier "$PROFILE_ID"
    rm -f "$STATE_FILE"
    echo "Camera enabled."
}

show_status() {
    if [ -f "$STATE_FILE" ]; then
        echo "Camera: DISABLED"
    else
        echo "Camera: ENABLED"
    fi
}

ACTION="${1:-toggle}"

case "$ACTION" in
    disable|off)
        disable_camera
        ;;
    enable|on)
        enable_camera
        ;;
    toggle)
        if [ -f "$STATE_FILE" ]; then
            enable_camera
        else
            disable_camera
        fi
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {disable|enable|toggle|status}"
        exit 1
        ;;
esac
