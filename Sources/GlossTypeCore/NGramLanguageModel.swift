import Foundation

/// 读 `scripts/build_ngram.py` 生成的 ngram.sqlite（格式见 docs/data-formats.md）。
public final class NGramLanguageModel: LanguageModel {
    public static let format = "glosstype-ngram"
    public static let supportedVersion = "1"

    public let order: Int
    public let metadata: [String: String]
    private let database: SQLiteDatabase
    private let unigramTotal: Int
    private var contextCache: [String: (id: Int, total: Int)?] = [:]
    private lazy var topUnigrams: [ScoredWord] = loadUnigrams(prefix: "", limit: 64)

    /// 文件不存在、不是这个格式或版本不认识时返回 nil。
    public convenience init?(path: String) {
        guard FileManager.default.fileExists(atPath: path),
              let database = try? SQLiteDatabase(path: path, readOnly: true) else { return nil }
        self.init(database: database)
    }

    public init?(database: SQLiteDatabase) {
        guard let metadata = try? database.metadata(),
              metadata["format"] == Self.format,
              metadata["version"] == Self.supportedVersion,
              let order = Int(metadata["order"] ?? ""), order >= 2 else { return nil }
        self.database = database
        self.metadata = metadata
        self.order = order
        var total = 0
        try? database.query("SELECT total FROM context WHERE words = ''") { row in total = row.int(0) }
        unigramTotal = max(total, 1)
    }

    public func nextWords(after context: [String], prefix: String, limit: Int) -> [ScoredWord] {
        let key = prefix.lowercased()
        return Backoff.search(context: context, order: order, limit: limit) { words in
            if words.isEmpty {
                return key.isEmpty ? topUnigrams : loadUnigrams(prefix: key, limit: limit * 2)
            }
            guard let entry = contextEntry(words) else { return [] }
            return continuations(contextID: entry.id, total: entry.total, prefix: key, limit: limit * 2)
        }
    }

    private func contextEntry(_ words: String) -> (id: Int, total: Int)? {
        if let cached = contextCache[words] { return cached }
        var entry: (id: Int, total: Int)?
        do {
            try database.query("SELECT id, total FROM context WHERE words = ?", [.text(words)]) { row in
                entry = (row.int(0), max(row.int(1), 1))
            }
        } catch {
            NSLog("GlossType: 查询语言模型上下文失败：\(error)")
        }
        if contextCache.count > 4096 { contextCache.removeAll() }
        contextCache[words] = entry
        return entry
    }

    private func continuations(contextID: Int, total: Int, prefix: String, limit: Int) -> [ScoredWord] {
        let sql = """
            SELECT v.word, v.display, n.count FROM ngram n JOIN vocab v ON v.id = n.word_id
            WHERE n.context_id = ? AND v.word >= ? AND v.word < ?
            ORDER BY n.count DESC, v.word LIMIT ?
            """
        return scoredRows(sql, [.integer(Int64(contextID)), .text(prefix), .text(TextRules.prefixUpperBound(prefix)), .integer(Int64(limit))], total: total)
    }

    private func loadUnigrams(prefix: String, limit: Int) -> [ScoredWord] {
        let sql = "SELECT word, display, count FROM vocab WHERE word >= ? AND word < ? ORDER BY count DESC, word LIMIT ?"
        return scoredRows(sql, [.text(prefix), .text(TextRules.prefixUpperBound(prefix)), .integer(Int64(limit))], total: unigramTotal)
    }

    /// 查询结果的三列依次是 word、display、count。
    private func scoredRows(_ sql: String, _ arguments: [SQLiteValue], total: Int) -> [ScoredWord] {
        var items: [ScoredWord] = []
        do {
            try database.query(sql, arguments) { row in
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
            NSLog("GlossType: 查询语言模型失败：\(error)")
        }
        return items
    }
}
