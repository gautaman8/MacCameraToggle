import Cocoa

// MARK: - Camera Manager

/// Manages camera enable/disable state using macOS configuration profiles.
/// Installs a restriction profile (com.apple.applicationaccess with allowCamera=false)
/// to disable the camera, and removes it to re-enable.
class CameraManager {

    static let profileIdentifier = "com.personal.camera-toggle"
    static let profileDisplayName = "Camera Toggle"

    private let stateFileURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".camera-toggle-disabled")
    }()

    private var profileFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("CameraToggle")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("DisableCamera.mobileconfig")
    }

    /// Returns true if the camera is currently disabled (state file exists).
    var isCameraDisabled: Bool {
        return FileManager.default.fileExists(atPath: stateFileURL.path)
    }

    /// Toggles the camera state. Returns true on success.
    @discardableResult
    func toggle() -> Bool {
        if isCameraDisabled {
            return enableCamera()
        } else {
            return disableCamera()
        }
    }

    /// Disables the camera by installing a restriction configuration profile.
    func disableCamera() -> Bool {
        createProfileFile()

        let path = profileFileURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        do shell script "profiles install -path \\"\(path)\\"" with administrator privileges
        """

        if runAppleScript(script) {
            FileManager.default.createFile(atPath: stateFileURL.path, contents: Data())
            return true
        }
        return false
    }

    /// Enables the camera by removing the restriction configuration profile.
    func enableCamera() -> Bool {
        let identifier = Self.profileIdentifier
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        do shell script "profiles remove -identifier \\"\(identifier)\\"" with administrator privileges
        """

        if runAppleScript(script) {
            try? FileManager.default.removeItem(at: stateFileURL)
            try? FileManager.default.removeItem(at: profileFileURL)
            return true
        }
        return false
    }

    /// Writes the .mobileconfig XML profile to disk.
    private func createProfileFile() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
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
                    <string>\(Self.profileIdentifier).restriction</string>
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
            <string>\(Self.profileIdentifier)</string>
            <key>PayloadUUID</key>
            <string>F1E2D3C4-B5A6-4C90-1234-567890ABCDEF</string>
            <key>PayloadDisplayName</key>
            <string>\(Self.profileDisplayName)</string>
            <key>PayloadDescription</key>
            <string>Disables the built-in camera. Managed by CameraToggle menu bar app.</string>
            <key>PayloadOrganization</key>
            <string>Personal</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
        </dict>
        </plist>
        """

        try? xml.write(to: profileFileURL, atomically: true, encoding: .utf8)
    }

    /// Executes an AppleScript string. Returns true on success.
    private func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript error: \(error)")
            return false
        }
        return true
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
                message: "Failed to toggle camera. Make sure you entered the correct admin password."
            )
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
