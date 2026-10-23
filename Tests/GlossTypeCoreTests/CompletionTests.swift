import GlossTypeCore
import XCTest

final class CompletionTests: XCTestCase {
    // MARK: 来源与排序

    func test_completion_01_literal_first_then_by_frequency() {
        let session = makeSession(lexicon: FakeLexicon(["hello", "help"]))
        session.type("hel")
        XCTAssertEqual(session.candidates, ["hel", "hello", "help"])
    }

    func test_completion_02_context_continuations_before_frequency() {
        let model = FakeLanguageModel()
        model.addSentence("thank you", times: 3)
        let session = makeSession(languageModel: model, lexicon: FakeLexicon(["your", "you"]))
        session.type("thank yo")
        guard let you = session.candidates.firstIndex(of: "you"),
              let your = session.candidates.firstIndex(of: "your") else {
            return XCTFail("候选里缺 you 或 your：\(session.candidates)")
        }
        XCTAssertLessThan(you, your)
    }

    func test_completion_03_corrections_first_for_unknown_literal() {
        let spelling = FakeSpelling()
        spelling.correctionTable["teh"] = ["the", "ten"]
        let session = makeSession(lexicon: FakeLexicon(["the", "tea"]), spelling: spelling)
        session.type("teh")
        XCTAssertEqual(session.candidates[1], "the")
    }

    func test_completion_04_no_corrections_for_known_literal() {
        let spelling = FakeSpelling()
        spelling.correctionTable["hello"] = ["hallo"]
        let session = makeSession(lexicon: FakeLexicon(["hello"]), spelling: spelling)
        session.type("hello")
        XCTAssertFalse(session.candidates.contains("hallo"))
    }

    func test_completion_05_spelling_completions_fill_in() {
        let spelling = FakeSpelling()
        spelling.completionTable["zy"] = ["zygote"]
        let session = makeSession(lexicon: FakeLexicon(["hello"]), spelling: spelling)
        session.type("zy")
        XCTAssertTrue(session.candidates.contains("zygote"))
    }

    // MARK: 去重、大小写与数量

    func test_completion_06_same_word_from_two_sources_once() {
        let model = FakeLanguageModel()
        model.addSentence("hello there", times: 3)
        let session = makeSession(languageModel: model, lexicon: FakeLexicon(["hello", "help"]))
        session.type("hel")
        XCTAssertEqual(session.candidates.filter { $0 == "hello" }.count, 1)
    }

    func test_completion_07_literal_not_repeated() {
        let session = makeSession(lexicon: FakeLexicon(["hello"]))
        session.type("hello")
        XCTAssertEqual(session.candidates.first, "hello")
        XCTAssertEqual(session.candidates.filter { $0 == "hello" }.count, 1)
    }

    func test_completion_08_capitalized_input_capitalizes_suggestions() {
        let session = makeSession(lexicon: FakeLexicon(["hello"]))
        session.type("Hel")
        XCTAssertEqual(session.candidates, ["Hel", "Hello"])
    }

    func test_completion_09_uppercase_input_uppercases_suggestions() {
        let session = makeSession(lexicon: FakeLexicon(["hello"]))
        session.type("HEL")
        XCTAssertEqual(session.candidates, ["HEL", "HELLO"])
    }

    func test_completion_10_proper_noun_keeps_its_casing() {
        let session = makeSession(lexicon: FakeLexicon(["London"]))
        session.type("lon")
        XCTAssertEqual(session.candidates, ["lon", "London"])
    }

    func test_completion_11_candidate_count_follows_preferences() {
        var preferences = Preferences()
        preferences.candidateCount = 3
        let session = makeSession(lexicon: FakeLexicon(["a", "about", "after", "again", "all", "also", "and", "any"]), preferences: preferences)
        session.type("a")
        XCTAssertEqual(session.candidates.count, 3)
        XCTAssertEqual(session.candidates.first, "a")
    }
}
