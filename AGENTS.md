# GlossType 开发约定

GlossType 是 macOS 15+ 的英文输入法：候选词带中文释义、候选窗底部显示整句中文翻译、提供下一个词与短语联想，并在本地学习用户习惯。全部离线运行（翻译用苹果系统自带的本地翻译）。

## 迭代流程

所有行为改动按 STDD 走，见 [`docs/dev/stdd.md`](docs/dev/stdd.md)。没有场景的行为不写代码；测试函数名带场景 ID（`test_<能力>_<序号>_…`）。

## 目录

| 路径 | 内容 |
|---|---|
| `Sources/GlossTypeCore/` | 纯逻辑：输入会话状态机、候选引擎、词典 / 语言模型 / 学习记录（SQLite）、翻译调度、候选窗布局、设置。只依赖 Foundation 和 SQLite3，不引 AppKit，全部可单测 |
| `Sources/GlossTypeApp/` | 输入法进程：InputMethodKit 控制器、候选窗（AppKit + SwiftUI）、系统拼写检查适配、苹果翻译适配、设置窗、输入源注册 |
| `Tests/GlossTypeCoreTests/` | Core 的 XCTest |
| `scripts/` | 数据构建（`build_glossary.py`、`build_ngram.py`）、STDD 追溯检查、打包；`scripts/tests/` 是它们的 unittest |
| `Packaging/` | `Info.plist`、图标，`make app` 用它们组装 `.app` |
| `docs/` | 开发文档、数据格式说明 |
| `stdd/` | 规格与变更记录 |

## 常用命令

| 命令 | 作用 |
|---|---|
| `make test` | 门禁：`swift test` + Python 测试 + STDD 追溯检查 |
| `make data` | 下载 ECDICT，生成 `Data/glossary.sqlite`（释义 + 词频词表） |
| `make lm CORPUS=<文本文件>` | 用一份语料（一行一句）生成 `Data/ngram.sqlite` |
| `make app` | release 构建并组装 `build/GlossType.app`（ad-hoc 签名） |
| `make install` | 装到 `~/Library/Input Methods/` 并注册、启用输入源 |

## 不变量与踩过的坑

- Bundle ID 必须含 `inputmethod`（`io.github.mirsery.inputmethod.GlossType`），否则系统不把它当输入法。
- `Packaging/Info.plist` 的 `InputMethodServerControllerClass` 必须等于控制器的 `@objc(...)` 名（`GlossTypeInputController`），由 `scripts/tests/test_install.py` 检查。
- InputMethodKit 的回调都在主线程；Core 里的类型不做线程同步，调用方保证在主线程用。翻译回调要切回主线程再交给 Core。
- macOS 15 的 Translation 框架只能通过 SwiftUI 的 `.translationTask` 拿到会话，输入法进程里用一个不可见的宿主窗口承载；语言包没下载时不在输入法里触发下载（会弹到不可见窗口上），只提示去设置窗下载。
- 重新安装后旧进程还在跑：`make install` 会先 `killall GlossType`。
- Core 要能被 Swift 5.7 编译（维护者本机验证用），不使用 `if` 表达式、宏、`@Observable` 等新语法；包按 Swift 5 语言模式编译。

## 提交

- 提交信息用中文，格式 `<type>(<scope>): <说明>`，type 取 `feat` / `fix` / `test` / `docs` / `refactor` / `chore`。
- 不提交 `Data/*.sqlite`、`build/` 等生成物。
