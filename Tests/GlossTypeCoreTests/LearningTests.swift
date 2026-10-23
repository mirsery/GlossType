import Foundation
import GlossTypeCore
import XCTest

final class LearningTests: XCTestCase {
    private func learningSession(
        store: UserHistoryStore,
        base: LanguageModel? = nil,
        lexicon: WordLexicon? = nil,
        preferences: Preferences = Preferences(),
        seed: String = ""
    ) -> InputSession {
        makeSession(
            languageModel: CompositeLanguageModel(base: base, user: store),
            lexicon: lexicon,
            recorder: store,
            preferences: preferences,
            seed: seed
        )
    }

    // MARK: 记录

    func test_learning_01_records_word_with_two_previous_words() throws {
        let store = try UserHistoryStore.inMemory()
        let session = learningSession(store: store, seed: "I see ")
        session.type("them ")
        XCTAssertEqual(store.count(word: "them", context: ""), 1)
        XCTAssertEqual(store.count(word: "them", context: "see"), 1)
        XCTAssertEqual(store.count(word: "them", context: "i see"), 1)
    }

    func test_learning_02_only_letter_words_recorded() throws {
        let store = try UserHistoryStore.inMemory()
        store.record(word: "v2", context: ["i", "see"])
        store.record(word: "a.b", context: ["i", "see"])
        XCTAssertTrue(store.isEmpty)
    }

    func test_learning_02_digit_glued_to_word_not_recorded() throws {
        let store = try UserHistoryStore.inMemory()
        let session = learningSession(store: store)
        session.type("v2 ")
        XCTAssertTrue(store.isEmpty)
    }

    func test_learning_03_disabled_learning_records_nothing() throws {
        let store = try UserHistoryStore.inMemory()
        var preferences = Preferences()
        preferences.learningEnabled = false
        let session = learningSession(store: store, preferences: preferences, seed: "I see ")
        session.type("them ")
        XCTAssertTrue(store.isEmpty)
    }

    func test_learning_04_records_survive_restart() throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent(ResourceLocator.userHistoryFileName).path
        do {
            let store = try UserHistoryStore(path: path)
            store.record(word: "them", context: ["i", "see"])
        }
        let reopened = try UserHistoryStore(path: path)
        XCTAssertEqual(reopened.count(word: "them", context: "see"), 1)
    }

    func test_learning_05_clear_removes_everything() throws {
        let store = try UserHistoryStore.inMemory()
        store.record(word: "them", context: ["i", "see"])
        XCTAssertFalse(store.isEmpty)
        try store.clear()
        XCTAssertTrue(store.isEmpty)
    }

    // MARK: 影响排序

    func test_learning_06_twice_used_pair_ranks_first() throws {
        let base = FakeLanguageModel()
        base.add(context: "see", word: "you", count: 10)
        base.add(context: "see", word: "them", count: 5)
        for word in ["i", "see", "you", "them"] {
            base.add(context: "", word: word, count: 10)
        }
        let store = try UserHistoryStore.inMemory()
        let session = learningSession(store: store, base: base)

        session.activate(seed: "I see", startKnown: true)
        session.handle(.space)
        XCTAssertEqual(session.candidates.first, "you")

        for _ in 0..<2 {
            session.activate(seed: "I see ", startKnown: true)
            session.type("them ")
        }
        session.activate(seed: "I see", startKnown: true)
        session.handle(.space)
        XCTAssertEqual(session.candidates.first, "them")
    }

    func test_learning_07_new_word_learned_after_two_commits() throws {
        let store = try UserHistoryStore.inMemory()
        let session = learningSession(store: store, lexicon: FakeLexicon(["grok", "great"]))
        session.type("grokking grokking ")
        session.handle(.escape)
        session.type("grok")
        XCTAssertTrue(session.candidates.contains("grokking"), "\(session.candidates)")
    }

    func test_learning_08_single_typo_not_suggested() throws {
        let store = try UserHistoryStore.inMemory()
        let session = learningSession(store: store, lexicon: FakeLexicon(["hello", "help"]))
        session.type("helo ")
        session.handle(.escape)
        session.type("hel")
        XCTAssertEqual(session.candidates, ["hel", "hello", "help"])
    }
}
