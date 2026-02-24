import Cocoa

// MARK: - Camera Manager

/// Manages camera enable/disable state by automating the Screen Time
/// "Allow Camera" toggle in System Settings via AppleScript UI scripting.
///
/// Navigation: System Settings > Screen Time > Content & Privacy >
///             App Restrictions > Allow Camera
///
/// Requires: System Settings > Privacy & Security > Accessibility permission
/// for CameraToggle.app (or Terminal if running the binary directly).
class CameraManager {

    private let defaults = UserDefaults.standard
    private let stateKey = "cameraDisabled"

    /// Locally tracked state (persists across launches via UserDefaults).
    var isCameraDisabled: Bool {
        get { defaults.bool(forKey: stateKey) }
        set { defaults.set(newValue, forKey: stateKey) }
    }

    /// Toggle the Allow Camera switch in Screen Time settings.
    /// Returns true if the script reported SUCCESS.
    @discardableResult
    func toggle() -> Bool {
        let wantDisabled = !isCameraDisabled

        print("[CameraToggle] Toggling camera to \(wantDisabled ? "DISABLED" : "ENABLED") ...")

        let script = buildToggleScript()

        if let result = runAppleScriptWithResult(script) {
            print("[CameraToggle] Script result: \(result)")
            if result.contains("SUCCESS") {
                isCameraDisabled = wantDisabled
                print("[CameraToggle] Camera is now \(wantDisabled ? "DISABLED" : "ENABLED").")
                return true
            }
        }
        print("[CameraToggle] Toggle failed. Run from Terminal to see details.")
        return false
    }

    /// Dump the UI element hierarchy at each navigation step.
    /// Run the app from Terminal to see the output.
    func dumpUI() {
        print("[CameraToggle] Opening System Settings > Screen Time and dumping UI ...")
        print("[CameraToggle] This may take several seconds ...")

        let script = """
        tell application "System Settings"
            activate
        end tell
        delay 2

        tell application "System Events"
            tell process "System Settings"
                set frontmost to true
                delay 1

                -- Click Screen Time in sidebar
                set allElems to entire contents of window 1
                repeat with elem in allElems
                    try
                        if (name of elem) is "Screen Time" and (role of elem as string) is "AXStaticText" then
                            click elem
                            exit repeat
                        end if
                    end try
                end repeat

                delay 2

                -- Dump Screen Time pane
                set output to "=== SCREEN TIME PANE ===" & linefeed
                set allElems to entire contents of window 1
                repeat with elem in allElems
                    try
                        set eName to name of elem
                        set eRole to role of elem as string
                        set eDesc to ""
                        try
                            set eDesc to description of elem as string
                        end try
                        set eVal to ""
                        try
                            set eVal to value of elem as string
                        end try
                        set output to output & eRole & " | " & eName & " | desc=" & eDesc & " | val=" & eVal & linefeed
                    end try
                end repeat

                -- Try clicking Content & Privacy
                set cpFound to false
                repeat with elem in allElems
                    try
                        set eName to name of elem
                        if eName contains "Content" and eName contains "Privacy" then
                            click elem
                            set cpFound to true
                            exit repeat
                        end if
                    end try
                end repeat

                if cpFound then
                    delay 2
                    set output to output & linefeed & "=== CONTENT & PRIVACY PANE ===" & linefeed
                    set allElems to entire contents of window 1
                    repeat with elem in allElems
                        try
                            set eName to name of elem
                            set eRole to role of elem as string
                            set eDesc to ""
                            try
                                set eDesc to description of elem as string
                            end try
                            set eVal to ""
                            try
                                set eVal to value of elem as string
                            end try
                            set output to output & eRole & " | " & eName & " | desc=" & eDesc & " | val=" & eVal & linefeed
                        end try
                    end repeat

                    -- Try clicking App Restrictions
                    set arFound to false
                    repeat with elem in allElems
                        try
                            set eName to name of elem
                            if eName contains "App Restriction" or eName contains "App restrictions" then
                                click elem
                                set arFound to true
                                exit repeat
                            end if
                        end try
                    end repeat

                    if arFound then
                        delay 2
                        set output to output & linefeed & "=== APP RESTRICTIONS PANE ===" & linefeed
                        set allElems to entire contents of window 1
                        repeat with elem in allElems
                            try
                                set eName to name of elem
                                set eRole to role of elem as string
                                set eDesc to ""
                                try
                                    set eDesc to description of elem as string
                                end try
                                set eVal to ""
                                try
                                    set eVal to value of elem as string
                                end try
                                set output to output & eRole & " | " & eName & " | desc=" & eDesc & " | val=" & eVal & linefeed
                            end try
                        end repeat
                    end if
                end if

                return output
            end tell
        end tell
        """

        if let result = runAppleScriptWithResult(script) {
            print("--- UI HIERARCHY ---")
            print(result)
            print("--- END ---")
        } else {
            print("[CameraToggle] Failed to dump UI. Make sure Accessibility permission is granted.")
        }
    }

    // MARK: - Private

    /// Build the AppleScript that navigates System Settings and toggles "Allow Camera".
    ///
    /// Flow:
    ///   1. Open System Settings, activate it
    ///   2. Click "Screen Time" in the sidebar
    ///   3. Click "Content & Privacy"
    ///   4. Enable "Content & Privacy" toggle if it's off
    ///   5. Click "App Restrictions"
    ///   6. Click the "Allow Camera" checkbox/switch
    ///   7. Click "Done"
    ///   8. Quit System Settings
    private func buildToggleScript() -> String {
        return """
        -- 1. Open System Settings
        tell application "System Settings"
            activate
        end tell
        delay 2

        tell application "System Events"
            tell process "System Settings"
                set frontmost to true
                delay 1

                -- 2. Click "Screen Time" in the sidebar
                set allElems to entire contents of window 1
                set stFound to false
                repeat with elem in allElems
                    try
                        if (name of elem) is "Screen Time" and (role of elem as string) is "AXStaticText" then
                            click elem
                            set stFound to true
                            exit repeat
                        end if
                    end try
                end repeat

                if not stFound then
                    tell application "System Settings" to quit
                    return "FAIL: Could not find Screen Time in sidebar"
                end if

                delay 2

                -- 3. Click "Content & Privacy"
                set allElems to entire contents of window 1
                set cpFound to false
                repeat with elem in allElems
                    try
                        set eName to name of elem
                        if eName contains "Content" and eName contains "Privacy" then
                            click elem
                            set cpFound to true
                            exit repeat
                        end if
                    end try
                end repeat

                if not cpFound then
                    tell application "System Settings" to quit
                    return "FAIL: Could not find Content & Privacy"
                end if

                delay 2

                -- 4. Check if Content & Privacy toggle needs to be enabled
                set allElems to entire contents of window 1
                repeat with elem in allElems
                    try
                        set eName to name of elem
                        set eRole to role of elem as string
                        if (eName contains "Content" and eName contains "Privacy") and (eRole is "AXCheckBox" or eRole is "AXSwitch") then
                            set eVal to value of elem
                            if eVal is 0 then
                                click elem
                                delay 1.5
                                set allElems to entire contents of window 1
                            end if
                            exit repeat
                        end if
                    end try
                end repeat

                -- 5. Click "App Restrictions"
                set arFound to false
                repeat with elem in allElems
                    try
                        set eName to name of elem
                        if eName contains "App Restriction" or eName contains "App restrictions" then
                            click elem
                            set arFound to true
                            exit repeat
                        end if
                    end try
                end repeat

                if arFound then
                    delay 2
                    set allElems to entire contents of window 1
                end if

                -- 6. Find and click the "Allow Camera" toggle
                set camFound to false

                -- Try exact match on name with checkbox/switch role
                repeat with elem in allElems
                    try
                        set eName to name of elem
                        set eRole to role of elem as string
                        if eName is "Allow Camera" and (eRole is "AXCheckBox" or eRole is "AXSwitch") then
                            click elem
                            set camFound to true
                            exit repeat
                        end if
                    end try
                end repeat

                -- Fallback: try description match
                if not camFound then
                    repeat with elem in allElems
                        try
                            set eDesc to description of elem as string
                            set eRole to role of elem as string
                            if eDesc is "Allow Camera" and (eRole is "AXCheckBox" or eRole is "AXSwitch") then
                                click elem
                                set camFound to true
                                exit repeat
                            end if
                        end try
                    end repeat
                end if

                -- Fallback: partial name match containing "Camera"
                if not camFound then
                    repeat with elem in allElems
                        try
                            set eName to name of elem
                            set eRole to role of elem as string
                            if eName contains "Camera" and (eRole is "AXCheckBox" or eRole is "AXSwitch") then
                                click elem
                                set camFound to true
                                exit repeat
                            end if
                        end try
                    end repeat
                end if

                if not camFound then
                    tell application "System Settings" to quit
                    return "FAIL: Could not find Allow Camera toggle"
                end if

                delay 0.5

                -- 7. Click "Done" button (if present in a sheet/dialog)
                set allElems to entire contents of window 1
                repeat with elem in allElems
                    try
                        if (name of elem) is "Done" and (role of elem as string) is "AXButton" then
                            click elem
                            exit repeat
                        end if
                    end try
                end repeat

            end tell
        end tell

        delay 0.5

        -- 8. Quit System Settings
        tell application "System Settings" to quit

        return "SUCCESS"
        """
    }

    private func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            print("[CameraToggle] AppleScript error: \(error)")
            return false
        }
        return true
    }

    private func runAppleScriptWithResult(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error = error {
            print("[CameraToggle] AppleScript error: \(error)")
            return nil
        }
        return result.stringValue
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let cameraManager = CameraManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        updateIcon()

        print("[CameraToggle] App launched. Look for the camera icon in the menu bar.")
        print("[CameraToggle] IMPORTANT: Grant Accessibility permission to this app in")
        print("  System Settings > Privacy & Security > Accessibility")
    }

    // MARK: NSMenuDelegate - rebuild menu each time it opens

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        let isDisabled = cameraManager.isCameraDisabled

        // ---- Status header ----
        let header = NSMenuItem(
            title: isDisabled ? "Camera: OFF" : "Camera: ON",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        if #available(macOS 11.0, *) {
            let symbolName = isDisabled ? "camera.slash" : "camera"
            header.image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )
        }
        menu.addItem(header)

        menu.addItem(NSMenuItem.separator())

        // ---- Toggle action ----
        let toggleItem = NSMenuItem(
            title: isDisabled ? "Enable Camera" : "Disable Camera",
            action: #selector(toggleCamera),
            keyEquivalent: "t"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // ---- Debug: Dump UI ----
        let debugItem = NSMenuItem(
            title: "Debug: Dump UI Elements",
            action: #selector(debugDumpUI),
            keyEquivalent: "d"
        )
        debugItem.target = self
        menu.addItem(debugItem)

        // ---- Reset State ----
        let resetItem = NSMenuItem(
            title: "Reset State to Camera ON",
            action: #selector(resetState),
            keyEquivalent: "r"
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // ---- Quit ----
        let quitItem = NSMenuItem(
            title: "Quit CameraToggle",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: Actions

    @objc private func toggleCamera() {
        let success = cameraManager.toggle()
        updateIcon()

        if success {
            let isDisabled = cameraManager.isCameraDisabled
            showNotification(
                title: "CameraToggle",
                message: isDisabled
                    ? "Camera has been disabled."
                    : "Camera has been enabled."
            )
        } else {
            showNotification(
                title: "CameraToggle",
                message: "Toggle failed. Run from Terminal to see details."
            )
        }
    }

    @objc private func debugDumpUI() {
        print("[CameraToggle] Starting UI dump (run from Terminal to see output) ...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.cameraManager.dumpUI()
        }
    }

    /// Reset locally tracked state to Camera ON without touching System Settings.
    /// Use this if the menu bar icon gets out of sync with the actual setting.
    @objc private func resetState() {
        cameraManager.isCameraDisabled = false
        updateIcon()
        showNotification(
            title: "CameraToggle",
            message: "State reset to Camera ON. (Icon only - does not change the actual setting.)"
        )
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: Helpers

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let isDisabled = cameraManager.isCameraDisabled

        if #available(macOS 11.0, *) {
            let name = isDisabled ? "camera.slash.fill" : "camera.fill"
            let image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: "Camera Toggle"
            )
            image?.isTemplate = true          // adapts to light / dark menu bar
            button.image = image
        } else {
            button.title = isDisabled ? "CAM OFF" : "CAM ON"
        }
    }

    /// Uses osascript `display notification` for a lightweight notification.
    private func showNotification(title: String, message: String) {
        let safeTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let safeMsg = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = """
        display notification "\(safeMsg)" with title "\(safeTitle)"
        """
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(nil)
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu-bar-only; no Dock icon
app.run()
