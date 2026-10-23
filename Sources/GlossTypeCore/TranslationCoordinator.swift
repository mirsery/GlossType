import Foundation

public enum TranslationError: Error, Equatable {
    /// 系统没装英→简中语言包。
    case notInstalled
    case failed(String)
}

public enum TranslationAvailability: Equatable {
    case installed
    case notInstalled
    case unsupported
}

/// 系统翻译能力的抽象（App 里用苹果 Translation 框架实现）。回调都在主线程。
public protocol Translator: AnyObject {
    func checkAvailability(_ completion: @escaping (TranslationAvailability) -> Void)
    func translate(_ text: String, completion: @escaping (Result<String, TranslationError>) -> Void)
}

public protocol Cancellable: AnyObject {
    func cancel()
}

/// 延时执行（防抖用）。测试里换成手动推进时间的替身。
public protocol Scheduler: AnyObject {
    func schedule(afterMilliseconds delay: Int, _ work: @escaping () -> Void) -> Cancellable
}

public final class MainQueueScheduler: Scheduler {
    private final class Token: Cancellable {
        let item: DispatchWorkItem
        init(_ item: DispatchWorkItem) { self.item = item }
        func cancel() { item.cancel() }
    }

    public init() {}

    public func schedule(afterMilliseconds delay: Int, _ work: @escaping () -> Void) -> Cancellable {
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: item)
        return Token(item)
    }
}

/// 候选窗底部的译文行。
public struct TranslationLine: Equatable {
    public enum Status: Equatable {
        case translated
        /// 等待新结果，text 是上一次的译文（可能为空）。
        case pending
        case failed
        case notInstalled
    }

    public static let failedText = "翻译失败"
    public static let notInstalledText = "未下载英→中语言包，可在设置中下载"

    public var text: String
    public var status: Status

    public init(text: String, status: Status) {
        self.text = text
        self.status = status
    }
}

/// 整句翻译的调度：防抖、过期结果丢弃、缓存、状态文案。只在主线程使用。
public final class TranslationCoordinator {
    public static let cacheLimit = 200

    public var enabled = true {
        didSet { if !enabled { reset() } }
    }
    public var delayMilliseconds = 300
    /// 译文行变化时回调；nil 表示不显示译文行。
    public var onChange: ((TranslationLine?) -> Void)?
    public private(set) var line: TranslationLine? {
        didSet { if line != oldValue { onChange?(line) } }
    }

    private let translator: Translator
    private let scheduler: Scheduler
    private var currentSource = ""
    private var lastTranslation = ""
    private var generation = 0
    private var pendingWork: Cancellable?
    private var knownInstalled = false
    private var cache: [String: String] = [:]
    private var cacheOrder: [String] = []

    public init(translator: Translator, scheduler: Scheduler = MainQueueScheduler()) {
        self.translator = translator
        self.scheduler = scheduler
    }

    /// 源文本变化（或可能变化）时调用。没变就什么也不做。
    public func update(source: String) {
        guard enabled else {
            reset()
            return
        }
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != currentSource else { return }
        currentSource = text
        generation += 1
        pendingWork?.cancel()
        pendingWork = nil

        guard !text.isEmpty else {
            line = nil
            return
        }
        if let cached = cachedTranslation(text) {
            show(cached)
            return
        }
        line = TranslationLine(text: lastTranslation, status: .pending)
        let scheduled = generation
        pendingWork = scheduler.schedule(afterMilliseconds: delayMilliseconds) { [weak self] in
            self?.request(text, generation: scheduled)
        }
    }

    /// 收起候选窗时调用：取消等待中的请求，清掉译文行。
    public func reset() {
        generation += 1
        pendingWork?.cancel()
        pendingWork = nil
        currentSource = ""
        line = nil
    }

    private func request(_ text: String, generation scheduled: Int) {
        pendingWork = nil
        guard scheduled == generation else { return }
        if knownInstalled {
            send(text, generation: scheduled)
            return
        }
        translator.checkAvailability { [weak self] availability in
            guard let self, scheduled == self.generation else { return }
            if availability == .installed {
                self.knownInstalled = true
                self.send(text, generation: scheduled)
            } else {
                self.line = TranslationLine(text: TranslationLine.notInstalledText, status: .notInstalled)
            }
        }
    }

    private func send(_ text: String, generation scheduled: Int) {
        translator.translate(text) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let translation):
                self.store(translation, for: text)
                guard scheduled == self.generation else { return }
                self.show(translation)
            case .failure(.notInstalled):
                self.knownInstalled = false
                guard scheduled == self.generation else { return }
                self.line = TranslationLine(text: TranslationLine.notInstalledText, status: .notInstalled)
            case .failure(.failed(let message)):
                NSLog("GlossType: 翻译失败：\(message)")
                guard scheduled == self.generation else { return }
                self.line = TranslationLine(text: TranslationLine.failedText, status: .failed)
            }
        }
    }

    private func show(_ translation: String) {
        lastTranslation = translation
        line = TranslationLine(text: translation, status: .translated)
    }

    private func cachedTranslation(_ text: String) -> String? {
        guard let value = cache[text] else { return nil }
        if let index = cacheOrder.firstIndex(of: text) {
            cacheOrder.remove(at: index)
        }
        cacheOrder.append(text)
        return value
    }

    private func store(_ translation: String, for text: String) {
        if cache[text] == nil {
            cacheOrder.append(text)
        }
        cache[text] = translation
        while cacheOrder.count > Self.cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
    }
}
