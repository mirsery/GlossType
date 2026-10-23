import GlossTypeCore
import XCTest

/// 夹具 tiny-ngram.sqlite 由 scripts/tests/fixtures/tiny-corpus.txt 生成：
/// how are 共 4 次（you 3、they 1），are 共 10 次（we 2）。
final class NGramLanguageModelTests: XCTestCase {
    private func load() throws -> NGramLanguageModel {
        try XCTUnwrap(NGramLanguageModel(path: Fixtures.ngramPath))
    }

    func test_lmdata_08_matched_context_uses_relative_frequency() throws {
        let model = try load()
        let results = model.nextWords(after: ["how", "are"], prefix: "", limit: 10)
        let you = try XCTUnwrap(results.first { $0.word == "you" })
        XCTAssertEqual(you.score, 0.75, accuracy: 1e-9)
        XCTAssertEqual(you.matchedOrder, 2)
        XCTAssertEqual(results.first?.word, "you")
    }

    func test_lmdata_09_backoff_multiplies_by_point_four() throws {
        let model = try load()
        let results = model.nextWords(after: ["how", "are"], prefix: "w", limit: 10)
        let we = try XCTUnwrap(results.first { $0.word == "we" })
        XCTAssertEqual(we.score, 0.4 * 0.2, accuracy: 1e-9)
        XCTAssertEqual(we.matchedOrder, 1)
    }
}
