import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let detector = ShiftDoubleTapDetector()
    private var enabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        rebuildMenu()

        detector.onDoubleTap = { [weak self] in
            guard let self = self, self.enabled else { return }
            SelectionRoundTrip.run()
        }

        if PermissionsHelper.isAccessibilityTrusted() {
            _ = detector.start()
        } else {
            PermissionsHelper.promptForAccessibility()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        detector.stop()
    }

    @objc private func appBecameActive() {
        rebuildMenu()
        if PermissionsHelper.isAccessibilityTrusted() {
            _ = detector.start()
        }
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "מ"
            button.toolTip = "Machlif — Hebrew/English layout switcher"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let trusted = PermissionsHelper.isAccessibilityTrusted()
        let statusTitle = trusted ? "Machlif: ready" : "Machlif: needs Accessibility"
        let statusItemEntry = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItemEntry.isEnabled = false
        menu.addItem(statusItemEntry)

        menu.addItem(NSMenuItem.separator())

        let enabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = enabled ? .on : .off
        menu.addItem(enabledItem)

        if !trusted {
            let grant = NSMenuItem(
                title: "Grant Accessibility…",
                action: #selector(openAccessibility),
                keyEquivalent: ""
            )
            grant.target = self
            menu.addItem(grant)
        }

        if #available(macOS 13.0, *) {
            let login = NSMenuItem(
                title: "Open at Login",
                action: #selector(toggleLoginItem),
                keyEquivalent: ""
            )
            login.target = self
            login.state = LoginItemHelper.isEnabled ? .on : .off
            menu.addItem(login)
        }

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(
            title: "Quit Machlif",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        rebuildMenu()
    }

    @objc private func openAccessibility() {
        PermissionsHelper.openAccessibilitySettings()
    }

    @objc private func toggleLoginItem() {
        guard #available(macOS 13.0, *) else { return }
        _ = LoginItemHelper.setEnabled(!LoginItemHelper.isEnabled)
        rebuildMenu()
    }
}
