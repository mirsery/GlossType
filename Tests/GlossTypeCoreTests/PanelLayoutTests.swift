import CoreGraphics
import Foundation
import GlossTypeCore
import XCTest

final class PanelLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 300, height: 80)

    private func frame(caret: CGRect, mouse: CGPoint = CGPoint(x: 10, y: 10)) -> CGRect {
        PanelLayout.frame(panelSize: size, caretRect: caret, visibleFrame: screen, mouseLocation: mouse)
    }

    func test_panel_01_below_caret() {
        let caret = CGRect(x: 100, y: 500, width: 2, height: 18)
        let result = frame(caret: caret)
        XCTAssertEqual(result.minX, caret.minX)
        XCTAssertEqual(result.maxY, caret.minY - 4)
        XCTAssertEqual(result.size, size)
    }

    func test_panel_02_above_caret_when_no_room_below() {
        let caret = CGRect(x: 100, y: 50, width: 2, height: 18)
        let result = frame(caret: caret)
        XCTAssertEqual(result.minY, caret.maxY + 4)
    }

    func test_panel_03_clamped_to_screen_horizontally() {
        let caret = CGRect(x: 1400, y: 500, width: 2, height: 18)
        let result = frame(caret: caret)
        XCTAssertLessThanOrEqual(result.maxX, screen.maxX)
        XCTAssertEqual(result.maxX, screen.maxX)
    }

    func test_panel_04_follows_mouse_without_caret() {
        let mouse = CGPoint(x: 600, y: 400)
        let result = frame(caret: .zero, mouse: mouse)
        XCTAssertEqual(result.minX, mouse.x)
        XCTAssertEqual(result.maxY, mouse.y - 4)
    }

    func test_panel_05_deactivation_hides_panel() {
        let session = makeSession(lexicon: FakeLexicon(["hello"]))
        session.type("hel")
        XCTAssertNotNil(session.panel)
        XCTAssertEqual(session.deactivate(), [.insertText("hel")])
        XCTAssertNil(session.panel)
    }
}
