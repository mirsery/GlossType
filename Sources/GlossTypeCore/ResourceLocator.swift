import Foundation

/// 数据文件的查找顺序：用户目录（~/Library/Application Support/GlossType/）优先，其次 app 包内。
public enum ResourceLocator {
    public static let languageModelFileName = "ngram.sqlite"
    public static let glossaryFileName = "glossary.sqlite"
    public static let userHistoryFileName = "user-history.sqlite"

    public static func defaultUserDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("GlossType", isDirectory: true)
    }

    public static func locate(
        fileName: String,
        userDirectory: URL,
        bundleResources: URL?,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> String? {
        let userPath = userDirectory.appendingPathComponent(fileName).path
        if fileExists(userPath) { return userPath }
        if let bundlePath = bundleResources?.appendingPathComponent(fileName).path, fileExists(bundlePath) {
            return bundlePath
        }
        return nil
    }

    /// 加载语言模型：按查找顺序取第一份，格式或版本不认识就当作没有。
    public static func loadLanguageModel(userDirectory: URL, bundleResources: URL?) -> NGramLanguageModel? {
        guard let path = locate(fileName: languageModelFileName, userDirectory: userDirectory, bundleResources: bundleResources) else {
            return nil
        }
        let model = NGramLanguageModel(path: path)
        if model == nil {
            NSLog("GlossType: 语言模型 \(path) 格式或版本不认识，按没有语言模型处理")
        }
        return model
    }
}
