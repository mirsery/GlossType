import AppKit
import GlossTypeCore
import SwiftUI

/// 候选窗：不抢焦点、浮在全屏应用上、跟随光标。内容由 SwiftUI 渲染，位置由 Core 的 PanelLayout 计算。
final class CandidatePanelController {
    private var model: PanelModel?
    private var translation: TranslationLine?
    private var caretRect = NSRect.zero
    private lazy var hostingView = NSHostingView(rootView: CandidateView(model: nil, translation: nil))
    private lazy var panel: NSPanel = makePanel()
    /// show 期间译文的变化只记下、不单独渲染，最后统一渲染一次。
    private var batching = false

    /// 换上新内容和位置；`updateTranslation` 里更新译文（会同步回调 `updateTranslation(_:)`），
    /// 返回最新的译文行。整个过程只渲染一次，不会先用旧内容闪一下。
    func show(_ model: PanelModel, caretRect: NSRect, updateTranslation: () -> TranslationLine?) {
        self.model = model
        self.caretRect = caretRect
        batching = true
        translation = updateTranslation()
        batching = false
        render()
    }

    func updateTranslation(_ line: TranslationLine?) {
        translation = line
        if model != nil, !batching { render() }
    }

    func hide() {
        model = nil
        translation = nil
        if panel.isVisible { panel.orderOut(nil) }
    }

    private func render() {
        guard let model else { return }
        hostingView.rootView = CandidateView(model: model, translation: translation)
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        guard size.width > 1, size.height > 1 else {
            panel.orderOut(nil)
            return
        }
        let anchor = caretRect == .zero ? NSRect(origin: NSEvent.mouseLocation, size: .zero) : caretRect
        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = PanelLayout.frame(panelSize: size, caretRect: caretRect, visibleFrame: visibleFrame, mouseLocation: NSEvent.mouseLocation)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.contentView = hostingView
        return panel
    }
}

/// 候选窗内容：带编号的候选和释义、⇧⇥ 短语、译文。
struct CandidateView: View {
    let model: PanelModel?
    let translation: TranslationLine?

    private static let maxWidth: CGFloat = 520

    var body: some View {
        if let model {
            VStack(alignment: .leading, spacing: 6) {
                if !model.items.isEmpty {
                    candidates(model)
                }
                if let phrase = model.phrase {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("⇧⇥").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                        Text(phrase).font(.system(size: 13))
                    }
                }
                if let translation {
                    translationLine(translation)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: Self.maxWidth, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
            .fixedSize()
        }
    }

    private func candidates(_ model: PanelModel) -> some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(model.items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(index + 1)").font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                        Text(item.text).font(.system(size: 15))
                    }
                    if let gloss = item.gloss {
                        Text(gloss).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(index == model.highlightedIndex && model.mode == .composing ? Color.accentColor.opacity(0.22) : Color.clear)
                )
            }
        }
    }

    private func translationLine(_ line: TranslationLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("译").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            Text(line.text.isEmpty ? "…" : line.text)
                .font(.system(size: 13))
                .foregroundColor(line.status == .translated ? .primary : .secondary)
                .lineLimit(3)
                .frame(maxWidth: Self.maxWidth - 40, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
