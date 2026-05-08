import AppKit
import SwiftUI

// A button-like control that records a key combination when clicked.
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: UInt16
    @Binding var modifierFlags: UInt64
    @Binding var displayName: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> RecorderControl {
        let v = RecorderControl()
        v.coordinator = context.coordinator
        return v
    }

    func updateNSView(_ v: RecorderControl, context: Context) {
        if !v.isRecording { v.label = displayName }
    }

    // MARK: - Coordinator

    final class Coordinator {
        var parent: ShortcutRecorderView
        init(_ parent: ShortcutRecorderView) { self.parent = parent }

        @MainActor func commit(keyCode: UInt16, flags: CGEventFlags, name: String) {
            parent.keyCode = keyCode
            parent.modifierFlags = flags.rawValue
            parent.displayName = name
        }
    }
}

// MARK: - RecorderControl

final class RecorderControl: NSView {
    weak var coordinator: ShortcutRecorderView.Coordinator?

    var label: String = "Click to record shortcut" {
        didSet { needsDisplay = true }
    }
    var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard !isRecording else { return }
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }

        if event.keyCode == 53 { // Escape — cancel
            isRecording = false
            return
        }

        let nsFlags = event.modifierFlags.intersection([.shift, .option, .command, .control])
        guard !nsFlags.isEmpty else { return } // require at least one modifier

        var cgFlags = CGEventFlags()
        if nsFlags.contains(.control) { cgFlags.insert(.maskControl) }
        if nsFlags.contains(.option)  { cgFlags.insert(.maskAlternate) }
        if nsFlags.contains(.shift)   { cgFlags.insert(.maskShift) }
        if nsFlags.contains(.command) { cgFlags.insert(.maskCommand) }

        let raw = event.charactersIgnoringModifiers ?? ""
        let keyStr = keySymbol(keyCode: event.keyCode) ?? raw.uppercased()

        var name = ""
        if nsFlags.contains(.control) { name += "⌃" }
        if nsFlags.contains(.option)  { name += "⌥" }
        if nsFlags.contains(.shift)   { name += "⇧" }
        if nsFlags.contains(.command) { name += "⌘" }
        name += keyStr

        isRecording = false
        coordinator?.commit(keyCode: UInt16(event.keyCode), flags: cgFlags, name: name)
    }

    override func flagsChanged(with event: NSEvent) {} // don't end recording on lone modifier

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5)

        if isRecording {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            NSColor.controlAccentColor.setStroke()
        } else {
            NSColor.controlBackgroundColor.setFill()
            NSColor.separatorColor.setStroke()
        }
        path.fill(); path.lineWidth = 1; path.stroke()

        let text = isRecording ? "Press shortcut… (Esc to cancel)" : label
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: (bounds.width - sz.width) / 2,
                             y: (bounds.height - sz.height) / 2))
    }

    // MARK: - Key symbols

    private func keySymbol(keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return nil
        }
    }
}
