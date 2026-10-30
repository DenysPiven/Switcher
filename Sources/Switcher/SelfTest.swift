import Foundation

/// `Switcher --test`: checks layout tables and detection without the event tap.
enum SelfTest {
    static func run() -> Int32 {
        let layouts = Layouts()
        let detector = Detector()
        for layout in layouts.all {
            print("layout \(layout.id) latin=\(layout.isLatin) lang=\(layout.language)")
        }
        guard let latin = layouts.all.first(where: \.isLatin),
              let other = layouts.all.first(where: { !$0.isLatin }) else {
            print("Need one Latin and one non-Latin layout enabled")
            return 1
        }
        detector.warmUp([latin.language, other.language])

        // (typed text, layout it was typed in, should it be converted?)
        let cases: [(String, Layout, Bool)] = [
            ("ghbdsn", latin, true), ("Ghbdsn", latin, true), ("cmjujlys", latin, true),
            ("[jxe", latin, true), ("k.,jd", latin, true), ("ghbdsn/", latin, true),
            ("yt", latin, true), ("oj,", latin, true),
            ("hello", latin, false), ("on", latin, false), ("world", latin, false),
            ("github", latin, false), ("e.g.", latin, false), ("abc123", latin, false),
            ("руддщ", other, true), ("цщкдв", other, true), ("Рщц", other, true), ("ерфтлі", other, true),
            ("привіт", other, false), ("сьогодні", other, false), ("не", other, false), ("щт", other, true),
        ]
        var failures = 0
        for (typed, from, expected) in cases {
            guard let keys = from.strokes(for: typed), let to = layouts.counterpart(of: from) else {
                print("SKIP \(typed): cannot type it in \(from.id)")
                continue
            }
            let converted = to.text(keys)
            let start = Date()
            let result = detector.shouldConvert(from.text(keys), from: from, to: converted, in: to)
            let ms = Date().timeIntervalSince(start) * 1000
            let ok = result == expected
            if !ok { failures += 1 }
            print(String(format: "%@ %@ -> %@  convert=%@  %.2f ms", ok ? "ok  " : "FAIL", typed, converted,
                         result ? "yes" : "no", ms))
        }
        print(failures == 0 ? "All passed" : "\(failures) failed")
        return failures == 0 ? 0 : 1
    }
}
