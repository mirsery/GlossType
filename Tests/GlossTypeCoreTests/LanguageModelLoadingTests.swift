import Foundation
import GlossTypeCore
import XCTest

final class LanguageModelLoadingTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = try Fixtures.temporaryDirectory()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    /// 把夹具模型复制到 directory，并改写它的 meta。
    private func installModel(in name: String, meta: [String: String]) throws -> URL {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent(ResourceLocator.languageModelFileName)
        try FileManager.default.copyItem(atPath: Fixtures.ngramPath, toPath: path.path)
        let database = try SQLiteDatabase(path: path.path, readOnly: false)
        for (key, value) in meta {
            try database.run("UPDATE meta SET value = ? WHERE key = ?", [.text(value), .text(key)])
        }
        return directory
    }

    func test_prediction_18_user_model_preferred() throws {
        let user = try installModel(in: "user", meta: ["corpus": "user corpus"])
        let bundle = try installModel(in: "bundle", meta: ["corpus": "bundle corpus"])
        let model = ResourceLocator.loadLanguageModel(userDirectory: user, bundleResources: bundle)
        XCTAssertEqual(model?.metadata["corpus"], "user corpus")
    }

    func test_prediction_18_bundle_model_when_user_has_none() throws {
        let bundle = try installModel(in: "bundle", meta: ["corpus": "bundle corpus"])
        let model = ResourceLocator.loadLanguageModel(userDirectory: root.appendingPathComponent("missing"), bundleResources: bundle)
        XCTAssertEqual(model?.metadata["corpus"], "bundle corpus")
    }

    func test_prediction_19_unknown_version_treated_as_absent() throws {
        let user = try installModel(in: "user", meta: ["version": "99"])
        XCTAssertNil(ResourceLocator.loadLanguageModel(userDirectory: user, bundleResources: nil))
    }
}
