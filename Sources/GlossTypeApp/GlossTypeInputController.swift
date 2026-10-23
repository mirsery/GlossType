import AppKit
import GlossTypeCore
import InputMethodKit

/// IMK 为每个输入客户端创建一个控制器。这里只做适配：NSEvent → Key，ClientAction → 客户端调用，
/// 会话状态 → 候选窗与翻译。行为都在 Core 的 InputSession 里。
/// 类名要和 Info.plist 的 InputMethodServerControllerClass 一致（scripts/tests/test_install.py 检查）。
@objc(GlossTypeInputController)
final class GlossTypeInputController: IMKInputController {
    /// 光标前最多读这么多字符做上下文种子。
    private static let seedLength = 300

    private let session: InputSession
    private var environment: AppEnvironment { AppEnvironment.shared }

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let environment = AppEnvironment.shared
        session = InputSession(engine: environment.engine, recorder: environment.history, preferences: environment.preferences)
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    // MARK: 生命周期

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        session.preferences = environment.preferences
        guard let client = textInput(sender) else {
            session.activate()
            return
        }
        let (seed, startKnown) = Self.readSeed(from: client)
        session.activate(seed: seed, startKnown: startKnown)
    }

    override func deactivateServer(_ sender: Any!) {
        perform(session.deactivate(), on: textInput(sender))
        hidePanel()
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        perform(session.commitComposition(), on: textInput(sender))
        hidePanel()
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        return Int(mask.rawValue)
    }

    // MARK: 按键

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event else { return false }
        let client = textInput(sender)
        session.preferences = environment.preferences

        switch event.type {
        case .keyDown:
            let key = KeyMapper.key(keyCode: event.keyCode, characters: event.characters, modifiers: KeyModifiers(event.modifierFlags))
            let result = session.handle(key)
            perform(result.actions, on: client)
            refreshPanel(client: client)
            return result.handled
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // 点击会移动光标：落下组词、收起候选窗、清空上下文，点击本身交给应用
            perform(session.deactivate(), on: client)
            hidePanel()
            return false
        default:
            return false
        }
    }

    // MARK: 菜单

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "GlossType")
        let settings = NSMenuItem(title: "设置…", action: #selector(showPreferences(_:)), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        return menu
    }

    override func showPreferences(_ sender: Any!) {
        environment.settings.show()
    }

    // MARK: 内部

    private func textInput(_ sender: Any?) -> (IMKTextInput & NSObjectProtocol)? {
        if let client = sender as? (IMKTextInput & NSObjectProtocol) { return client }
        return client()
    }

    private func perform(_ actions: [ClientAction], on client: (IMKTextInput & NSObjectProtocol)?) {
        guard let client else { return }
        let notFound = NSRange(location: NSNotFound, length: 0)
        for action in actions {
            switch action {
            case .setMarkedText(let text):
                let selection = NSRange(location: (text as NSString).length, length: 0)
                client.setMarkedText(text, selectionRange: selection, replacementRange: notFound)
            case .insertText(let text):
                client.insertText(text, replacementRange: notFound)
            }
        }
    }

    private func refreshPanel(client: (IMKTextInput & NSObjectProtocol)?) {
        guard let model = session.panel else {
            hidePanel()
            return
        }
        environment.coordinator.update(source: session.translationSource)
        environment.panel.show(model, translation: environment.coordinator.line, caretRect: Self.caretRect(of: client))
    }

    private func hidePanel() {
        environment.coordinator.reset()
        environment.panel.hide()
    }

    /// 光标（或标记文本开头）所在行的屏幕矩形；应用给不出时为零矩形。
    private static func caretRect(of client: (IMKTextInput & NSObjectProtocol)?) -> NSRect {
        var rect = NSRect.zero
        _ = client?.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        return rect
    }

    /// 光标前的文本做上下文种子；从文档开头读起时句首是确定的。
    private static func readSeed(from client: IMKTextInput & NSObjectProtocol) -> (String, Bool) {
        let selection = client.selectedRange()
        guard selection.location != NSNotFound, selection.location > 0 else {
            return ("", selection.location == 0)
        }
        let start = max(0, selection.location - seedLength)
        let range = NSRange(location: start, length: selection.location - start)
        guard let text = client.attributedSubstring(from: range)?.string else { return ("", false) }
        return (text, start == 0)
    }
}

extension KeyModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.command) { insert(.command) }
    }
}
