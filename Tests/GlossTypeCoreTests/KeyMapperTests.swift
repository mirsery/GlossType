import GlossTypeCore
import XCTest

final class KeyMapperTests: XCTestCase {
    func test_composition_21_system_keys_map_to_input_keys() {
        func key(_ code: UInt16, _ characters: String? = nil, _ modifiers: KeyModifiers = []) -> Key {
            KeyMapper.key(keyCode: code, characters: characters, modifiers: modifiers)
        }
        XCTAssertEqual(key(36, "\r"), .enter)
        XCTAssertEqual(key(76, "\u{3}"), .enter)
        XCTAssertEqual(key(48, "\t"), .tab)
        XCTAssertEqual(key(48, "\u{19}", [.shift]), .backTab)
        XCTAssertEqual(key(49, " "), .space)
        XCTAssertEqual(key(49, " ", [.shift]), .space)
        XCTAssertEqual(key(51, "\u{7f}"), .backspace)
        XCTAssertEqual(key(53, "\u{1b}"), .escape)
        XCTAssertEqual(key(123, "\u{F702}"), .left)
        XCTAssertEqual(key(124, "\u{F703}"), .right)
        XCTAssertEqual(key(125, "\u{F701}"), .down)
        XCTAssertEqual(key(126, "\u{F700}"), .up)
        XCTAssertEqual(key(0, "a"), .character("a"))
        XCTAssertEqual(key(4, "H", [.shift]), .character("H"))
        XCTAssertEqual(key(43, ","), .character(","))
        XCTAssertEqual(key(39, "'"), .character("'"))
        XCTAssertEqual(key(19, "2"), .character("2"))
    }

    func test_composition_21_modifier_combinations_are_shortcuts() {
        XCTAssertEqual(KeyMapper.key(keyCode: 0, characters: "a", modifiers: [.command]), .shortcut)
        XCTAssertEqual(KeyMapper.key(keyCode: 0, characters: "\u{1}", modifiers: [.control]), .shortcut)
        XCTAssertEqual(KeyMapper.key(keyCode: 0, characters: "å", modifiers: [.option]), .shortcut)
        XCTAssertEqual(KeyMapper.key(keyCode: 123, characters: "\u{F702}", modifiers: [.option]), .shortcut)
        XCTAssertEqual(KeyMapper.key(keyCode: 48, characters: "\t", modifiers: [.control]), .shortcut)
    }

    func test_composition_21_non_printable_keys_are_other() {
        XCTAssertEqual(KeyMapper.key(keyCode: 117, characters: "\u{F728}", modifiers: []), .other)
        XCTAssertEqual(KeyMapper.key(keyCode: 122, characters: "\u{F704}", modifiers: []), .other)
        XCTAssertEqual(KeyMapper.key(keyCode: 115, characters: "\u{F729}", modifiers: []), .other)
        XCTAssertEqual(KeyMapper.key(keyCode: 200, characters: nil, modifiers: []), .other)
    }
}
