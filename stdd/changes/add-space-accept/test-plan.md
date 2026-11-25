# 测试方案：空格接受建议词和联想词

| 场景 | 层级 | 测试文件 | 要点 |
|---|---|---|---|
| `[composition.22]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | FakeSpelling 给 helo 纠错，断言 highlightedIndex 指向 hello |
| `[composition.23]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 空格插入 "hello " |
| `[composition.24]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 已知词高亮在原样，空格插入 "help " |
| `[composition.25]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 词表补全有 tomorrow、拼写无纠错，空格插入 "tomo " |
| `[composition.26]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | Esc 插入 "helo" |
| `[composition.27]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | ← 后空格插入 "helo "；再加一个字母后重新按规则定高亮 |
| `[prediction.20]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 联想状态空格插入 "you " |
| `[prediction.21]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 接受后候选第一个是 ok |
| `[prediction.22]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 无联想词时返回透传 |
| `[prediction.23]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 关闭时透传并收起 |
| `[settings.09]` | unit | `Tests/GlossTypeCoreTests/PreferencesTests.swift` | 空 UserDefaults 读出 true |
| `[settings.10]` | unit | `Tests/GlossTypeCoreTests/PreferencesTests.swift` | save false 后新 store 读出 false |
| `[settings.11]` | 手动 | — | 真机设置窗切换后在备忘录里按空格 |

另外：`[composition.07]` 的测试改为显式关闭开关；跑全量测试确认其它组词、联想、翻译场景不受默认开启影响。

## 手动验证

macOS 15 真机 `make install` 后：备忘录、Safari 地址栏里分别打 "I hav a qestion" + 空格，看是否被纠正；联想出现时连按空格接受；关掉开关重复一遍确认回到旧行为。

## 真实输出与回放

无。
