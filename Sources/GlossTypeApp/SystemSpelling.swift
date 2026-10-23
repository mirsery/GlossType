import AppKit
import GlossTypeCore

/// 系统拼写检查（NSSpellChecker），只查英文。
final class SystemSpelling: SpellingProvider {
    private let language = "en"
    private var checker: NSSpellChecker { .shared }

    func isCorrectlySpelled(_ word: String) -> Bool {
        let range = checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        return range.location == NSNotFound
    }

    func corrections(for word: String) -> [String] {
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.guesses(forWordRange: range, in: word, language: language, inSpellDocumentWithTag: 0) ?? []
    }

    func completions(for prefix: String) -> [String] {
        let range = NSRange(location: 0, length: (prefix as NSString).length)
        return checker.completions(forPartialWordRange: range, in: prefix, language: language, inSpellDocumentWithTag: 0) ?? []
    }
}
