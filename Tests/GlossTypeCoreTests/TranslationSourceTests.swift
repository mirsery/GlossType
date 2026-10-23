import GlossTypeCore
import XCTest

final class TranslationSourceTests: XCTestCase {
    private func session(seed: String) -> InputSession {
        let spelling = FakeSpelling()
        spelling.known = ["i", "like", "cat", "car", "cats"]
        return makeSession(lexicon: FakeLexicon(["cat", "car", "cats"]), spelling: spelling, seed: seed)
    }

    func test_translation_01_composing_uses_known_literal() {
        let session = session(seed: "I like ")
        session.type("cat")
        XCTAssertEqual(session.translationSource, "I like cat")
    }

    func test_translation_02_unknown_literal_uses_first_suggestion() {
        let session = session(seed: "I like ")
        session.type("ca")
        XCTAssertEqual(session.candidates[1], "cat")
        XCTAssertEqual(session.translationSource, "I like cat")
    }

    func test_translation_03_moved_highlight_wins() {
        let session = session(seed: "I like ")
        session.type("ca")
        session.handle(.right)
        session.handle(.right)
        XCTAssertEqual(session.candidates[session.highlightedIndex], "car")
        XCTAssertEqual(session.translationSource, "I like car")
    }

    func test_translation_04_predicting_uses_current_sentence() {
        let session = session(seed: "I like cats")
        session.handle(.space)
        XCTAssertEqual(session.mode, .predicting)
        XCTAssertEqual(session.translationSource, "I like cats")
    }

    func test_translation_05_after_terminator_uses_finished_sentence() {
        let session = session(seed: "I like ")
        session.type("cats.")
        XCTAssertEqual(session.translationSource, "I like cats.")
        session.handle(.space)
        XCTAssertEqual(session.translationSource, "I like cats.")
    }

    func test_translation_06_source_capped_at_300_characters() {
        let sentence = String(repeating: "abcd ", count: 100).trimmingCharacters(in: .whitespaces)
        let session = session(seed: sentence)
        XCTAssertEqual(sentence.count, 499)
        XCTAssertEqual(session.translationSource.count, 300)
        XCTAssertEqual(session.translationSource, String(sentence.suffix(300)))
    }
}
