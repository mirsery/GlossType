import Carbon
import Foundation

/// 把输入法注册进系统输入源列表并启用（make install 时执行 `GlossType --register`）。
enum InputSourceRegistration {
    static func registerAndEnable(bundle: Bundle) -> Bool {
        guard let bundleID = bundle.bundleIdentifier else {
            print("GlossType: 没有 Bundle ID，无法注册")
            return false
        }
        let status = TISRegisterInputSource(bundle.bundleURL as CFURL)
        guard status == noErr else {
            print("GlossType: TISRegisterInputSource 失败（\(status)）：\(bundle.bundleURL.path)")
            return false
        }
        let sources = inputSources(bundleID: bundleID)
        guard !sources.isEmpty else {
            print("GlossType: 注册后没找到输入源 \(bundleID)，注销再登录后到「设置 → 键盘 → 输入法」里手动添加")
            return false
        }
        var enabled = false
        for source in sources {
            let result = TISEnableInputSource(source)
            if result == noErr {
                enabled = true
            } else {
                print("GlossType: TISEnableInputSource 失败（\(result)）")
            }
        }
        if enabled {
            print("GlossType: 已注册并启用，可在菜单栏输入法列表里切换到 GlossType")
        }
        return enabled
    }

    private static func inputSources(bundleID: String) -> [TISInputSource] {
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() else { return [] }
        return (list as NSArray).map { $0 as! TISInputSource }
    }
}
