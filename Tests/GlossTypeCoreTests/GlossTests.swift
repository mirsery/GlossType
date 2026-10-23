import Foundation
import GlossTypeCore
import XCTest

final class GlossTests: XCTestCase {
    private func glossary() throws -> SQLiteGlossary {
        try XCTUnwrap(SQLiteGlossary(path: Fixtures.glossaryPath))
    }

    func test_gloss_01_candidate_shows_gloss() throws {
        let glossary = try glossary()
        let session = makeSession(lexicon: glossary, glossary: glossary)
        session.type("hell")
        let hello = try XCTUnwrap(session.panel?.items.first { $0.text == "hello" })
        XCTAssertEqual(hello.gloss, "喂，嘿")
    }

    func test_gloss_02_lookup_ignores_case() throws {
        let engine = SuggestionEngine(glossary: try glossary())
        XCTAssertEqual(engine.gloss(for: "Hello"), "喂，嘿")
        XCTAssertEqual(engine.gloss(for: "HELLO"), "喂，嘿")
    }

    func test_gloss_03_inflections_fall_back_to_lemma() throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("glossary.sqlite").path
        try Fixtures.makeGlossary(at: path, entries: [
            ("study", "学习"), ("cat", "猫"), ("run", "跑"), ("stop", "停止"),
        ])
        let engine = SuggestionEngine(glossary: try XCTUnwrap(SQLiteGlossary(path: path)))
        XCTAssertEqual(engine.gloss(for: "studies"), "学习")
        XCTAssertEqual(engine.gloss(for: "studied"), "学习")
        XCTAssertEqual(engine.gloss(for: "cats"), "猫")
        XCTAssertEqual(engine.gloss(for: "running"), "跑")
        XCTAssertEqual(engine.gloss(for: "stopped"), "停止")
    }

    func test_gloss_04_unknown_word_has_no_gloss() throws {
        let glossary = try glossary()
        let session = makeSession(lexicon: glossary, glossary: glossary)
        session.type("xq")
        XCTAssertEqual(session.panel?.items, [PanelModel.Item(text: "xq", gloss: nil)])
    }

    func test_gloss_05_long_gloss_truncated() {
        let engine = SuggestionEngine(glossary: FakeGlossary(["word": "甲乙丙丁戊己庚辛壬癸子丑寅卯辰"]))
        XCTAssertEqual(engine.gloss(for: "word"), "甲乙丙丁戊己庚辛壬癸…")
    }

    func test_gloss_06_gloss_can_be_disabled() throws {
        let glossary = try glossary()
        var preferences = Preferences()
        preferences.showGloss = false
        let session = makeSession(lexicon: glossary, glossary: glossary, preferences: preferences)
        session.type("hel")
        let items = try XCTUnwrap(session.panel?.items)
        XCTAssertGreaterThan(items.count, 1)
        XCTAssertTrue(items.allSatisfy { $0.gloss == nil })
    }
}
