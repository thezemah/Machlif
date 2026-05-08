import Cocoa
@preconcurrency import CoreGraphics

@MainActor
final class TriggerDetector {

    var onTrigger: (() -> Void)?
    var onTapDisabled: (() -> Void)?
    var maxInterval: CFTimeInterval = 0.4
    var config: TriggerConfig = LanguagePreferences.triggerConfig

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Double-tap state
    private var lastModDownAt: CFTimeInterval = 0
    private var modIsDown = false
    private var otherKeyPressed = false

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let det = Unmanaged<TriggerDetector>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { det.handle(type: type, event: event) }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type.rawValue >= 0xFFFFFFFE {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            onTapDisabled?()
            return
        }

        switch config.mode {
        case .doubleTap:
            handleDoubleTap(type: type, event: event)
        case .hotkey:
            handleHotkey(type: type, event: event)
        }
    }

    // MARK: - Double-tap

    private func handleDoubleTap(type: CGEventType, event: CGEvent) {
        switch type {
        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard config.doubleTapModifier.keyCodes.contains(keyCode) else { return }

            let isDown = event.flags.contains(config.doubleTapModifier.eventFlag)

            if isDown && !modIsDown {
                let now = CACurrentMediaTime()
                let interval = now - lastModDownAt
                if interval > 0 && interval <= maxInterval && !otherKeyPressed {
                    lastModDownAt = 0
                    modIsDown = isDown
                    otherKeyPressed = false
                    onTrigger?()
                    return
                }
                lastModDownAt = now
                otherKeyPressed = false
            }
            modIsDown = isDown

        case .keyDown:
            otherKeyPressed = true

        default:
            break
        }
    }

    // MARK: - Hotkey (listen-only — event also reaches other apps)

    private func handleHotkey(type: CGEventType, event: CGEvent) {
        guard type == .keyDown else { return }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == config.hotkeyKeyCode else { return }

        let targetFlags = CGEventFlags(rawValue: config.hotkeyModifierFlags)
        let modMask: CGEventFlags = [.maskShift, .maskAlternate, .maskCommand, .maskControl]
        guard event.flags.intersection(modMask) == targetFlags.intersection(modMask) else { return }

        onTrigger?()
    }
}
