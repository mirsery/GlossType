import Foundation

/// 用户设置。数值项超出范围时夹到范围内。
public struct Preferences: Equatable {
    public static let candidateCountRange = 3...9
    public static let translationDelayRange = 100...2000

    public var showGloss = true
    public var showTranslation = true
    public var phrasePrediction = true
    public var learningEnabled = true
    /// 候选数量（组词时含原样）。
    public var candidateCount = 5 {
        didSet { candidateCount = Self.clamp(candidateCount, to: Self.candidateCountRange) }
    }
    /// 源文本停止变化多久后请求翻译。
    public var translationDelayMs = 300 {
        didSet { translationDelayMs = Self.clamp(translationDelayMs, to: Self.translationDelayRange) }
    }

    public init() {}

    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

/// 设置的持久化（UserDefaults）。
public final class PreferencesStore {
    public static let didChangeNotification = Notification.Name("GlossTypePreferencesDidChange")

    enum Key {
        static let showGloss = "showGloss"
        static let showTranslation = "showTranslation"
        static let phrasePrediction = "phrasePrediction"
        static let learningEnabled = "learningEnabled"
        static let candidateCount = "candidateCount"
        static let translationDelayMs = "translationDelayMs"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Preferences {
        var preferences = Preferences()
        preferences.showGloss = bool(Key.showGloss) ?? preferences.showGloss
        preferences.showTranslation = bool(Key.showTranslation) ?? preferences.showTranslation
        preferences.phrasePrediction = bool(Key.phrasePrediction) ?? preferences.phrasePrediction
        preferences.learningEnabled = bool(Key.learningEnabled) ?? preferences.learningEnabled
        preferences.candidateCount = int(Key.candidateCount) ?? preferences.candidateCount
        preferences.translationDelayMs = int(Key.translationDelayMs) ?? preferences.translationDelayMs
        return preferences
    }

    public func save(_ preferences: Preferences) {
        defaults.set(preferences.showGloss, forKey: Key.showGloss)
        defaults.set(preferences.showTranslation, forKey: Key.showTranslation)
        defaults.set(preferences.phrasePrediction, forKey: Key.phrasePrediction)
        defaults.set(preferences.learningEnabled, forKey: Key.learningEnabled)
        defaults.set(preferences.candidateCount, forKey: Key.candidateCount)
        defaults.set(preferences.translationDelayMs, forKey: Key.translationDelayMs)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func bool(_ key: String) -> Bool? {
        (defaults.object(forKey: key) as? NSNumber)?.boolValue
    }

    private func int(_ key: String) -> Int? {
        (defaults.object(forKey: key) as? NSNumber)?.intValue
    }
}
