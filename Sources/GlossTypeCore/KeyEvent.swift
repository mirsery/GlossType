import Foundation

/// 输入法关心的按键。App 把 NSEvent 映射成它，InputSession 只看它。
public enum Key: Equatable {
    /// 可打印字符（字母、数字、标点、撇号）。
    case character(Character)
    case space
    case tab
    /// Shift+Tab
    case backTab
    case enter
    case backspace
    case escape
    case left
    case right
    case up
    case down
    /// 带 ⌘ / ⌃ / ⌥ 的组合键。
    case shortcut
    /// 其它不可打印的键（功能键、Home / End、向前删除等）。
    case other
}

public struct KeyModifiers: OptionSet {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let shift = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
}

/// 系统键码与字符 → Key。
public enum KeyMapper {
    public enum Code {
        public static let enter: UInt16 = 36
        public static let keypadEnter: UInt16 = 76
        public static let tab: UInt16 = 48
        public static let space: UInt16 = 49
        public static let backspace: UInt16 = 51
        public static let escape: UInt16 = 53
        public static let left: UInt16 = 123
        public static let right: UInt16 = 124
        public static let down: UInt16 = 125
        public static let up: UInt16 = 126
    }

    public static func key(keyCode: UInt16, characters: String?, modifiers: KeyModifiers) -> Key {
        if !modifiers.isDisjoint(with: [.command, .control, .option]) {
            return .shortcut
        }
        switch keyCode {
        case Code.enter, Code.keypadEnter: return .enter
        case Code.tab: return modifiers.contains(.shift) ? .backTab : .tab
        case Code.space: return .space
        case Code.backspace: return .backspace
        case Code.escape: return .escape
        case Code.left: return .left
        case Code.right: return .right
        case Code.down: return .down
        case Code.up: return .up
        default: break
        }
        guard let characters, characters.count == 1, let character = characters.first, isPrintable(character) else {
            return .other
        }
        return .character(character)
    }

    /// 排除控制字符和 AppKit 给功能键用的私用区字符（U+F700–U+F8FF）。
    static func isPrintable(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
                && !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !(0xF700...0xF8FF).contains(scalar.value)
        }
    }
}
