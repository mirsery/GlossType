import AppKit
import GlossTypeCore
import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// 设置窗：从输入法菜单的「设置…」打开。
final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?

    init(environment: AppEnvironment) {
        model = SettingsModel(environment: environment)
    }

    func show() {
        model.reload()
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "GlossType 设置"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

final class SettingsModel: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            environment.preferencesStore.save(preferences)
        }
    }
    @Published var historyMessage = ""
    /// 每次打开设置窗加一，让语言包状态重新检查（可能在后台下载完了）。
    @Published private(set) var revision = 0

    let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        preferences = environment.preferences
    }

    func reload() {
        preferences = environment.preferencesStore.load()
        historyMessage = ""
        revision += 1
    }

    func clearHistory() {
        guard let history = environment.history else {
            historyMessage = "学习记录不可用"
            return
        }
        do {
            try history.clear()
            historyMessage = "已清除"
        } catch {
            historyMessage = "清除失败：\(error.localizedDescription)"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section("显示") {
                Toggle("候选下方显示中文释义", isOn: $model.preferences.showGloss)
                Toggle("候选窗底部显示整句翻译", isOn: $model.preferences.showTranslation)
                Toggle("短语联想（⇧⇥ 接受）", isOn: $model.preferences.phrasePrediction)
                Stepper("候选数量：\(model.preferences.candidateCount)", value: $model.preferences.candidateCount, in: Preferences.candidateCountRange)
                Stepper("翻译延迟：\(model.preferences.translationDelayMs) 毫秒", value: $model.preferences.translationDelayMs, in: Preferences.translationDelayRange, step: 100)
            }
            Section("学习") {
                Toggle("记录我的用词习惯", isOn: $model.preferences.learningEnabled)
                HStack {
                    Button("清除学习记录…") { confirmingClear = true }
                    Text(model.historyMessage).foregroundColor(.secondary)
                }
            }
            Section("翻译语言包（英文 → 简体中文）") {
                LanguagePackRow(revision: model.revision)
            }
            Section("数据") {
                LabeledRow(title: "词典", value: model.environment.glossaryDescription)
                LabeledRow(title: "语言模型", value: model.environment.languageModelDescription)
                Text("自备语言模型放在 ~/Library/Application Support/GlossType/ngram.sqlite，重启输入法生效。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .alert("清除全部学习记录？", isPresented: $confirmingClear) {
            Button("清除", role: .destructive) { model.clearHistory() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("记下的用词和搭配会全部删除，不能恢复。")
        }
    }
}

private struct LabeledRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing)
        }
    }
}

/// 语言包状态和下载按钮。下载走系统的确认界面（prepareTranslation）。
private struct LanguagePackRow: View {
    let revision: Int
    #if canImport(Translation)
    @State private var configuration: TranslationSession.Configuration?
    #endif
    @State private var status = "检查中…"
    @State private var preparing = false

    var body: some View {
        #if canImport(Translation)
        HStack {
            Text(status).foregroundColor(.secondary)
            Spacer()
            Button("下载语言包") {
                preparing = true
                if configuration == nil {
                    configuration = TranslationSession.Configuration(source: AppleTranslator.source, target: AppleTranslator.target)
                } else {
                    configuration?.invalidate()
                }
            }
            .disabled(status == "已安装" || preparing)
        }
        .task(id: revision) { await refresh() }
        .translationTask(configuration) { session in
            do {
                try await session.prepareTranslation()
                await refresh()
            } catch {
                // 用户关掉进度界面时下载可能还在后台继续，下次打开设置窗会重新检查
                status = "下载未完成：\(error.localizedDescription)"
            }
            preparing = false
        }
        #else
        Text("当前系统不支持本地翻译").foregroundColor(.secondary)
        #endif
    }

    #if canImport(Translation)
    @MainActor
    private func refresh() async {
        switch await AppleTranslator.availability() {
        case .installed: status = "已安装"
        case .notInstalled: status = "未下载"
        case .unsupported: status = "系统不支持英→中翻译"
        }
    }
    #endif
}
