#if canImport(Translation)
import AppKit
import GlossTypeCore
import SwiftUI
import Translation

// Translation 框架自己也有 TranslationError，本文件里 Core 的类型一律写全名。

/// 苹果本地翻译（macOS 15 Translation 框架）。macOS 15 只能通过 SwiftUI 的 `.translationTask` 拿到
/// TranslationSession，所以放一个 1×1、透明、不接收鼠标的宿主窗口承载这个任务。
final class AppleTranslator: GlossTypeCore.Translator {
    static let source = Locale.Language(identifier: "en")
    static let target = Locale.Language(identifier: "zh-Hans")
    /// 一个请求这么久还没结果就判失败并重建会话：宿主任务没起来、或系统在看不见的窗口上弹了下载确认时，
    /// 请求不会永远挂着。
    static let requestTimeout: TimeInterval = 8

    private let host = TranslationHost()
    private var window: NSWindow?

    func checkAvailability(_ completion: @escaping (GlossTypeCore.TranslationAvailability) -> Void) {
        Task { @MainActor in
            completion(await Self.availability())
        }
    }

    func translate(_ text: String, completion: @escaping (Result<String, GlossTypeCore.TranslationError>) -> Void) {
        installHostWindowIfNeeded()
        host.enqueue(text, completion: completion)
    }

    static func availability() async -> GlossTypeCore.TranslationAvailability {
        let status = await LanguageAvailability().status(from: source, to: target)
        switch status {
        case .installed: return .installed
        case .supported: return .notInstalled
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    private func installHostWindowIfNeeded() {
        guard window == nil else { return }
        // 放在主屏可见区域的角上：不在屏幕内的窗口，SwiftUI 不一定认为视图已出现
        let origin = NSScreen.main?.visibleFrame.origin ?? .zero
        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: NSSize(width: 1, height: 1)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.contentView = NSHostingView(rootView: TranslationHostView(host: host))
        window.orderFrontRegardless()
        self.window = window
    }
}

/// 请求队列。改变配置会让 `.translationTask` 用新会话调 `drain`，`drain` 把队列取空就结束。
///
/// 会话在配置再次变化后就不能用（会崩），所以：等任务启动期间不再动配置；配置变了（超时重建）之后，
/// 旧的 `drain` 发现代数不对就停手，不再碰旧会话。
final class TranslationHost: ObservableObject {
    typealias Completion = (Result<String, GlossTypeCore.TranslationError>) -> Void

    private struct Request {
        let id: Int
        let text: String
        let completion: Completion
    }

    @Published var configuration: TranslationSession.Configuration?
    private var queue: [Request] = []
    /// 还没回调过的请求；超时和正常结果谁先到算谁，另一个丢掉。
    private var pending = Set<Int>()
    private var nextID = 0
    /// 每次重建会话加一；`drain` 开始时记下，变了就停。
    private var generation = 0
    /// 已经改了配置、在等任务启动。
    private var sessionRequested = false
    private var draining = false

    func enqueue(_ text: String, completion: @escaping Completion) {
        nextID += 1
        let request = Request(id: nextID, text: text, completion: completion)
        queue.append(request)
        pending.insert(request.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + AppleTranslator.requestTimeout) { [weak self] in
            self?.expire(request.id)
        }
        startSessionIfNeeded()
    }

    @MainActor
    func drain(using session: TranslationSession) async {
        let current = generation
        sessionRequested = false
        draining = true
        defer {
            if current == generation { draining = false }
        }

        // 语言包没装时不调 translate：它会在看不见的宿主窗口上请求下载
        let availability = await AppleTranslator.availability()
        guard current == generation else { return }
        guard availability == .installed else {
            failQueued(availability == .notInstalled ? .notInstalled : .failed("系统不支持英→中翻译"))
            return
        }

        while current == generation, !Task.isCancelled, !queue.isEmpty {
            let request = queue.removeFirst()
            let result: Result<String, GlossTypeCore.TranslationError>
            do {
                let response = try await session.translate(request.text)
                result = .success(response.targetText)
            } catch {
                NSLog("GlossType: 翻译失败：\(error)")
                let availability = await AppleTranslator.availability()
                result = .failure(availability == .notInstalled ? .notInstalled : .failed(error.localizedDescription))
            }
            finish(request, with: result)
        }
    }

    private func startSessionIfNeeded() {
        guard !draining, !sessionRequested else { return }
        sessionRequested = true
        if configuration == nil {
            configuration = TranslationSession.Configuration(source: AppleTranslator.source, target: AppleTranslator.target)
        } else {
            configuration?.invalidate()
        }
    }

    private func expire(_ id: Int) {
        guard pending.contains(id) else { return }
        NSLog("GlossType: 翻译请求 \(Int(AppleTranslator.requestTimeout)) 秒内没有结果，判为失败并重建会话")
        if let index = queue.firstIndex(where: { $0.id == id }) {
            finish(queue.remove(at: index), with: .failure(.failed("翻译超时")))
        } else {
            // 正在 translate 的那个：先回调失败，等它真的返回时 finish 会丢掉结果
            pending.remove(id)
        }
        rebuildSession()
    }

    /// 放弃当前会话。队列里还有请求就立刻用新配置重启任务，否则清空配置让 SwiftUI 取消旧任务。
    private func rebuildSession() {
        generation += 1
        draining = false
        sessionRequested = false
        if queue.isEmpty {
            configuration = nil
        } else {
            startSessionIfNeeded()
        }
    }

    private func failQueued(_ error: GlossTypeCore.TranslationError) {
        let requests = queue
        queue.removeAll()
        for request in requests {
            finish(request, with: .failure(error))
        }
    }

    private func finish(_ request: Request, with result: Result<String, GlossTypeCore.TranslationError>) {
        guard pending.remove(request.id) != nil else { return }
        request.completion(result)
    }
}

private struct TranslationHostView: View {
    @ObservedObject var host: TranslationHost

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(host.configuration) { session in
                await host.drain(using: session)
            }
    }
}
#endif
