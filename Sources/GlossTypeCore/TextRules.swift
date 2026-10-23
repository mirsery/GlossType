import Foundation

/// 分词、大小写与字符分类规则。语言模型、学习记录、候选排序共用同一套规则。
public enum TextRules {
    public static let sentenceStart = "<s>"
    public static let sentenceEnd = "</s>"

    public static func isApostrophe(_ character: Character) -> Bool {
        character == "'" || character == "\u{2019}"
    }

    public static func isSentenceTerminator(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?" || character == "\n" || character == "\r"
    }

    /// 1–9 的数字键，返回对应的数字。
    public static func selectionDigit(_ character: Character) -> Int? {
        guard let value = character.wholeNumberValue, (1...9).contains(value), character.isASCII else { return nil }
        return value
    }

    /// 文本里的词：字母序列，中间可以夹撇号（don't、I'm），统一成小写和直撇号。
    public static func words(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var pendingApostrophe = false
        for character in text {
            if character.isLetter {
                if pendingApostrophe {
                    current.append("'")
                    pendingApostrophe = false
                }
                current.append(contentsOf: character.lowercased())
            } else if isApostrophe(character), !current.isEmpty {
                pendingApostrophe = true
            } else {
                if !current.isEmpty { result.append(current) }
                current = ""
                pendingApostrophe = false
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// 能进学习记录的词：只有字母，中间可以夹撇号。
    public static func isLearnableWord(_ word: String) -> Bool {
        guard let first = word.first, let last = word.last, first.isLetter, last.isLetter else { return false }
        var previousWasApostrophe = false
        for character in word {
            if character.isLetter {
                previousWasApostrophe = false
            } else if isApostrophe(character), !previousWasApostrophe {
                previousWasApostrophe = true
            } else {
                return false
            }
        }
        return true
    }

    /// 组词被这个字符结束时，这个词算不算打完（能记进学习）：常见标点算；
    /// 数字、@、_、-、/ 这类会和前面粘成一个记号（v2、user_name）的不算。
    public static func endsWordCleanly(_ character: Character) -> Bool {
        ".,!?;:)]}\"\u{201D}".contains(character)
    }

    public static func capitalizeFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// 候选的显示形式跟随用户已输入部分的大小写：
    /// 输入两个以上字母且全大写 → 全大写；词典形式本身带大写（I、London、iPhone）→ 保留；
    /// 首字母大写 → 首字母大写；其余照词典形式。
    public static func applyCasing(typed: String, to display: String) -> String {
        let letters = typed.filter { $0.isLetter }
        if letters.count >= 2, letters == letters.uppercased(), letters != letters.lowercased() {
            return display.uppercased()
        }
        if display != display.lowercased() {
            return display
        }
        if let first = letters.first, first.isUppercase {
            return capitalizeFirst(display)
        }
        return display
    }

    /// SQLite 按前缀做范围查询的上界（BINARY 排序下大于所有以 prefix 开头的字符串）。
    public static func prefixUpperBound(_ prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }
}
