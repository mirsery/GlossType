#if canImport(Translation)
import AppKit
import GlossTypeCore
import SwiftUI
import Translation

/// 苹果本地翻译（macOS 15 Translation 框架）。macOS 15 只能通过 SwiftUI 的 `.translationTask` 拿到
/// TranslationSession，所以放一个 1×1、透明、不接收鼠标的宿主窗口承载这个任务。
final class AppleTranslator: Translator {
    static let source = Locale.Language(identifier: "en")
    static let target = Locale.Language(identifier: "zh-Hans")

    private let host = TranslationHost()
    private var window: NSWindow?

    func checkAvailability(_ completion: @escaping (TranslationAvailability) -> Void) {
        Task { @MainActor in
            completion(await Self.availability())
        }
    }

    func translate(_ text: String, completion: @escaping (Result<String, TranslationError>) -> Void) {
        installHostWindowIfNeeded()
        host.enqueue(text, completion: completion)
    }

    static func availability() async -> TranslationAvailability {
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]
        window.contentView = NSHostingView(rootView: TranslationHostView(host: host))
        window.orderFrontRegardless()
        self.window = window
    }
}

/// 请求队列。宿主视图的翻译任务把队列取空就结束；任务没在跑时来了新请求，就让配置失效以重启任务。
final class TranslationHost: ObservableObject {
    typealias Completion = (Result<String, TranslationError>) -> Void

    @Published var configuration: TranslationSession.Configuration?
    private var queue: [(text: String, completion: Completion)] = []
    private var draining = false

    func enqueue(_ text: String, completion: @escaping Completion) {
        queue.append((text, completion))
        guard !draining else { return }
        if configuration == nil {
            configuration = TranslationSession.Configuration(source: AppleTranslator.source, target: AppleTranslator.target)
        } else {
            configuration?.invalidate()
        }
    }

    @MainActor
    func drain(using session: TranslationSession) async {
        draining = true
        defer { draining = false }
        while !queue.isEmpty {
            let request = queue.removeFirst()
            do {
                let response = try await session.translate(request.text)
                request.completion(.success(response.targetText))
            } catch {
                request.completion(.failure(.failed(error.localizedDescription)))
            }
        }
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
