import Cocoa
import CoreGraphics
import MachlifCore

enum SelectionRoundTrip {

    private static let kVK_ANSI_C: CGKeyCode = 0x08
    private static let kVK_ANSI_V: CGKeyCode = 0x09

    static func run() {
        let pasteboard = NSPasteboard.general
        let originalChangeCount = pasteboard.changeCount
        let snapshot = snapshotPasteboard(pasteboard)

        postCommandKey(kVK_ANSI_C)

        guard let copied = waitForPasteboardChange(pasteboard, since: originalChangeCount) else {
            return
        }

        let converted: String
        if let maps = HebrewLayoutDetector.bestMaps(for: copied) {
            converted = LayoutConverter.convert(copied, hebrewToEnglish: maps.hebrewToEnglish, englishToHebrew: maps.englishToHebrew)
        } else {
            converted = LayoutConverter.convert(copied)
        }
        if converted == copied { return }

        pasteboard.clearContents()
        pasteboard.setString(converted, forType: .string)

        postCommandKey(kVK_ANSI_V)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            restorePasteboard(pasteboard, from: snapshot)
        }
    }

    private static func postCommandKey(_ key: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func waitForPasteboardChange(
        _ pasteboard: NSPasteboard,
        since originalChangeCount: Int
    ) -> String? {
        for _ in 0..<8 {
            Thread.sleep(forTimeInterval: 0.03)
            if pasteboard.changeCount != originalChangeCount {
                return pasteboard.string(forType: .string)
            }
        }
        return nil
    }

    private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    private static func restorePasteboard(
        _ pasteboard: NSPasteboard,
        from snapshot: [[NSPasteboard.PasteboardType: Data]]
    ) {
        pasteboard.clearContents()
        let items = snapshot.map { typeMap -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in typeMap {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
