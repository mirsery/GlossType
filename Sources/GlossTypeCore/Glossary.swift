import Foundation

/// 查中文释义。返回词典里的原始短释义，显示前由 GlossFormatter 截断。
public protocol Glossary: AnyObject {
    func gloss(for word: String) -> String?
}

/// 词表里的一个词。
public struct LexiconWord: Equatable {
    public var word: String
    public var display: String

    public init(word: String, display: String) {
        self.word = word
        self.display = display
    }
}

/// 带词频排名的词表：判断已知词、按前缀列出补全。
public protocol WordLexicon: AnyObject {
    func contains(_ word: String) -> Bool
    /// 以 prefix（小写）开头的词，按词频排名从高到低。
    func completions(prefix: String, limit: Int) -> [LexiconWord]
}

/// 读 `scripts/build_glossary.py` 生成的 glossary.sqlite，同时充当词表和释义词典。
public final class SQLiteGlossary: Glossary, WordLexicon {
    public static let format = "glosstype-glossary"
    public static let supportedVersion = "1"

    public let metadata: [String: String]
    private let database: SQLiteDatabase

    /// 文件不存在、不是这个格式或版本不认识时返回 nil。
    public convenience init?(path: String) {
        guard FileManager.default.fileExists(atPath: path),
              let database = try? SQLiteDatabase(path: path, readOnly: true) else { return nil }
        self.init(database: database)
    }

    public init?(database: SQLiteDatabase) {
        guard let metadata = try? database.metadata(),
              metadata["format"] == Self.format,
              metadata["version"] == Self.supportedVersion else { return nil }
        self.database = database
        self.metadata = metadata
    }

    public func contains(_ word: String) -> Bool {
        entry(Self.key(word)) != nil
    }

    public func completions(prefix: String, limit: Int) -> [LexiconWord] {
        guard limit > 0 else { return [] }
        let key = Self.key(prefix)
        var items: [LexiconWord] = []
        do {
            try database.query(
                "SELECT word, display FROM entry WHERE word >= ? AND word < ? ORDER BY rank, word LIMIT ?",
                [.text(key), .text(TextRules.prefixUpperBound(key)), .integer(Int64(limit))]
            ) { row in
                items.append(LexiconWord(word: row.string(0) ?? "", display: row.string(1) ?? ""))
            }
        } catch {
            NSLog("GlossType: 查询词表失败：\(error)")
        }
        return items
    }

    /// 原词（小写）→ 规则还原的原形 → 没有。
    public func gloss(for word: String) -> String? {
        let key = Self.key(word)
        guard !key.isEmpty else { return nil }
        if let found = entry(key) { return found }
        for lemma in Lemmatizer.candidates(for: key) {
            if let found = entry(lemma) { return found }
        }
        return nil
    }

    private func entry(_ key: String) -> String? {
        var gloss: String?
        do {
            try database.query("SELECT gloss FROM entry WHERE word = ?", [.text(key)]) { row in
                gloss = row.string(0)
            }
        } catch {
            NSLog("GlossType: 查询释义失败：\(error)")
        }
        return gloss
    }

    /// 词典的键：小写、弯撇号换成直撇号。
    static func key(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
    }
}

/// 把变形词还原成可能的原形，按可能性从高到低。只做规则还原，不保证每个都是真词。
public enum Lemmatizer {
    public static func candidates(for word: String) -> [String] {
        var result: [String] = []
        func add(_ candidate: String) {
            if candidate.count >= 2, candidate != word, !result.contains(candidate) {
                result.append(candidate)
            }
        }
        func stem(_ suffix: String) -> String? {
            guard word.hasSuffix(suffix), word.count > suffix.count + 1 else { return nil }
            return String(word.dropLast(suffix.count))
        }
        if let base = stem("ies") { add(base + "y") }
        if let base = stem("es") { add(base) }
        if let base = stem("s"), !word.hasSuffix("ss") { add(base) }
        if let base = stem("ied") { add(base + "y") }
        if let base = stem("ed") {
            add(base)
            add(base + "e")
            if let undoubled = undoubled(base) { add(undoubled) }
        }
        if let base = stem("ing") {
            add(base)
            add(base + "e")
            if let undoubled = undoubled(base) { add(undoubled) }
        }
        return result
    }

    /// stopp → stop、runn → run：末尾两个相同辅音去掉一个。
    private static func undoubled(_ stem: String) -> String? {
        let characters = Array(stem)
        guard characters.count >= 3,
              let last = characters.last,
              characters[characters.count - 2] == last,
              !"aeiou".contains(last) else { return nil }
        return String(characters.dropLast())
    }
}

/// 释义显示规则：超过 10 个字截断加「…」。
public enum GlossFormatter {
    public static let maxLength = 10

    public static func display(_ gloss: String) -> String {
        let trimmed = gloss.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(maxLength)) + "…"
    }
}
