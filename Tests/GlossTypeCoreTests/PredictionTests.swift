import GlossTypeCore
import XCTest

final class PredictionTests: XCTestCase {
    private func model(_ sentences: [(String, Int)]) -> FakeLanguageModel {
        let model = FakeLanguageModel()
        for (sentence, times) in sentences {
            model.addSentence(sentence, times: times)
        }
        return model
    }

    /// 当前句是 seed，敲空格进入联想。
    private func predicting(_ model: LanguageModel?, seed: String, preferences: Preferences = Preferences()) -> InputSession {
        let session = makeSession(languageModel: model, preferences: preferences, seed: seed)
        session.handle(.space)
        return session
    }

    // MARK: 下一个词

    func test_prediction_01_next_word_after_commit() {
        let session = makeSession(languageModel: model([("how are you", 3), ("how are they", 1)]))
        session.type("how are ")
        XCTAssertEqual(session.mode, .predicting)
        XCTAssertEqual(session.candidates.first, "you")
    }

    func test_prediction_02_longer_context_wins() {
        let session = predicting(model([("are you ok", 2), ("you know", 6), ("do you know", 4)]), seed: "how are you")
        guard let ok = session.candidates.firstIndex(of: "ok"),
              let know = session.candidates.firstIndex(of: "know") else {
            return XCTFail("联想里缺 ok 或 know：\(session.candidates)")
        }
        XCTAssertLessThan(ok, know)
    }

    func test_prediction_03_sentence_start_capitalized() {
        let session = predicting(model([("the cat sat", 5), ("i see", 2)]), seed: "Hi.")
        XCTAssertEqual(session.candidates.first, "The")
    }

    func test_prediction_04_manual_space_predicts() {
        let session = makeSession(languageModel: model([("how are you", 3)]), seed: "how are")
        XCTAssertEqual(session.handle(.space), .passThrough)
        XCTAssertEqual(session.mode, .predicting)
        XCTAssertEqual(session.candidates.first, "you")
    }

    func test_prediction_05_tab_accepts_prediction() {
        let session = predicting(model([("how are you", 3)]), seed: "how are")
        XCTAssertEqual(session.handle(.tab), KeyResult(handled: true, actions: [.insertText("you ")]))
    }

    func test_prediction_06_prediction_chains_after_accept() {
        let session = predicting(model([("how are you ok", 3)]), seed: "how are")
        session.handle(.tab)
        XCTAssertEqual(session.mode, .predicting)
        XCTAssertEqual(session.candidates.first, "ok")
    }

    // MARK: 短语

    func test_prediction_07_backtab_accepts_phrase() {
        let session = predicting(model([("how are you doing", 3)]), seed: "how are")
        XCTAssertEqual(session.panel?.phrase, "you doing")
        XCTAssertEqual(session.handle(.backTab), KeyResult(handled: true, actions: [.insertText("you doing ")]))
    }

    func test_prediction_08_phrase_at_most_five_words() {
        let session = predicting(model([("one two three four five six seven eight", 3)]), seed: "one")
        XCTAssertEqual(session.phrase, ["two", "three", "four", "five", "six"])
    }

    func test_prediction_09_phrase_stops_at_sentence_end() {
        let session = predicting(model([("i said thanks", 5), ("thanks a lot", 1)]), seed: "I")
        XCTAssertEqual(session.phrase, ["said", "thanks"])
    }

    func test_prediction_10_phrase_stops_at_rare_continuation() {
        let model = FakeLanguageModel()
        model.add(context: "<s> i", word: "want", count: 3)
        model.add(context: "i want", word: "coffee", count: 3)
        model.add(context: "want coffee", word: "now", count: 1)
        for word in ["i", "want", "coffee", "now"] {
            model.add(context: "", word: word, count: 3)
        }
        let session = predicting(model, seed: "I")
        XCTAssertEqual(session.phrase, ["want", "coffee"])
    }

    func test_prediction_11_phrase_can_be_disabled() {
        var preferences = Preferences()
        preferences.phrasePrediction = false
        let session = predicting(model([("how are you doing", 3)]), seed: "how are", preferences: preferences)
        XCTAssertEqual(session.candidates.first, "you")
        XCTAssertNil(session.panel?.phrase)
    }

    func test_prediction_12_phrase_while_composing() {
        let session = makeSession(languageModel: model([("thank you", 3)]), lexicon: FakeLexicon(["thank", "that"]))
        session.type("tha")
        XCTAssertEqual(session.candidates[1], "thank")
        XCTAssertEqual(session.panel?.phrase, "thank you")
    }

    // MARK: 联想状态下的按键

    func test_prediction_13_digit_passes_through_while_predicting() {
        let session = predicting(model([("how are you", 3)]), seed: "how are")
        XCTAssertEqual(session.handle(.character("2")), .passThrough)
    }

    func test_prediction_14_letter_starts_contextual_composition() {
        let session = predicting(model([("thank you", 3)]), seed: "thank")
        session.engine.lexicon = FakeLexicon(["yes", "your", "you"])
        XCTAssertEqual(session.handle(.character("y")), KeyResult(handled: true, actions: [.setMarkedText("y")]))
        XCTAssertEqual(session.candidates[1], "you")
    }

    func test_prediction_15_escape_hides_predictions() {
        let session = predicting(model([("how are you", 3)]), seed: "how are")
        XCTAssertEqual(session.handle(.escape), KeyResult(handled: true))
        XCTAssertNil(session.panel)
    }

    func test_prediction_16_control_key_hides_and_passes_through() {
        let session = predicting(model([("how are you", 3)]), seed: "how are")
        XCTAssertEqual(session.handle(.enter), .passThrough)
        XCTAssertNil(session.panel)
    }

    // MARK: 语言模型缺席

    func test_prediction_17_no_model_no_predictions() {
        let session = makeSession(languageModel: nil, lexicon: FakeLexicon(["hello"]))
        session.type("hello ")
        XCTAssertTrue(session.candidates.isEmpty)
        XCTAssertEqual(session.panel?.items ?? [], [])
    }
}
