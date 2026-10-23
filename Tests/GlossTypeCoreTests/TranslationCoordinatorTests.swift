import GlossTypeCore
import XCTest

final class TranslationCoordinatorTests: XCTestCase {
    private var translator: FakeTranslator!
    private var scheduler: ManualScheduler!
    private var coordinator: TranslationCoordinator!

    override func setUp() {
        translator = FakeTranslator()
        scheduler = ManualScheduler()
        coordinator = TranslationCoordinator(translator: translator, scheduler: scheduler)
        coordinator.delayMilliseconds = 300
    }

    /// 请求 source 并让它返回 translation。
    private func translate(_ source: String, as translation: String) {
        coordinator.update(source: source)
        scheduler.advance(by: 300)
        translator.respond(to: source, with: .success(translation))
    }

    // MARK: 调度

    func test_translation_07_debounce_requests_latest_only() {
        coordinator.update(source: "I")
        scheduler.advance(by: 100)
        coordinator.update(source: "I like")
        scheduler.advance(by: 100)
        coordinator.update(source: "I like cats")
        scheduler.advance(by: 299)
        XCTAssertEqual(translator.requests, [])
        scheduler.advance(by: 1)
        XCTAssertEqual(translator.requests, ["I like cats"])
    }

    func test_translation_08_stale_result_dropped() {
        coordinator.update(source: "I like")
        scheduler.advance(by: 300)
        coordinator.update(source: "I like cats")
        translator.respond(to: "I like", with: .success("我喜欢"))
        XCTAssertEqual(coordinator.line, TranslationLine(text: "", status: .pending))
    }

    func test_translation_09_cached_result_reused() {
        translate("I like cats", as: "我喜欢猫")
        coordinator.update(source: "I like")
        coordinator.update(source: "I like cats")
        XCTAssertEqual(coordinator.line, TranslationLine(text: "我喜欢猫", status: .translated))
        scheduler.advance(by: 1000)
        XCTAssertEqual(translator.requests, ["I like cats"])
    }

    func test_translation_10_unchanged_source_not_requested_again() {
        coordinator.update(source: "I like")
        scheduler.advance(by: 300)
        coordinator.update(source: "I like")
        scheduler.advance(by: 300)
        XCTAssertEqual(translator.requests, ["I like"])
    }

    // MARK: 显示

    func test_translation_11_previous_translation_shown_while_pending() {
        translate("I like", as: "我喜欢")
        coordinator.update(source: "I like cats")
        XCTAssertEqual(coordinator.line, TranslationLine(text: "我喜欢", status: .pending))
    }

    func test_translation_12_failure_shows_message() {
        coordinator.update(source: "I like")
        scheduler.advance(by: 300)
        translator.respond(to: "I like", with: .failure(.failed("boom")))
        XCTAssertEqual(coordinator.line, TranslationLine(text: "翻译失败", status: .failed))
    }

    func test_translation_13_missing_language_pack_shows_hint() {
        translator.availability = .notInstalled
        coordinator.update(source: "I like")
        scheduler.advance(by: 300)
        XCTAssertEqual(coordinator.line, TranslationLine(text: "未下载英→中语言包，可在设置中下载", status: .notInstalled))
        XCTAssertEqual(translator.requests, [])
    }

    func test_translation_14_disabled_translation() {
        coordinator.enabled = false
        coordinator.update(source: "I like")
        scheduler.advance(by: 1000)
        XCTAssertEqual(translator.requests, [])
        XCTAssertNil(coordinator.line)
    }

    func test_translation_15_empty_source_hides_line() {
        translate("I like", as: "我喜欢")
        XCTAssertNotNil(coordinator.line)
        coordinator.update(source: "  ")
        XCTAssertNil(coordinator.line)
    }
}
