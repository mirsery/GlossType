import Foundation
import GlossTypeCore
import XCTest

final class PreferencesTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "GlossTypeTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_settings_01_defaults_when_never_saved() {
        let preferences = PreferencesStore(defaults: defaults).load()
        XCTAssertTrue(preferences.showGloss)
        XCTAssertTrue(preferences.showTranslation)
        XCTAssertTrue(preferences.phrasePrediction)
        XCTAssertTrue(preferences.learningEnabled)
        XCTAssertEqual(preferences.candidateCount, 5)
        XCTAssertEqual(preferences.translationDelayMs, 300)
    }

    func test_settings_02_out_of_range_values_clamped() {
        defaults.set(20, forKey: "candidateCount")
        defaults.set(10, forKey: "translationDelayMs")
        let loaded = PreferencesStore(defaults: defaults).load()
        XCTAssertEqual(loaded.candidateCount, 9)
        XCTAssertEqual(loaded.translationDelayMs, 100)

        var preferences = Preferences()
        preferences.candidateCount = 1
        preferences.translationDelayMs = 99999
        XCTAssertEqual(preferences.candidateCount, 3)
        XCTAssertEqual(preferences.translationDelayMs, 2000)
    }

    func test_settings_03_saved_values_persist() {
        var preferences = Preferences()
        preferences.candidateCount = 7
        preferences.showGloss = false
        PreferencesStore(defaults: defaults).save(preferences)

        let reopened = PreferencesStore(defaults: UserDefaults(suiteName: suiteName)!).load()
        XCTAssertEqual(reopened.candidateCount, 7)
        XCTAssertFalse(reopened.showGloss)
    }
}
