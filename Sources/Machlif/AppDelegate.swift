import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let detector = ShiftDoubleTapDetector()
    private var enabled = true
    private var permissionPoller: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()

        detector.onDoubleTap = { [weak self] in
            guard let self, self.enabled else { return }
            SelectionRoundTrip.run()
        }

        detector.onTapDisabled = { [weak self] in
            guard let self else { return }
            if !PermissionsHelper.isAccessibilityTrusted() {
                self.startPermissionPoller()
                self.rebuildMenu()
            }
        }

        checkAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionPoller?.invalidate()
        detector.stop()
    }

    // MARK: - Accessibility

    private func checkAccessibility() {
        if PermissionsHelper.isAccessibilityTrusted() {
            stopPermissionPoller()
            _ = detector.start()
        } else {
            PermissionsHelper.promptForAccessibility()
            startPermissionPoller()
        }
        rebuildMenu()
    }

    private func startPermissionPoller() {
        guard permissionPoller == nil else { return }
        permissionPoller = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if PermissionsHelper.isAccessibilityTrusted() {
                    self.stopPermissionPoller()
                    _ = self.detector.start()
                    self.rebuildMenu()
                }
            }
        }
    }

    private func stopPermissionPoller() {
        permissionPoller?.invalidate()
        permissionPoller = nil
    }

    // MARK: - Status item

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
        let statusTitle = trusted ? "Machlif: ready" : "Machlif: waiting for Accessibility…"
        let info = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        menu.addItem(NSMenuItem.separator())

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = enabled ? .on : .off
        menu.addItem(enabledItem)

        if !trusted {
            let grant = NSMenuItem(title: "Grant Accessibility…", action: #selector(openAccessibility), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        }

        if #available(macOS 13.0, *) {
            let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
            login.target = self
            login.state = LoginItemHelper.isEnabled ? .on : .off
            menu.addItem(login)
        }

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit Machlif", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Actions

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
