import Foundation

/// 对客户端（正在输入的应用）的动作，App 按顺序执行。
public enum ClientAction: Equatable {
    /// 设置标记文本；空串表示清掉。
    case setMarkedText(String)
    /// 插入文本（替换标记文本）。
    case insertText(String)
}

public struct KeyResult: Equatable {
    /// true：输入法吞掉这个键；false：执行完 actions 后把键交给应用。
    public var handled: Bool
    public var actions: [ClientAction]

    public init(handled: Bool, actions: [ClientAction] = []) {
        self.handled = handled
        self.actions = actions
    }

    public static let passThrough = KeyResult(handled: false)
}

/// 候选窗要显示的内容。
public struct PanelModel: Equatable {
    public enum Mode: Equatable {
        case composing
        case predicting
    }

    public struct Item: Equatable {
        public var text: String
        public var gloss: String?

        public init(text: String, gloss: String?) {
            self.text = text
            self.gloss = gloss
        }
    }

    public var mode: Mode
    public var items: [Item]
    public var highlightedIndex: Int
    /// ⇧Tab 能接受的短语（空格连接）。
    public var phrase: String?
}

/// 一个输入法会话的状态机：组词、联想、提交、上下文、学习。按键语义见 design.md。
/// 只在主线程使用。
public final class InputSession {
    public enum Mode: Equatable {
        case idle
        case composing
        case predicting
    }

    /// 翻译源文本最多取最后这么多个字符。
    public static let maxTranslationLength = 300

    public let engine: SuggestionEngine
    public var recorder: LearningRecorder?
    public var preferences: Preferences

    public private(set) var mode: Mode = .idle
    public private(set) var composition = ""
    public private(set) var context = SentenceContext()
    public private(set) var candidates: [String] = []
    public private(set) var highlightedIndex = 0
    public private(set) var phrase: [String]?
    /// 用户在这次组词里主动移动过高亮。
    private var highlightMoved = false

    public init(engine: SuggestionEngine, recorder: LearningRecorder? = nil, preferences: Preferences = Preferences()) {
        self.engine = engine
        self.recorder = recorder
        self.preferences = preferences
    }

    // MARK: 生命周期

    /// 输入法激活：用客户端光标前的文本做上下文种子（读不到就传空）。
    public func activate(seed: String = "", startKnown: Bool = false) {
        hide()
        context.reset(seed: seed, startKnown: startKnown)
    }

    /// 输入法失活：提交组词、收起候选窗、清空上下文。
    public func deactivate() -> [ClientAction] {
        let actions = commitComposition()
        hide()
        context.reset()
        return actions
    }

    /// 系统要求提交（失焦、点了别处）：组词按原样提交，不记学习。
    public func commitComposition() -> [ClientAction] {
        guard mode == .composing else {
            hide()
            return []
        }
        let action = commit(words: [composition], trailing: "", learn: false)
        hide()
        context.reset()
        return [action]
    }

    // MARK: 输出

    public var panel: PanelModel? {
        let panelMode: PanelModel.Mode
        switch mode {
        case .idle: return nil
        case .composing: panelMode = .composing
        case .predicting: panelMode = .predicting
        }
        let items = candidates.map { text in
            PanelModel.Item(text: text, gloss: preferences.showGloss ? engine.gloss(for: text) : nil)
        }
        return PanelModel(mode: panelMode, items: items, highlightedIndex: highlightedIndex, phrase: phrase?.joined(separator: " "))
    }

    /// 整句翻译的源文本：当前句 + 组词的有效词；当前句为空时取刚结束的那一句。
    public var translationSource: String {
        var source: String
        if mode == .composing {
            source = context.currentSentence + effectiveWord
        } else {
            source = context.currentSentence
            if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                source = context.lastCompletedSentence ?? ""
            }
        }
        source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(source.suffix(Self.maxTranslationLength))
    }

    /// 组词时代表「用户想打的词」：移动过高亮取高亮候选；否则原样是已知词取原样，不是取第一个建议词。
    private var effectiveWord: String {
        if highlightMoved, candidates.indices.contains(highlightedIndex) {
            return candidates[highlightedIndex]
        }
        if candidates.count < 2 || engine.isKnownWord(composition) {
            return composition
        }
        return candidates[1]
    }

    // MARK: 按键

    @discardableResult
    public func handle(_ key: Key) -> KeyResult {
        switch mode {
        case .composing: return handleComposing(key)
        case .predicting: return handlePredicting(key)
        case .idle: return handleIdle(key)
        }
    }

    private func handleIdle(_ key: Key) -> KeyResult {
        switch key {
        case .character(let character):
            if Self.startsWord(character) {
                return startComposing(with: character)
            }
            context.append(String(character))
            return .passThrough
        case .space:
            let previous = context.text.last
            context.append(" ")
            if let previous, !previous.isWhitespace {
                enterPredicting()
            }
            return .passThrough
        case .backspace:
            context.deleteBackward()
            return .passThrough
        case .escape:
            return .passThrough
        case .tab, .backTab, .enter, .left, .right, .up, .down, .shortcut, .other:
            context.reset()
            return .passThrough
        }
    }

    private func handleComposing(_ key: Key) -> KeyResult {
        switch key {
        case .character(let character):
            if Self.startsWord(character) || (TextRules.isApostrophe(character) && composition.last?.isLetter == true) {
                composition.append(character)
                refreshCompletions()
                return KeyResult(handled: true, actions: [.setMarkedText(composition)])
            }
            if let number = TextRules.selectionDigit(character) {
                if number <= candidates.count {
                    return commitAndPredict(words: [candidates[number - 1]])
                }
                let action = commit(words: [composition], trailing: String(character), learn: false)
                hide()
                return KeyResult(handled: true, actions: [action])
            }
            let action = commit(words: [composition], trailing: String(character), learn: TextRules.endsWordCleanly(character))
            hide()
            return KeyResult(handled: true, actions: [action])
        case .space:
            return commitAndPredict(words: [candidates[highlightedIndex]])
        case .tab:
            return commitAndPredict(words: [firstSuggestion])
        case .backTab:
            return commitAndPredict(words: phrase ?? [firstSuggestion])
        case .left:
            moveHighlight(by: -1)
            return KeyResult(handled: true)
        case .right:
            moveHighlight(by: 1)
            return KeyResult(handled: true)
        case .enter:
            let action = commit(words: [candidates[highlightedIndex]], trailing: "", learn: true)
            hide()
            return KeyResult(handled: true, actions: [action])
        case .escape:
            let action = commit(words: [composition], trailing: "", learn: false)
            hide()
            return KeyResult(handled: true, actions: [action])
        case .backspace:
            composition.removeLast()
            if composition.isEmpty {
                hide()
                return KeyResult(handled: true, actions: [.setMarkedText("")])
            }
            refreshCompletions()
            return KeyResult(handled: true, actions: [.setMarkedText(composition)])
        case .up, .down, .shortcut, .other:
            // 光标要移走或应用要处理快捷键：先把组词按原样落下，再交给应用
            let action = commit(words: [composition], trailing: "", learn: false)
            hide()
            context.reset()
            return KeyResult(handled: false, actions: [action])
        }
    }

    private func handlePredicting(_ key: Key) -> KeyResult {
        switch key {
        case .character(let character):
            if Self.startsWord(character) {
                return startComposing(with: character)
            }
            context.append(String(character))
            hide()
            return .passThrough
        case .tab:
            guard candidates.indices.contains(highlightedIndex) else { return dismissAndPass(resettingContext: true) }
            return commitAndPredict(words: [candidates[highlightedIndex]])
        case .backTab:
            if let phrase { return commitAndPredict(words: phrase) }
            guard candidates.indices.contains(highlightedIndex) else { return dismissAndPass(resettingContext: true) }
            return commitAndPredict(words: [candidates[highlightedIndex]])
        case .escape:
            hide()
            return KeyResult(handled: true)
        case .space:
            context.append(" ")
            return dismissAndPass(resettingContext: false)
        case .backspace:
            context.deleteBackward()
            return dismissAndPass(resettingContext: false)
        case .enter, .left, .right, .up, .down, .shortcut, .other:
            return dismissAndPass(resettingContext: true)
        }
    }

    // MARK: 内部

    /// 字母开始或延续一个词。
    static func startsWord(_ character: Character) -> Bool {
        character.isLetter
    }

    private var firstSuggestion: String {
        candidates.count > 1 ? candidates[1] : composition
    }

    private func startComposing(with character: Character) -> KeyResult {
        mode = .composing
        composition = String(character)
        refreshCompletions()
        return KeyResult(handled: true, actions: [.setMarkedText(composition)])
    }

    private func refreshCompletions() {
        let words = context.contextWords(maxCount: engine.contextLength)
        candidates = engine.completions(for: composition, context: words, count: preferences.candidateCount)
        if candidates.isEmpty { candidates = [composition] }
        highlightedIndex = 0
        highlightMoved = false
        phrase = preferences.phrasePrediction && candidates.count > 1
            ? engine.phrase(startingWith: candidates[1], after: words)
            : nil
    }

    private func enterPredicting() {
        composition = ""
        let words = context.contextWords(maxCount: engine.contextLength)
        candidates = engine.predictions(after: words, limit: preferences.candidateCount, capitalizeFirst: context.isAtSentenceStart)
        highlightedIndex = 0
        highlightMoved = false
        phrase = preferences.phrasePrediction && !candidates.isEmpty
            ? engine.phrase(startingWith: candidates[0], after: words)
            : nil
        mode = .predicting
        // 没有联想词时，只有还要显示译文才留着候选窗
        if candidates.isEmpty && (!preferences.showTranslation || translationSource.isEmpty) {
            hide()
        }
    }

    private func moveHighlight(by offset: Int) {
        guard !candidates.isEmpty else { return }
        highlightedIndex = (highlightedIndex + offset + candidates.count) % candidates.count
        highlightMoved = true
    }

    private func commitAndPredict(words: [String]) -> KeyResult {
        let action = commit(words: words, trailing: " ", learn: true)
        enterPredicting()
        return KeyResult(handled: true, actions: [action])
    }

    /// 提交若干个词（空格连接）加 trailing：更新上下文，按需逐词记学习。
    private func commit(words: [String], trailing: String, learn: Bool) -> ClientAction {
        for (index, word) in words.enumerated() {
            if learn && preferences.learningEnabled {
                recorder?.record(word: word, context: context.contextWords(maxCount: UserHistoryStore.maxContextWords))
            }
            context.append(word + (index == words.count - 1 ? trailing : " "))
        }
        composition = ""
        return .insertText(words.joined(separator: " ") + trailing)
    }

    private func dismissAndPass(resettingContext: Bool) -> KeyResult {
        hide()
        if resettingContext { context.reset() }
        return .passThrough
    }

    private func hide() {
        mode = .idle
        composition = ""
        candidates = []
        highlightedIndex = 0
        highlightMoved = false
        phrase = nil
    }
}
