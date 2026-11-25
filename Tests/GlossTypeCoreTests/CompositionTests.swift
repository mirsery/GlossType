import GlossTypeCore
import XCTest

final class CompositionTests: XCTestCase {
    private func session(candidateCount: Int = 5) -> InputSession {
        var preferences = Preferences()
        preferences.candidateCount = candidateCount
        return makeSession(lexicon: FakeLexicon(["hello", "help", "held", "hell"]), preferences: preferences)
    }

    // MARK: 字母组词

    func test_composition_01_letters_form_marked_text() {
        let session = session()
        XCTAssertEqual(session.handle(.character("h")), KeyResult(handled: true, actions: [.setMarkedText("h")]))
        XCTAssertEqual(session.handle(.character("e")), KeyResult(handled: true, actions: [.setMarkedText("he")]))
        XCTAssertEqual(session.composition, "he")
    }

    func test_composition_02_shifted_letter_composes_uppercase() {
        let session = session()
        let key = KeyMapper.key(keyCode: 4, characters: "H", modifiers: [.shift])
        XCTAssertEqual(session.handle(key), KeyResult(handled: true, actions: [.setMarkedText("H")]))
    }

    func test_composition_03_apostrophe_inside_word_continues() {
        let session = session()
        session.type("don")
        XCTAssertEqual(session.handle(.character("'")), KeyResult(handled: true, actions: [.setMarkedText("don'")]))
    }

    func test_composition_04_leading_apostrophe_passes_through() {
        let session = session()
        XCTAssertFalse(session.handle(.character("'")).handled)
        XCTAssertEqual(session.mode, .idle)
    }

    func test_composition_05_backspace_deletes_last_character() {
        let session = session()
        session.type("hel")
        XCTAssertEqual(session.handle(.backspace), KeyResult(handled: true, actions: [.setMarkedText("he")]))
    }

    func test_composition_06_backspace_to_empty_hides_panel() {
        let session = session()
        session.type("h")
        XCTAssertEqual(session.handle(.backspace), KeyResult(handled: true, actions: [.setMarkedText("")]))
        XCTAssertNil(session.panel)
        XCTAssertEqual(session.mode, .idle)
    }

    // MARK: 提交

    func test_composition_07_space_commits_literal() {
        let spelling = FakeSpelling()
        spelling.correctionTable["helo"] = ["hello"]
        var preferences = Preferences()
        preferences.spaceAcceptsSuggestion = false
        let session = makeSession(lexicon: FakeLexicon(["hello", "help"]), spelling: spelling, preferences: preferences)
        session.type("helo")
        XCTAssertTrue(session.candidates.contains("hello"))
        XCTAssertEqual(session.handle(.space), KeyResult(handled: true, actions: [.insertText("helo ")]))
    }

    func test_composition_08_space_commits_moved_highlight() {
        let session = session()
        session.type("hel")
        XCTAssertEqual(session.handle(.right), KeyResult(handled: true))
        XCTAssertEqual(session.candidates[1], "hello")
        XCTAssertEqual(session.handle(.space), KeyResult(handled: true, actions: [.insertText("hello ")]))
    }

    func test_composition_09_digit_selects_candidate() {
        let session = session()
        session.type("hel")
        XCTAssertEqual(session.candidates[1], "hello")
        XCTAssertEqual(session.handle(.character("2")), KeyResult(handled: true, actions: [.insertText("hello ")]))
    }

    func test_composition_10_digit_beyond_candidates_commits_literal_and_digit() {
        let session = session()
        session.type("xq")
        XCTAssertEqual(session.candidates, ["xq"])
        XCTAssertEqual(session.handle(.character("7")), KeyResult(handled: true, actions: [.insertText("xq7")]))
    }

    func test_composition_11_tab_commits_first_suggestion() {
        let session = session()
        session.type("hel")
        XCTAssertEqual(session.handle(.tab), KeyResult(handled: true, actions: [.insertText("hello ")]))
    }

    func test_composition_12_tab_without_suggestion_commits_literal() {
        let session = session()
        session.type("xq")
        XCTAssertEqual(session.handle(.tab), KeyResult(handled: true, actions: [.insertText("xq ")]))
    }

    func test_composition_13_left_arrow_wraps_highlight() {
        let session = session(candidateCount: 3)
        session.type("hel")
        XCTAssertEqual(session.candidates.count, 3)
        XCTAssertEqual(session.highlightedIndex, 0)
        XCTAssertTrue(session.handle(.left).handled)
        XCTAssertEqual(session.highlightedIndex, 2)
        XCTAssertEqual(session.panel?.highlightedIndex, 2)
    }

    func test_composition_14_enter_confirms_without_space() {
        let session = session()
        session.type("hel")
        XCTAssertEqual(session.handle(.enter), KeyResult(handled: true, actions: [.insertText("hel")]))
    }

    func test_composition_15_escape_commits_literal_and_hides() {
        let session = session()
        session.type("hel")
        XCTAssertEqual(session.handle(.escape), KeyResult(handled: true, actions: [.insertText("hel")]))
        XCTAssertNil(session.panel)
    }

    func test_composition_16_punctuation_commits_literal_with_punctuation() {
        let session = session()
        session.type("hello")
        XCTAssertEqual(session.handle(.character(",")), KeyResult(handled: true, actions: [.insertText("hello,")]))
    }

    func test_composition_17_shortcut_commits_literal_then_passes_through() {
        let session = session()
        session.type("hel")
        let key = KeyMapper.key(keyCode: 0, characters: "a", modifiers: [.command])
        XCTAssertEqual(session.handle(key), KeyResult(handled: false, actions: [.insertText("hel")]))
    }

    func test_composition_18_vertical_arrow_commits_literal_then_passes_through() {
        let session = session()
        session.type("hel")
        XCTAssertEqual(session.handle(.down), KeyResult(handled: false, actions: [.insertText("hel")]))
    }

    func test_composition_19_focus_loss_commits_literal() {
        let session = session()
        session.type("hel")
        XCTAssertEqual(session.commitComposition(), [.insertText("hel")])
        XCTAssertEqual(session.mode, .idle)
    }

    // MARK: 空闲

    func test_composition_20_idle_non_letter_passes_through() {
        let session = session()
        XCTAssertEqual(session.handle(.character("5")), .passThrough)
        XCTAssertNil(session.panel)
    }

    // MARK: 空格接受建议

    /// 开启空格接受建议；拼写检查把 helo 纠正为 hello。
    private func spaceAcceptSession() -> InputSession {
        let spelling = FakeSpelling()
        spelling.correctionTable["helo"] = ["hello"]
        return makeSession(lexicon: FakeLexicon(["hello", "help", "helpful", "tomorrow"]), spelling: spelling)
    }

    func test_composition_22_misspelling_highlights_correction() {
        let session = spaceAcceptSession()
        session.type("helo")
        XCTAssertEqual(session.candidates[1], "hello")
        XCTAssertEqual(session.highlightedIndex, 1)
        XCTAssertEqual(session.panel?.highlightedIndex, 1)
    }

    func test_composition_23_space_commits_correction() {
        let session = spaceAcceptSession()
        session.type("helo")
        XCTAssertEqual(session.handle(.space), KeyResult(handled: true, actions: [.insertText("hello ")]))
    }

    func test_composition_24_known_word_space_commits_literal() {
        let session = spaceAcceptSession()
        session.type("help")
        XCTAssertTrue(session.candidates.contains("helpful"))
        XCTAssertEqual(session.highlightedIndex, 0)
        XCTAssertEqual(session.handle(.space), KeyResult(handled: true, actions: [.insertText("help ")]))
    }

    func test_composition_25_completion_only_space_commits_literal() {
        let session = spaceAcceptSession()
        session.type("tomo")
        XCTAssertEqual(session.candidates[1], "tomorrow")
        XCTAssertEqual(session.highlightedIndex, 0)
        XCTAssertEqual(session.handle(.space), KeyResult(handled: true, actions: [.insertText("tomo ")]))
    }

    func test_composition_26_escape_commits_literal_when_correction_highlighted() {
        let session = spaceAcceptSession()
        session.type("helo")
        XCTAssertEqual(session.highlightedIndex, 1)
        XCTAssertEqual(session.handle(.escape), KeyResult(handled: true, actions: [.insertText("helo")]))
    }

    func test_composition_27_moved_highlight_wins() {
        let session = spaceAcceptSession()
        session.type("helo")
        XCTAssertEqual(session.handle(.left), KeyResult(handled: true))
        XCTAssertEqual(session.highlightedIndex, 0)
        XCTAssertEqual(session.handle(.space), KeyResult(handled: true, actions: [.insertText("helo ")]))
    }

    func test_composition_27_typing_again_recomputes_highlight() {
        let spelling = FakeSpelling()
        spelling.correctionTable["hel"] = ["hell"]
        spelling.correctionTable["helo"] = ["hello"]
        let session = makeSession(lexicon: FakeLexicon(["hello", "hell"]), spelling: spelling)
        session.type("hel")
        session.handle(.left)
        XCTAssertEqual(session.highlightedIndex, 0)
        session.type("o")
        XCTAssertEqual(session.highlightedIndex, 1)
        XCTAssertEqual(session.candidates[1], "hello")
    }
}
