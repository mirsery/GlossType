import Foundation

/// 提交词时调用，记录用户的用词和搭配。
public protocol LearningRecorder: AnyObject {
    /// context 是这个词前面的词（小写，可能以 `<s>` 开头）。
    func record(word: String, context: [String])
}

/// 用户学习记录（user-history.sqlite）：以前面 0–2 个词为上下文记录每次提交的词，
/// 同时作为语言模型参与排序（各上下文里的相对频率，stupid backoff）。
public final class UserHistoryStore: LanguageModel, LearningRecorder {
    public static let format = "glosstype-user-history"
    public static let version = "1"
    public static let maxContextWords = 2

    public let order = maxContextWords + 1
    private let database: SQLiteDatabase
    private var totals: [String: Int] = [:]

    public convenience init(path: String) throws {
        let directory = (path as NSString).deletingLastPathComponent
        if !directory.isEmpty {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        try self.init(database: SQLiteDatabase(path: path, readOnly: false))
    }

    public static func inMemory() throws -> UserHistoryStore {
        try UserHistoryStore(database: SQLiteDatabase.inMemory())
    }

    public init(database: SQLiteDatabase) throws {
        self.database = database
        try database.execute("""
            CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS history(
                context TEXT NOT NULL,
                word TEXT NOT NULL,
                display TEXT NOT NULL,
                count INTEGER NOT NULL,
                PRIMARY KEY(context, word)
            ) WITHOUT ROWID;
            """)
        try database.run("INSERT OR IGNORE INTO meta(key, value) VALUES ('format', ?)", [.text(Self.format)])
        try database.run("INSERT OR IGNORE INTO meta(key, value) VALUES ('version', ?)", [.text(Self.version)])
    }

    // MARK: 记录

    public func record(word: String, context: [String]) {
        guard TextRules.isLearnableWord(word) else { return }
        let key = Self.key(word)
        let previous = Array(context.suffix(Self.maxContextWords))
        let display = Self.displayForm(of: word, atSentenceStart: previous.last == TextRules.sentenceStart)
        do {
            try database.execute("BEGIN")
            for length in 0...previous.count {
                let contextKey = previous.suffix(length).joined(separator: " ")
                try database.run("""
                    INSERT INTO history(context, word, display, count) VALUES (?, ?, ?, 1)
                    ON CONFLICT(context, word) DO UPDATE SET count = count + 1, display = excluded.display
                    """, [.text(contextKey), .text(key), .text(display)])
                totals[contextKey] = nil
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            NSLog("GlossType: 写入学习记录失败：\(error)")
        }
    }

    public func clear() throws {
        try database.execute("DELETE FROM history")
        totals.removeAll()
    }

    /// 某个上下文（空格分隔的小写词，空串表示无上下文）下这个词被记录的次数。
    public func count(word: String, context: String = "") -> Int {
        var result = 0
        try? database.query("SELECT count FROM history WHERE context = ? AND word = ?", [.text(context), .text(Self.key(word))]) { row in
            result = row.int(0)
        }
        return result
    }

    public var isEmpty: Bool {
        var empty = true
        try? database.query("SELECT 1 FROM history LIMIT 1") { _ in empty = false }
        return empty
    }

    // MARK: 语言模型

    public func nextWords(after context: [String], prefix: String, limit: Int) -> [ScoredWord] {
        let key = Self.key(prefix)
        return Backoff.search(context: context, order: order, limit: limit) { contextKey in
            let total = self.total(for: contextKey)
            guard total > 0 else { return [] }
            var items: [ScoredWord] = []
            do {
                try database.query("""
                    SELECT word, display, count FROM history
                    WHERE context = ? AND word >= ? AND word < ?
                    ORDER BY count DESC, word LIMIT ?
                    """, [.text(contextKey), .text(key), .text(TextRules.prefixUpperBound(key)), .integer(Int64(limit * 2))]) { row in
                    let count = row.int(2)
                    items.append(ScoredWord(
                        word: row.string(0) ?? "",
                        display: row.string(1) ?? "",
                        score: Double(count) / Double(total),
                        count: count,
                        matchedOrder: 0
                    ))
                }
            } catch {
                NSLog("GlossType: 查询学习记录失败：\(error)")
            }
            return items
        }
    }

    private func total(for contextKey: String) -> Int {
        if let cached = totals[contextKey] { return cached }
        var total = 0
        do {
            try database.query("SELECT COALESCE(SUM(count), 0) FROM history WHERE context = ?", [.text(contextKey)]) { row in
                total = row.int(0)
            }
        } catch {
            NSLog("GlossType: 查询学习记录失败：\(error)")
            return 0
        }
        totals[contextKey] = total
        return total
    }

    static func key(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
    }

    /// 记下来的显示形式：句首被动大写的词、全大写强调的词存小写；
    /// 句中主动大写的（专有名词）和 iPhone 这类本身带大写的保留；I 和 I'm 永远大写。
    static func displayForm(of word: String, atSentenceStart: Bool) -> String {
        let lower = key(word)
        if lower == "i" || lower.hasPrefix("i'") { return TextRules.capitalizeFirst(lower) }
        let normalized = word.replacingOccurrences(of: "\u{2019}", with: "'")
        if normalized == lower { return lower }
        let letters = normalized.filter { $0.isLetter }
        if letters.count >= 2, letters == letters.uppercased() { return lower }
        if atSentenceStart, normalized.dropFirst() == lower.dropFirst() { return lower }
        return normalized
    }
}
