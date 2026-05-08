import Cocoa
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {

    static let shared = PreferencesWindowController()

    private init() {
        let hosting = NSHostingController(rootView: PreferencesView())
        let win = NSWindow(contentViewController: hosting)
        win.title = "Machlif Preferences"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        super.init(window: win)
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
