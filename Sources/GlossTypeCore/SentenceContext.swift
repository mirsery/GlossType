import Foundation

/// 输入法看得到的「当前这句」：提交的词和交给应用的可打印字符。
/// 光标位置变得不可知时（方向键、回车、快捷键、切换应用）由调用方重置。
public struct SentenceContext: Equatable {
    public static let maxLength = 1000

    public private(set) var text: String
    /// text 的开头是不是文档开头或句子边界。重置后从中途开始记，就不知道当前句从哪开始。
    public private(set) var startKnown: Bool

    public init(seed: String = "", startKnown: Bool = false) {
        text = ""
        self.startKnown = startKnown
        reset(seed: seed, startKnown: startKnown)
    }

    public mutating func append(_ string: String) {
        text += string
        truncateIfNeeded()
    }

    public mutating func deleteBackward() {
        if !text.isEmpty { text.removeLast() }
    }

    public mutating func reset(seed: String = "", startKnown: Bool = false) {
        text = seed
        self.startKnown = startKnown
        truncateIfNeeded()
    }

    private mutating func truncateIfNeeded() {
        guard text.count > Self.maxLength else { return }
        text = String(text.suffix(Self.maxLength))
        startKnown = false
    }

    /// 最后一个句末符号之后的文本，去掉开头空白。
    public var currentSentence: String {
        let tail: Substring
        if let index = text.lastIndex(where: TextRules.isSentenceTerminator) {
            tail = text[text.index(after: index)...]
        } else {
            tail = Substring(text)
        }
        return String(tail.drop(while: { $0.isWhitespace }))
    }

    /// 当前句的开头是否确定（前面有句末符号，或 text 从文档开头记起）。
    public var sentenceStartKnown: Bool {
        startKnown || text.contains(where: TextRules.isSentenceTerminator)
    }

    /// 当前句还没有词，且确定是在句首。
    public var isAtSentenceStart: Bool {
        sentenceStartKnown && TextRules.words(in: currentSentence).isEmpty
    }

    /// 当前句为空、前面刚结束一句时，返回那一句（带句末符号）。
    public var lastCompletedSentence: String? {
        guard currentSentence.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var body = Substring(text)
        while let last = body.last, last.isWhitespace, !TextRules.isSentenceTerminator(last) { body.removeLast() }
        guard let last = body.last, TextRules.isSentenceTerminator(last) else { return nil }
        // 去掉末尾连续的句末符号，再找上一句的边界
        var end = body.endIndex
        while end > body.startIndex, TextRules.isSentenceTerminator(body[body.index(before: end)]) {
            end = body.index(before: end)
        }
        let head = body[..<end]
        let start = head.lastIndex(where: TextRules.isSentenceTerminator).map { head.index(after: $0) } ?? head.startIndex
        let sentence = body[start...].trimmingCharacters(in: .whitespacesAndNewlines)
        return sentence.isEmpty ? nil : sentence
    }

    /// 当前句最后几个词（小写）。词数不足 maxCount 且确定在句首时，前面补 `<s>`。
    public func contextWords(maxCount: Int) -> [String] {
        guard maxCount > 0 else { return [] }
        var words = TextRules.words(in: currentSentence)
        if words.count < maxCount, sentenceStartKnown {
            words.insert(TextRules.sentenceStart, at: 0)
        }
        return Array(words.suffix(maxCount))
    }

    /// 最后一个非空白字符。
    public var lastNonWhitespaceCharacter: Character? {
        text.last(where: { !$0.isWhitespace })
    }
}
