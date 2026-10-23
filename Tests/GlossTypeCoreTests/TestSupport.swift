import Foundation
import GlossTypeCore
import XCTest

// MARK: - 语言模型替身

/// 内存里的 n-gram 计数，和 build_ngram.py 的计法一致（句首 `<s>`、句尾 `</s>`、不剪枝）。
final class FakeLanguageModel: LanguageModel {
    let order: Int
    private var counts: [String: [String: Int]] = [:]
    private var displays: [String: String] = [:]

    init(order: Int = 3) {
        self.order = order
    }

    /// 直接加一条计数：context 为空串表示一元。
    func add(context: String, word: String, count: Int) {
        counts[context, default: [:]][word, default: 0] += count
    }

    /// 把一句话的各阶 n-gram 加 times 次。
    func addSentence(_ sentence: String, times: Int = 1) {
        let sequence = [TextRules.sentenceStart] + TextRules.words(in: sentence) + [TextRules.sentenceEnd]
        for index in 1..<sequence.count {
            for length in 0..<order where index - length >= 0 {
                let context = sequence[(index - length)..<index].joined(separator: " ")
                add(context: context, word: sequence[index], count: times)
            }
        }
    }

    func setDisplay(_ display: String, for word: String) {
        displays[word] = display
    }

    func nextWords(after context: [String], prefix: String, limit: Int) -> [ScoredWord] {
        let key = prefix.lowercased()
        return Backoff.search(context: context, order: order, limit: limit) { contextKey in
            guard let table = counts[contextKey] else { return [] }
            let total = table.values.reduce(0, +)
            return table.filter { $0.key.hasPrefix(key) }.map { word, count in
                ScoredWord(
                    word: word,
                    display: displays[word] ?? (word == "i" ? "I" : word),
                    score: Double(count) / Double(total),
                    count: count,
                    matchedOrder: 0
                )
            }
        }
    }
}

// MARK: - 词表、拼写、释义替身

/// 按给定顺序当作词频排名；传入的字符串就是显示形式。
final class FakeLexicon: WordLexicon {
    private let entries: [LexiconWord]

    init(_ words: [String]) {
        entries = words.map { LexiconWord(word: $0.lowercased(), display: $0) }
    }

    func contains(_ word: String) -> Bool {
        entries.contains { $0.word == word.lowercased() }
    }

    func completions(prefix: String, limit: Int) -> [LexiconWord] {
        Array(entries.filter { $0.word.hasPrefix(prefix.lowercased()) }.prefix(limit))
    }
}

final class FakeSpelling: SpellingProvider {
    var known: Set<String> = []
    var correctionTable: [String: [String]] = [:]
    var completionTable: [String: [String]] = [:]

    func isCorrectlySpelled(_ word: String) -> Bool {
        known.contains(word.lowercased())
    }

    func corrections(for word: String) -> [String] {
        correctionTable[word] ?? []
    }

    func completions(for prefix: String) -> [String] {
        completionTable[prefix] ?? []
    }
}

final class FakeGlossary: Glossary {
    var entries: [String: String]

    init(_ entries: [String: String] = [:]) {
        self.entries = entries
    }

    func gloss(for word: String) -> String? {
        entries[word.lowercased()]
    }
}

// MARK: - 翻译与调度替身

final class FakeTranslator: Translator {
    var availability: TranslationAvailability = .installed
    private(set) var requests: [String] = []
    private var pending: [(text: String, completion: (Result<String, TranslationError>) -> Void)] = []

    func checkAvailability(_ completion: @escaping (TranslationAvailability) -> Void) {
        completion(availability)
    }

    func translate(_ text: String, completion: @escaping (Result<String, TranslationError>) -> Void) {
        requests.append(text)
        pending.append((text, completion))
    }

    /// 让 text 的那个请求返回结果。
    func respond(to text: String, with result: Result<String, TranslationError>) {
        guard let index = pending.firstIndex(where: { $0.text == text }) else {
            XCTFail("没有等待中的翻译请求：\(text)")
            return
        }
        let request = pending.remove(at: index)
        request.completion(result)
    }
}

/// 手动推进时间的调度器。
final class ManualScheduler: Scheduler {
    private final class Work: Cancellable {
        let due: Int
        let block: () -> Void
        var cancelled = false

        init(due: Int, block: @escaping () -> Void) {
            self.due = due
            self.block = block
        }

        func cancel() {
            cancelled = true
        }
    }

    private(set) var now = 0
    private var works: [Work] = []

    func schedule(afterMilliseconds delay: Int, _ work: @escaping () -> Void) -> Cancellable {
        let item = Work(due: now + delay, block: work)
        works.append(item)
        return item
    }

    func advance(by milliseconds: Int) {
        now += milliseconds
        while let index = works.indices.filter({ works[$0].due <= now }).min(by: { works[$0].due < works[$1].due }) {
            let work = works.remove(at: index)
            if !work.cancelled { work.block() }
        }
    }
}

// MARK: - 夹具与工具

enum Fixtures {
    static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
    static let glossaryPath = directory.appendingPathComponent("tiny-glossary.sqlite").path
    static let ngramPath = directory.appendingPathComponent("tiny-ngram.sqlite").path

    /// 每次调用新建一个空的临时目录。
    static func temporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GlossTypeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 按 glossary.sqlite 的格式建一个只有给定词条的词典，排名按传入顺序。
    static func makeGlossary(at path: String, entries: [(word: String, gloss: String)]) throws {
        let database = try SQLiteDatabase(path: path, readOnly: false)
        try database.execute("""
            CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE entry(word TEXT PRIMARY KEY, display TEXT NOT NULL, gloss TEXT NOT NULL, lemma TEXT, rank INTEGER NOT NULL) WITHOUT ROWID;
            INSERT INTO meta VALUES ('format', 'glosstype-glossary'), ('version', '1');
            """)
        for (index, entry) in entries.enumerated() {
            try database.run(
                "INSERT INTO entry(word, display, gloss, lemma, rank) VALUES (?, ?, ?, NULL, ?)",
                [.text(entry.word), .text(entry.word), .text(entry.gloss), .integer(Int64(index + 1))]
            )
        }
    }
}

func makeSession(
    languageModel: LanguageModel? = nil,
    lexicon: WordLexicon? = nil,
    spelling: SpellingProvider? = FakeSpelling(),
    glossary: Glossary? = nil,
    recorder: LearningRecorder? = nil,
    preferences: Preferences = Preferences(),
    seed: String = ""
) -> InputSession {
    let engine = SuggestionEngine(languageModel: languageModel, lexicon: lexicon, spelling: spelling, glossary: glossary)
    let session = InputSession(engine: engine, recorder: recorder, preferences: preferences)
    session.activate(seed: seed, startKnown: true)
    return session
}

extension InputSession {
    /// 逐字符输入；空格按空格键处理。返回最后一个按键的结果。
    @discardableResult
    func type(_ text: String) -> KeyResult {
        var last = KeyResult.passThrough
        for character in text {
            last = handle(character == " " ? .space : .character(character))
        }
        return last
    }
}
