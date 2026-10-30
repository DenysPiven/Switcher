import AppKit
import Carbon

/// Marks events we post ourselves so the tap lets them through untouched.
private let ownEventMarker: Int64 = 0x5357_4954

/// Apps where automatic correction is off by default (code, terminals).
/// The manual hotkey still works there.
private let defaultExcludedApps: Set<String> = [
    "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
    "net.kovidgoyal.kitty", "org.alacritty", "com.apple.dt.Xcode", "com.microsoft.VSCode",
    "com.todesktop.230313mzl4w4u92", "com.sublimetext.4", "com.apple.keychainaccess",
]
private let excludedPrefixes = ["com.jetbrains."]

/// Watches the keyboard through a CGEventTap, remembers the keys of the
/// current word and retypes it in the other layout when needed.
///
/// Everything runs on the main thread. Per keystroke the work is an array
/// append; the spell check happens only on space, and takes well under 1 ms.
final class Engine {
    private let layouts = Layouts()
    private let detector = Detector()
    private let eventSource = CGEventSource(stateID: .privateState)
    private let defaults = UserDefaults.standard
    private var tap: CFMachPort?

    private var keys: [KeyStroke] = []
    /// A space was typed right after `keys`.
    private var wordEnded = false
    /// Original text of a word we just auto-corrected, so the hotkey can undo it.
    private var autoCorrected: String?
    private var autoEnabled = true
    private var lastOwnSwitch: TimeInterval = 0
    private var exceptions: Set<String>
    private let excludedApps: Set<String>

    // Double-Shift detection.
    private var shiftDown = false
    private var shiftClean = false
    private var shiftDownAt: TimeInterval = 0
    private var lastShiftTap: TimeInterval = 0

    private let maxAutoWordLength = 30
    private let maxWordLength = 60

    init() {
        exceptions = Set(defaults.stringArray(forKey: "Exceptions") ?? [])
        excludedApps = defaultExcludedApps.union(defaults.stringArray(forKey: "ExcludedApps") ?? [])
        detector.warmUp(layouts.all.map(\.language))
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: - Setup

    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                Unmanaged<Engine>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        observe()
        return true
    }

    private func observe() {
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
                                object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.layouts.refreshCurrent()
            // The user switched layout by hand in the middle of a word.
            if self.now - self.lastOwnSwitch > 0.5 { self.reset() }
        }
        distributed.addObserver(forName: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
                                object: nil, queue: .main) { [weak self] _ in
            self?.layouts.reload()
            self?.reset()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.appActivated(app?.bundleIdentifier)
        }
        appActivated(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    private func appActivated(_ bundleID: String?) {
        reset()
        let id = bundleID ?? ""
        autoEnabled = !excludedApps.contains(id) && !excludedPrefixes.contains { id.hasPrefix($0) }
    }

    // MARK: - Events

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        case .keyDown:
            if event.getIntegerValueField(.eventSourceUserData) == ownEventMarker { return pass }
            return keyDown(event) ? nil : pass
        case .flagsChanged:
            flagsChanged(event.flags)
            return pass
        default: // mouse click: the caret may have moved
            reset()
            return pass
        }
    }

    /// Returns true if the event must be swallowed.
    private func keyDown(_ event: CGEvent) -> Bool {
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        shiftClean = false
        lastShiftTap = 0

        if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            reset()
            return false
        }
        switch code {
        case kVK_Space:
            return spacePressed()
        case kVK_Delete:
            autoCorrected = nil
            if wordEnded { wordEnded = false } else if !keys.isEmpty { keys.removeLast() }
            return false
        default:
            break
        }

        let stroke = KeyStroke(code: UInt16(code), shift: flags.contains(.maskShift), caps: flags.contains(.maskAlphaShift))
        guard let layout = layouts.current, layout.isPrintable(stroke) else {
            reset() // Return, Tab, arrows, Esc, F-keys...
            return false
        }
        if wordEnded { reset() }
        if keys.count < maxWordLength { keys.append(stroke) }
        return false
    }

    private func spacePressed() -> Bool {
        guard !wordEnded, !keys.isEmpty else {
            reset()
            return false
        }
        wordEnded = true
        guard autoEnabled, (2...maxAutoWordLength).contains(keys.count),
              let from = layouts.current, let to = layouts.counterpart(of: from) else { return false }

        let typed = from.text(keys)
        let converted = to.text(keys)
        guard !exceptions.contains(typed.lowercased()),
              detector.shouldConvert(typed, from: from, to: converted, in: to) else { return false }

        // Swallow the space and retype the word plus space in the right layout.
        replace(deleting: keys.count, with: converted + " ")
        select(to)
        autoCorrected = typed
        return true
    }

    private func flagsChanged(_ flags: CGEventFlags) {
        let shift = flags.contains(.maskShift)
        let otherModifiers = !flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn]).isEmpty
        let t = now
        if shift && !shiftDown {
            shiftClean = !otherModifiers
            shiftDownAt = t
        } else if !shift && shiftDown {
            if shiftClean && !otherModifiers && t - shiftDownAt < 0.3 {
                if t - lastShiftTap < 0.4 {
                    lastShiftTap = 0
                    convertLastWord()
                } else {
                    lastShiftTap = t
                }
            } else {
                lastShiftTap = 0
            }
        } else {
            shiftClean = false
        }
        shiftDown = shift
    }

    // MARK: - Actions

    /// Double Shift: convert the last word to the other layout, or undo an auto-correction.
    private func convertLastWord() {
        guard !keys.isEmpty, let from = layouts.current, let to = layouts.counterpart(of: from) else { return }
        if let original = autoCorrected {
            // The user did not want this correction; never repeat it.
            exceptions.insert(original.lowercased())
            defaults.set(Array(exceptions), forKey: "Exceptions")
            autoCorrected = nil
        }
        let suffix = wordEnded ? " " : ""
        replace(deleting: keys.count + suffix.count, with: to.text(keys) + suffix)
        select(to)
    }

    private func select(_ layout: Layout) {
        lastOwnSwitch = now
        layouts.select(layout)
    }

    private func reset() {
        keys.removeAll(keepingCapacity: true)
        wordEnded = false
        autoCorrected = nil
    }

    // MARK: - Typing

    private func replace(deleting count: Int, with text: String) {
        for _ in 0..<count { postKey(CGKeyCode(kVK_Delete)) }
        for ch in text {
            if ch == " " {
                postKey(CGKeyCode(kVK_Space))
            } else {
                postKey(0, text: Array(String(ch).utf16))
            }
        }
    }

    private func postKey(_ code: CGKeyCode, text: [UniChar]? = nil) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: down) else { continue }
            event.flags = []
            if let text { event.keyboardSetUnicodeString(stringLength: text.count, unicodeString: text) }
            event.setIntegerValueField(.eventSourceUserData, value: ownEventMarker)
            event.post(tap: .cghidEventTap)
        }
    }
}
