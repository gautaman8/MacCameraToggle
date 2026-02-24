import Cocoa

// MARK: - Camera Manager

/// Manages camera enable/disable state by automating the Screen Time
/// "Allow Camera" toggle in System Settings via AppleScript UI scripting.
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
    /// Returns true if the AppleScript executed without error.
    @discardableResult
    func toggle() -> Bool {
        let wantDisabled = !isCameraDisabled

        print("[CameraToggle] Toggling camera to \(wantDisabled ? "DISABLED" : "ENABLED") ...")

        let script = buildToggleScript()

        if runAppleScript(script) {
            isCameraDisabled = wantDisabled
            print("[CameraToggle] Success. Camera is now \(wantDisabled ? "DISABLED" : "ENABLED").")
            return true
        }
        print("[CameraToggle] Toggle failed.")
        return false
    }

    /// Dump the UI element hierarchy of the current System Settings window.
    /// Useful for debugging when the toggle script can't find elements.
    /// Run the app from Terminal to see the output.
    func dumpUI() {
        print("[CameraToggle] Opening System Settings and dumping UI hierarchy ...")
        print("[CameraToggle] This may take several seconds ...")

        let script = """
        do shell script "open 'x-apple.systempreferences:com.apple.ScreenTime-Settings.extension'"
        delay 3

        tell application "System Events"
            tell process "System Settings"
                set frontmost to true
                delay 1

                set output to ""
                set allElems to entire contents of window 1
                repeat with elem in allElems
                    try
                        set elemClass to class of elem as string
                        set elemName to ""
                        try
                            set elemName to name of elem
                        end try
                        set elemRole to ""
                        try
                            set elemRole to role of elem as string
                        end try
                        set elemDesc to ""
                        try
                            set elemDesc to description of elem as string
                        end try
                        set elemVal to ""
                        try
                            set elemVal to value of elem as string
                        end try
                        set output to output & elemClass & " | name=" & elemName & " | role=" & elemRole & " | desc=" & elemDesc & " | val=" & elemVal & linefeed
                    end try
                end repeat
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
    /// Flow (macOS Sonoma / Sequoia):
    ///   1. Open System Settings > Screen Time
    ///   2. Search for "Content & Privacy" row and click it
    ///   3. Wait, then search for "App Restrictions" row and click it
    ///   4. In the resulting sheet, find the "Allow Camera" checkbox and click it
    ///   5. Click "Done"
    ///   6. Quit System Settings
    private func buildToggleScript() -> String {
        return """
        -- 1. Open Screen Time pane
        do shell script "open 'x-apple.systempreferences:com.apple.ScreenTime-Settings.extension'"
        delay 2

        tell application "System Events"
            tell process "System Settings"
                set frontmost to true
                delay 1

                -- Helper: get flat list of every UI element in window
                set allElems to entire contents of window 1

                -- 2. Click "Content & Privacy" (static text, button, or row)
                set cpFound to false
                repeat with elem in allElems
                    try
                        set eName to name of elem
                        if eName contains "Content" and eName contains "Privacy" then
                            set elemRole to role of elem as string
                            if elemRole is "AXStaticText" or elemRole is "AXButton" or elemRole is "AXCell" or elemRole is "AXGroup" or elemRole is "AXRow" then
                                click elem
                                set cpFound to true
                                exit repeat
                            end if
                        end if
                    end try
                end repeat

                if not cpFound then
                    repeat with elem in allElems
                        try
                            set eDesc to description of elem as string
                            if eDesc contains "Content" and eDesc contains "Privacy" then
                                click elem
                                set cpFound to true
                                exit repeat
                            end if
                        end try
                    end repeat
                end if

                delay 1.5

                -- 3. Click "App Restrictions" (if a separate sub-page)
                set allElems to entire contents of window 1
                repeat with elem in allElems
                    try
                        set eName to name of elem
                        if eName contains "App Restriction" then
                            click elem
                            exit repeat
                        end if
                    end try
                end repeat

                delay 1.5

                -- 4. Find and click the "Allow Camera" checkbox / toggle
                set allElems to entire contents of window 1
                set camFound to false
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

                delay 0.5

                -- 5. Click "Done" button
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

        -- 6. Quit System Settings
        tell application "System Settings" to quit
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
                message: "Toggle failed. Check Accessibility permission and run from Terminal for debug output."
            )
        }
    }

    @objc private func debugDumpUI() {
        print("[CameraToggle] Starting UI dump (run from Terminal to see output) ...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.cameraManager.dumpUI()
        }
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
