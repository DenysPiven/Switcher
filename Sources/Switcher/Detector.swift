import AppKit

/// Decides whether a word was typed in the wrong layout, using the
/// system spell checker (it ships with English, Ukrainian, Russian, ...).
final class Detector {
    private let checker = NSSpellChecker.shared

    /// The first lookup loads the dictionary, so do it before the user types.
    func warmUp(_ languages: [String]) {
        for language in Set(languages) { _ = isWord("test", language) }
    }

    func isWord(_ word: String, _ language: String) -> Bool {
        let range = checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false,
                                          inSpellDocumentWithTag: 0, wordCount: nil)
        return range.location == NSNotFound
    }

    /// The word without surrounding punctuation, or nil if it is not a plain word.
    static func core(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: CharacterSet.letters.inverted)
        guard trimmed.count >= 2 else { return nil }
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "'’ʼ-"))
        guard trimmed.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return trimmed
    }

    /// Convert only when the typed text is not a word and the converted one is.
    func shouldConvert(_ typed: String, from: Layout, to converted: String, in target: Layout) -> Bool {
        if let word = Self.core(typed), isWord(word, from.language) { return false }
        guard let word = Self.core(converted) else { return false }
        return isWord(word, target.language)
    }
}
