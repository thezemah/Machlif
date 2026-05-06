import Cocoa
import CoreGraphics

final class ShiftDoubleTapDetector {

    var onDoubleTap: (() -> Void)?
    var maxInterval: CFTimeInterval = 0.4

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var lastShiftDownAt: CFTimeInterval = 0
    private var shiftIsDown = false
    private var otherKeyPressedSinceLastShift = false

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let detector = Unmanaged<ShiftDoubleTapDetector>.fromOpaque(refcon).takeUnretainedValue()
            detector.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            // kVK_Shift = 56, kVK_RightShift = 60
            guard keyCode == 56 || keyCode == 60 else { return }

            let flags = event.flags
            let nowDown = flags.contains(.maskShift)

            if nowDown && !shiftIsDown {
                let now = CACurrentMediaTime()
                let interval = now - lastShiftDownAt
                if interval > 0 && interval <= maxInterval && !otherKeyPressedSinceLastShift {
                    lastShiftDownAt = 0
                    shiftIsDown = nowDown
                    otherKeyPressedSinceLastShift = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onDoubleTap?()
                    }
                    return
                }
                lastShiftDownAt = now
                otherKeyPressedSinceLastShift = false
            }
            shiftIsDown = nowDown

        case .keyDown:
            otherKeyPressedSinceLastShift = true

        default:
            break
        }
    }
}
