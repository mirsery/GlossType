import AppKit
import InputMethodKit

// 输入法进程入口。`GlossType --register` 只做输入源注册（make install 调用），然后退出。
if CommandLine.arguments.contains("--register") {
    exit(InputSourceRegistration.registerAndEnable(bundle: .main) ? 0 : 1)
}

let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String
    ?? "io.github.mirsery.inputmethod.GlossType_Connection"
let server: IMKServer? = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
if server == nil {
    NSLog("GlossType: IMKServer 启动失败（连接名 \(connectionName)）")
    exit(1)
}
AppEnvironment.shared.server = server

NSApplication.shared.run()
