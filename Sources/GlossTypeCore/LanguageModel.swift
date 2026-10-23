import Foundation

/// 语言模型给出的一个续词。
public struct ScoredWord: Equatable {
    /// 小写键；句末是 `</s>`。
    public var word: String
    /// 显示形式（最常见的大小写）。
    public var display: String
    public var score: Double
    /// 在命中的那一阶上下文里出现的次数。
    public var count: Int
    /// 命中的上下文长度：0 表示退到了一元（没有上下文证据）。
    public var matchedOrder: Int

    public init(word: String, display: String, score: Double, count: Int, matchedOrder: Int) {
        self.word = word
        self.display = display
        self.score = score
        self.count = count
        self.matchedOrder = matchedOrder
    }
}

/// 可插拔的语言模型接口。context 是小写词序列，句首以 `<s>` 开头；
/// 返回以 prefix 开头的续词，按得分从高到低。prefix 为空时结果里可能有 `</s>`。
public protocol LanguageModel: AnyObject {
    /// 最高阶数（3 表示最多看前两个词）。
    var order: Int { get }
    func nextWords(after context: [String], prefix: String, limit: Int) -> [ScoredWord]
}

extension LanguageModel {
    /// 这个词不看上下文的出现次数（一元计数）。
    public func occurrences(of word: String) -> Int {
        nextWords(after: [], prefix: word, limit: 64).first { $0.word == word }?.count ?? 0
    }
}

/// Stupid backoff：高阶命中直接用相对频率，每退一阶乘这个系数。
public enum Backoff {
    public static let factor = 0.4

    /// 从最长的上下文往短里查，直到一元（上下文键为空串）。
    /// continuations 返回某个上下文键下的续词，score 是该上下文里的相对频率。
    /// 同一个词只取最高阶命中的那一次，matchedOrder 记命中的上下文长度。
    public static func search(
        context: [String],
        order: Int,
        limit: Int,
        continuations: (String) -> [ScoredWord]
    ) -> [ScoredWord] {
        guard limit > 0 else { return [] }
        let usable = Array(context.suffix(max(order - 1, 0)))
        var results: [String: ScoredWord] = [:]
        var multiplier = 1.0
        for length in stride(from: usable.count, through: 0, by: -1) {
            let key = usable.suffix(length).joined(separator: " ")
            for item in continuations(key) where results[item.word] == nil {
                var scored = item
                scored.score *= multiplier
                scored.matchedOrder = length
                results[item.word] = scored
            }
            multiplier *= factor
        }
        return ranked(Array(results.values), limit: limit)
    }

    /// 按得分从高到低，同分按词排，截到 limit。
    public static func ranked(_ items: [ScoredWord], limit: Int) -> [ScoredWord] {
        let sorted = items.sorted { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.word < rhs.word
        }
        return Array(sorted.prefix(limit))
    }
}

/// 基础模型加用户学习：同一个词的得分相加，用户部分乘以权重。
public final class CompositeLanguageModel: LanguageModel {
    public let base: LanguageModel?
    public let user: LanguageModel?
    public let userWeight: Double

    public init(base: LanguageModel?, user: LanguageModel?, userWeight: Double = 1.0) {
        self.base = base
        self.user = user
        self.userWeight = userWeight
    }

    public var order: Int {
        max(base?.order ?? 1, user?.order ?? 1)
    }

    public func nextWords(after context: [String], prefix: String, limit: Int) -> [ScoredWord] {
        var merged: [String: ScoredWord] = [:]
        for item in base?.nextWords(after: context, prefix: prefix, limit: limit * 2) ?? [] {
            merged[item.word] = item
        }
        for item in user?.nextWords(after: context, prefix: prefix, limit: limit * 2) ?? [] {
            if var existing = merged[item.word] {
                // 显示形式以基础模型为准，次数和命中阶数取两边较大的
                existing.score += userWeight * item.score
                existing.count = max(existing.count, item.count)
                existing.matchedOrder = max(existing.matchedOrder, item.matchedOrder)
                merged[item.word] = existing
            } else {
                var weighted = item
                weighted.score *= userWeight
                merged[item.word] = weighted
            }
        }
        return Backoff.ranked(Array(merged.values), limit: limit)
    }
}
