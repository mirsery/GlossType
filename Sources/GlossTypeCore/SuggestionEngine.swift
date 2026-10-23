import Foundation

/// 系统拼写检查的抽象（App 里用 NSSpellChecker 实现）。
public protocol SpellingProvider: AnyObject {
    func isCorrectlySpelled(_ word: String) -> Bool
    /// 拼写纠错的猜测，按可能性从高到低。
    func corrections(for word: String) -> [String]
    /// 以 prefix 开头的补全。
    func completions(for prefix: String) -> [String]
}

/// 候选的来源与排序：组词补全、下一个词、短语、释义。
public final class SuggestionEngine {
    /// 短语最多几个词（含第一个词）。
    public static let maxPhraseWords = 5
    /// 短语往后接时，续词在该上下文里至少出现的次数。
    public static let minimumPhraseCount = 2
    /// 词表和拼写检查都不认识的词，在语言模型里总共至少出现这么多次才进候选（防止学到的错字冒出来）。
    public static let minimumUnknownWordCount = 2
    /// 拼写纠错最多放几个。
    public static let maxCorrections = 2

    public var languageModel: LanguageModel?
    public var lexicon: WordLexicon?
    public var spelling: SpellingProvider?
    public var glossary: Glossary?

    public init(
        languageModel: LanguageModel? = nil,
        lexicon: WordLexicon? = nil,
        spelling: SpellingProvider? = nil,
        glossary: Glossary? = nil
    ) {
        self.languageModel = languageModel
        self.lexicon = lexicon
        self.spelling = spelling
        self.glossary = glossary
    }

    /// 查语言模型时带几个上下文词。
    public var contextLength: Int {
        max((languageModel?.order ?? 3) - 1, 1)
    }

    /// 词表或系统拼写检查认识这个词。
    public func isKnownWord(_ word: String) -> Bool {
        guard !word.isEmpty else { return false }
        if lexicon?.contains(word.lowercased()) == true { return true }
        return spelling?.isCorrectlySpelled(word) == true
    }

    /// 组词候选：原样排第一，后面是纠错（原样不认识时）、上下文续词、词频补全、拼写补全，
    /// 去重后截到 count 个（含原样）。
    public func completions(for typed: String, context: [String], count: Int) -> [String] {
        guard !typed.isEmpty, count > 0 else { return [] }
        var result = [typed]
        func add(_ display: String) {
            guard result.count < count, !display.isEmpty else { return }
            let cased = TextRules.applyCasing(typed: typed, to: display)
            if !result.contains(cased) { result.append(cased) }
        }
        let key = Self.key(typed)

        if !isKnownWord(typed) {
            for correction in (spelling?.corrections(for: typed) ?? []).prefix(Self.maxCorrections) {
                add(correction)
            }
        }
        for item in languageModel?.nextWords(after: context, prefix: key, limit: count) ?? [] where isAcceptable(item) {
            add(item.display)
        }
        for item in lexicon?.completions(prefix: key, limit: count) ?? [] {
            add(item.display)
        }
        if result.count < count {
            for completion in spelling?.completions(for: typed) ?? [] {
                add(completion)
            }
        }
        return result
    }

    /// 下一个词：语言模型在上下文里有证据的续词（不含句末），按得分排序。
    public func predictions(after context: [String], limit: Int, capitalizeFirst: Bool) -> [String] {
        guard limit > 0, let languageModel else { return [] }
        var result: [String] = []
        for item in languageModel.nextWords(after: context, prefix: "", limit: limit * 2)
        where item.matchedOrder >= 1 && isAcceptable(item) {
            let display = capitalizeFirst ? TextRules.capitalizeFirst(item.display) : item.display
            if !result.contains(display) { result.append(display) }
            if result.count == limit { break }
        }
        return result
    }

    /// 短语：从 first 出发，每步接语言模型里得分最高的续词，最多 5 个词。
    /// 遇到句末、重复词、出现次数不足或只有一元证据时停止；接不上任何词返回 nil。
    public func phrase(startingWith first: String, after context: [String]) -> [String]? {
        guard let languageModel, !first.isEmpty else { return nil }
        var words = [first]
        var keys = [Self.key(first)]
        var history = context + keys
        while words.count < Self.maxPhraseWords {
            guard let next = languageModel.nextWords(after: history, prefix: "", limit: 1).first,
                  next.word != TextRules.sentenceEnd,
                  next.word != TextRules.sentenceStart,
                  next.matchedOrder >= 1,
                  next.count >= Self.minimumPhraseCount,
                  !keys.contains(next.word) else { break }
            words.append(next.display)
            keys.append(next.word)
            history.append(next.word)
        }
        return words.count >= 2 ? words : nil
    }

    /// 候选下方显示的释义（已截断）。
    public func gloss(for word: String) -> String? {
        guard let raw = glossary?.gloss(for: word), !raw.isEmpty else { return nil }
        return GlossFormatter.display(raw)
    }

    private func isAcceptable(_ item: ScoredWord) -> Bool {
        if item.word == TextRules.sentenceEnd || item.word == TextRules.sentenceStart { return false }
        // 上下文里的次数够了，总次数一定也够
        if item.count >= Self.minimumUnknownWordCount || isKnownWord(item.display) { return true }
        return (languageModel?.occurrences(of: item.word) ?? 0) >= Self.minimumUnknownWordCount
    }

    static func key(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
    }
}
