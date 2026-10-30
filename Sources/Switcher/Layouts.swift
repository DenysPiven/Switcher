import Carbon
import Foundation

/// A physical key press. It does not depend on the layout, so the same
/// strokes can be rendered in any layout.
struct KeyStroke {
    let code: UInt16
    let shift: Bool
    let caps: Bool

    var modIndex: Int { (shift ? 1 : 0) | (caps ? 2 : 0) }
}

func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
    guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? T
}

/// A keyboard layout with a precomputed keycode -> character table,
/// so lookups while typing cost nothing.
final class Layout {
    let source: TISInputSource
    let id: String
    let isLatin: Bool
    /// Spell checker language for words typed in this layout.
    let language: String
    private let table: [[String]] // [modIndex][keyCode]

    init?(source: TISInputSource) {
        guard let id: String = property(source, kTISPropertyInputSourceID),
              let data: Data = property(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        self.source = source
        self.id = id

        let kbdType = UInt32(LMGetKbdType())
        var table = Array(repeating: Array(repeating: "", count: 128), count: 4)
        data.withUnsafeBytes { raw in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            for mod in 0..<4 {
                var modifiers: UInt32 = 0
                if mod & 1 != 0 { modifiers |= UInt32(shiftKey >> 8) }
                if mod & 2 != 0 { modifiers |= UInt32(alphaLock >> 8) }
                for code in 0..<128 {
                    var deadKeyState: UInt32 = 0
                    var chars = [UniChar](repeating: 0, count: 4)
                    var length = 0
                    let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), modifiers, kbdType,
                                                OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState,
                                                chars.count, &length, &chars)
                    if status == noErr, length > 0 {
                        table[mod][code] = String(utf16CodeUnits: chars, count: length)
                    }
                }
            }
        }
        guard !table[0].allSatisfy(\.isEmpty) else { return nil }
        self.table = table

        let a = table[0][Int(kVK_ANSI_A)]
        isLatin = !a.isEmpty && a.unicodeScalars.allSatisfy { $0.isASCII && $0.properties.isAlphabetic }
        let languages: [String] = property(source, kTISPropertyInputSourceLanguages) ?? []
        if isLatin {
            language = languages.contains("en") ? "en" : (languages.first ?? "en")
        } else {
            language = languages.first ?? "uk"
        }
    }

    func char(_ stroke: KeyStroke) -> String {
        stroke.code < 128 ? table[stroke.modIndex][Int(stroke.code)] : ""
    }

    func text(_ strokes: [KeyStroke]) -> String {
        strokes.map(char).joined()
    }

    /// True if the key types a visible character (not space, arrows, F-keys...).
    func isPrintable(_ stroke: KeyStroke) -> Bool {
        guard let scalar = char(stroke).unicodeScalars.first else { return false }
        return scalar.value >= 0x21 && scalar.value != 0x7F && !scalar.properties.isWhitespace
    }

    /// Reverse lookup, used by the self-test.
    func strokes(for text: String) -> [KeyStroke]? {
        var result: [KeyStroke] = []
        for ch in text {
            let s = String(ch)
            guard let hit = (0..<128).lazy.flatMap({ code in [false, true].map { KeyStroke(code: UInt16(code), shift: $0, caps: false) } })
                .first(where: { self.char($0) == s }) else { return nil }
            result.append(hit)
        }
        return result
    }
}

/// Enabled keyboard layouts and the currently selected one.
final class Layouts {
    private(set) var all: [Layout] = []
    private(set) var current: Layout?

    init() { reload() }

    func reload() {
        let filter = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String] as CFDictionary
        let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        all = list.compactMap(Layout.init)
        refreshCurrent()
    }

    func refreshCurrent() {
        let id: String? = TISCopyCurrentKeyboardInputSource().map { property($0.takeRetainedValue(), kTISPropertyInputSourceID) } ?? nil
        let layoutID: String? = TISCopyCurrentKeyboardLayoutInputSource().map { property($0.takeRetainedValue(), kTISPropertyInputSourceID) } ?? nil
        current = all.first { $0.id == id } ?? all.first { $0.id == layoutID }
    }

    /// The layout to convert to: Latin <-> non-Latin (Cyrillic).
    func counterpart(of layout: Layout) -> Layout? {
        all.first { $0.isLatin != layout.isLatin }
    }

    func select(_ layout: Layout) {
        TISSelectInputSource(layout.source)
        current = layout
    }
}
