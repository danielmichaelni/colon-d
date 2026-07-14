import AppKit
import Carbon

struct KeyInfo {
    let keyCode: CGKeyCode
    let characters: String?
    let flags: CGEventFlags
    let isReplacementEvent: Bool

    nonisolated init(event: CGEvent) {
        keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        characters = NSEvent(cgEvent: event)?.characters
        flags = event.flags
        isReplacementEvent = SyntheticReplacementEventTag.isTagged(event)
    }

    nonisolated init(
        keyCode: CGKeyCode,
        characters: String?,
        flags: CGEventFlags = [],
        isReplacementEvent: Bool = false
    ) {
        self.keyCode = keyCode
        self.characters = characters
        self.flags = flags
        self.isReplacementEvent = isReplacementEvent
    }

    var usesEditingModifier: Bool {
        flags.contains(.maskControl)
            || flags.contains(.maskCommand)
            || flags.contains(.maskAlternate)
    }

    var isSpaceKey: Bool {
        keyCode == CGKeyCode(kVK_Space)
    }

    var usesPickerControlModifier: Bool {
        !flags.intersection([.maskControl, .maskCommand, .maskAlternate, .maskShift]).isEmpty
    }
}

@MainActor
final class GlobalKeyEventTap {
    enum StartError: Error {
        case unableToCreateTap
    }

    private let options: CGEventTapOptions
    private let onKeyDown: (KeyInfo) -> Bool
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        options: CGEventTapOptions,
        onKeyDown: @escaping (KeyInfo) -> Bool
    ) {
        self.options = options
        self.onKeyDown = onKeyDown
    }

    var isRunning: Bool {
        eventTap != nil
    }

    func start() throws {
        guard eventTap == nil else { return }

        let mask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: options,
                eventsOfInterest: CGEventMask(mask),
                callback: Self.eventTapCallback,
                userInfo: refcon
            )
        else {
            throw StartError.unableToCreateTap
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return true
        }

        guard type == .keyDown else {
            return true
        }

        return onKeyDown(KeyInfo(event: event))
    }

    private nonisolated static let eventTapCallback: CGEventTapCallBack = {
        _,
        type,
        event,
        userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let eventTap = Unmanaged<GlobalKeyEventTap>.fromOpaque(userInfo).takeUnretainedValue()
        // The tap source is installed on CFRunLoopGetMain(), so callbacks run on the main run loop.
        let shouldForward: Bool = MainActor.assumeIsolated {
            let shouldForward = eventTap.handle(type: type, event: event)
            return eventTap.options == .listenOnly || shouldForward
        }
        return shouldForward ? Unmanaged.passUnretained(event) : nil
    }
}
