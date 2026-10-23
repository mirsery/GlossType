import AppKit
import GlossTypeCore
import InputMethodKit

/// 进程里共享的东西：数据、设置、翻译调度、候选窗。各个输入控制器（每个客户端一个）共用。
/// 只在主线程使用。
final class AppEnvironment {
    static let shared = AppEnvironment()

    var server: IMKServer?
    let preferencesStore = PreferencesStore()
    private(set) var preferences: Preferences
    let engine: SuggestionEngine
    let history: UserHistoryStore?
    let languageModel: NGramLanguageModel?
    let glossary: SQLiteGlossary?
    let coordinator: TranslationCoordinator
    let panel = CandidatePanelController()
    private(set) lazy var settings = SettingsWindowController(environment: self)

    private init() {
        let userDirectory = ResourceLocator.defaultUserDirectory()
        let resources = Bundle.main.resourceURL

        languageModel = ResourceLocator.loadLanguageModel(userDirectory: userDirectory, bundleResources: resources)
        glossary = ResourceLocator.locate(fileName: ResourceLocator.glossaryFileName, userDirectory: userDirectory, bundleResources: resources)
            .flatMap { SQLiteGlossary(path: $0) }
        if glossary == nil {
            NSLog("GlossType: 没找到词典 glossary.sqlite，候选只有拼写检查的结果，也没有释义")
        }
        do {
            history = try UserHistoryStore(path: userDirectory.appendingPathComponent(ResourceLocator.userHistoryFileName).path)
        } catch {
            NSLog("GlossType: 打开学习记录失败：\(error)")
            history = nil
        }

        engine = SuggestionEngine(
            languageModel: CompositeLanguageModel(base: languageModel, user: history),
            lexicon: glossary,
            spelling: SystemSpelling(),
            glossary: glossary
        )
        preferences = preferencesStore.load()
        coordinator = TranslationCoordinator(translator: Self.makeTranslator())
        applyPreferences()

        coordinator.onChange = { [weak self] line in
            self?.panel.updateTranslation(line)
        }
        NotificationCenter.default.addObserver(forName: PreferencesStore.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reloadPreferences()
        }
    }

    func reloadPreferences() {
        preferences = preferencesStore.load()
        applyPreferences()
    }

    private func applyPreferences() {
        coordinator.enabled = preferences.showTranslation
        coordinator.delayMilliseconds = preferences.translationDelayMs
    }

    private static func makeTranslator() -> Translator {
        #if canImport(Translation)
        return AppleTranslator()
        #else
        return UnavailableTranslator()
        #endif
    }

    /// 设置窗里显示的数据来源说明。
    var languageModelDescription: String {
        guard let languageModel else { return "未安装（联想只来自学习记录）" }
        let corpus = languageModel.metadata["corpus"] ?? "未知语料"
        let license = languageModel.metadata["license"] ?? "未知许可"
        return "\(corpus)（\(license)，\(languageModel.order) 阶）"
    }

    var glossaryDescription: String {
        guard let glossary else { return "未安装" }
        let source = glossary.metadata["source"] ?? "未知来源"
        let entries = glossary.metadata["entries"] ?? "?"
        return "\(source)，\(entries) 条"
    }
}

/// 没有 Translation 框架时（只在旧 SDK 上做类型检查时会用到）。
final class UnavailableTranslator: Translator {
    func checkAvailability(_ completion: @escaping (TranslationAvailability) -> Void) {
        completion(.unsupported)
    }

    func translate(_ text: String, completion: @escaping (Result<String, TranslationError>) -> Void) {
        completion(.failure(.notInstalled))
    }
}
