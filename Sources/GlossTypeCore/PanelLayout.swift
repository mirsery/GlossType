import CoreGraphics
import Foundation

/// 候选窗位置（屏幕坐标，原点在左下）。
public enum PanelLayout {
    /// 候选窗与光标行之间的间距。
    public static let gap: CGFloat = 4

    /// - Parameters:
    ///   - caretRect: 光标所在行的矩形；应用给不出时为零矩形。
    ///   - visibleFrame: 光标所在屏幕的可见区域（去掉菜单栏和程序坞）。
    ///   - mouseLocation: 拿不到光标时的退路。
    public static func frame(panelSize: CGSize, caretRect: CGRect, visibleFrame: CGRect, mouseLocation: CGPoint) -> CGRect {
        let anchor = caretRect == .zero
            ? CGRect(origin: mouseLocation, size: .zero)
            : caretRect

        var origin = CGPoint(x: anchor.minX, y: anchor.minY - gap - panelSize.height)
        if origin.y < visibleFrame.minY {
            origin.y = anchor.maxY + gap
        }
        if origin.y + panelSize.height > visibleFrame.maxY {
            origin.y = visibleFrame.maxY - panelSize.height
        }
        origin.x = min(origin.x, visibleFrame.maxX - panelSize.width)
        origin.x = max(origin.x, visibleFrame.minX)
        return CGRect(origin: origin, size: panelSize)
    }
}
