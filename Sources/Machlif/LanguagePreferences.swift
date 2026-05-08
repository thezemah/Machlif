import Carbon
import Foundation

extension Notification.Name {
    static let preferencesChanged = Notification.Name("MachlifPreferencesChanged")
}

// MARK: - Trigger config

enum ModifierKey: String, Codable, CaseIterable, Identifiable {
    case shift, option, command, control
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .shift:   return "Shift ⇧"
        case .option:  return "Option ⌥"
        case .command: return "Command ⌘"
        case .control: return "Control ⌃"
        }
    }
    var keyCodes: [Int64] {
        switch self {
        case .shift:   return [56, 60]
        case .option:  return [58, 61]
        case .command: return [55, 54]
        case .control: return [59, 62]
        }
    }
    var eventFlag: CGEventFlags {
        switch self {
        case .shift:   return .maskShift
        case .option:  return .maskAlternate
        case .command: return .maskCommand
        case .control: return .maskControl
        }
    }
}

struct TriggerConfig: Codable, Equatable {
    enum Mode: String, Codable { case doubleTap, hotkey }
    var mode: Mode = .doubleTap
    var doubleTapModifier: ModifierKey = .shift
    var hotkeyKeyCode: UInt16 = 0
    var hotkeyModifierFlags: UInt64 = 0
    var hotkeyDisplayName: String = ""
}

enum LanguagePreferences {
    private static let enabledKey = "enabledLayoutIDs"
    private static let intervalKey = "doubleTapInterval"

    static var enabledLayoutIDs: Set<String>? {
        get {
            guard let arr = UserDefaults.standard.array(forKey: enabledKey) as? [String] else { return nil }
            return Set(arr)
        }
        set {
            if let ids = newValue {
                UserDefaults.standard.set(Array(ids), forKey: enabledKey)
            } else {
                UserDefaults.standard.removeObject(forKey: enabledKey)
            }
            NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        }
    }

    static var doubleTapInterval: Double {
        get {
            let v = UserDefaults.standard.double(forKey: intervalKey)
            return v == 0 ? 0.4 : v
        }
        set {
            UserDefaults.standard.set(newValue, forKey: intervalKey)
            NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        }
    }

    private static let triggerKey = "triggerConfig"
    static var triggerConfig: TriggerConfig {
        get {
            guard let data = UserDefaults.standard.data(forKey: triggerKey),
                  let config = try? JSONDecoder().decode(TriggerConfig.self, from: data)
            else { return TriggerConfig() }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: triggerKey)
            }
            NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        }
    }
}
