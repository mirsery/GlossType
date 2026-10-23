import Carbon
import Foundation

/// 把输入法注册进系统输入源列表并启用（make install 时执行 `GlossType --register`）。
/// 注册或启用不成功时只给出提示：app 已经装好，到系统设置里手动添加也能用，不让 make install 失败。
enum InputSourceRegistration {
    static func registerAndEnable(bundle: Bundle) -> Bool {
        guard let bundleID = bundle.bundleIdentifier else {
            print("GlossType: 没有 Bundle ID，无法注册")
            return false
        }
        let status = TISRegisterInputSource(bundle.bundleURL as CFURL)
        if status != noErr {
            // 已经注册过时也可能返回错误，继续找输入源
            print("GlossType: TISRegisterInputSource 返回 \(status)（\(bundle.bundleURL.path)），继续尝试启用")
        }
        let sources = inputSources(bundleID: bundleID)
        guard !sources.isEmpty else {
            print("GlossType: 还没在输入源列表里找到 \(bundleID)。注销再登录后，到「系统设置 → 键盘 → 输入法」里添加 GlossType")
            return true
        }
        var failed = false
        for source in sources where !isEnabled(source) {
            let result = TISEnableInputSource(source)
            if result != noErr {
                failed = true
                print("GlossType: TISEnableInputSource 返回 \(result)")
            }
        }
        if failed {
            print("GlossType: 已注册但没能自动启用，到「系统设置 → 键盘 → 输入法」里添加 GlossType")
        } else {
            print("GlossType: 已注册并启用，可在菜单栏输入法列表里切换到 GlossType")
        }
        return true
    }

    private static func inputSources(bundleID: String) -> [TISInputSource] {
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() else { return [] }
        return (list as NSArray).map { $0 as! TISInputSource }
    }

    private static func isEnabled(_ source: TISInputSource) -> Bool {
        guard let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
    }
}
