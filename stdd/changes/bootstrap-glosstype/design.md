# 设计：从零实现 GlossType 输入法

## 方案

### 分层

```
macOS ─ IMKServer ─ GlossTypeInputController（App，薄适配层）
                      │  NSEvent → KeyEvent（KeyMapper，Core）
                      ▼
                   InputSession（Core，状态机）
                      ├─ SentenceContext      当前这句已提交的文本、上下文词
                      ├─ SuggestionEngine     候选：原样 / 补全 / 纠错 / 下一个词 / 短语
                      │    ├─ LanguageModel   n-gram（基础模型 + 用户学习，CompositeLanguageModel）
                      │    ├─ WordLexicon     词频词表（glossary.sqlite）
                      │    ├─ SpellingProvider 系统拼写检查（App 里用 NSSpellChecker 实现）
                      │    └─ Glossary        中文释义（glossary.sqlite）
                      └─ LearningRecorder     提交时记录搭配（UserHistoryStore）
                      │
                      ▼  输出：KeyResult（是否吞键 + 对客户端的动作）、PanelModel、翻译源文本
   App：执行 insertText / setMarkedText；CandidatePanel 渲染；TranslationCoordinator（Core）调度 AppleTranslator（App）
```

Core 只依赖 Foundation 和 SQLite3，所有行为在 Core 里实现并单测；App 只做三件事：把系统事件翻译成 Core 的输入、把 Core 的输出落到客户端和窗口、把系统能力（拼写检查、翻译、TIS 注册）包成 Core 定义的接口。

### 按键语义

两种状态：**组词**（有标记文本）和**联想**（刚提交完，候选窗显示下一个词）。

| 按键 | 组词 | 联想 | 空闲（无候选窗） |
|---|---|---|---|
| 字母 | 追加到组词 | 开始组词，补全带上下文 | 开始组词 |
| `'` | 词中间：追加；词首不算 | 透传 | 透传 |
| 空格 | 提交高亮候选（默认原样）+ 空格，进入联想 | 透传，收起 | 透传 |
| `1`–`9` | 提交第 N 个候选 + 空格；超出候选数则提交原样 + 该数字 | 透传（打数字） | 透传 |
| Tab | 提交第一个建议词（没有建议就提交原样）+ 空格 | 接受高亮的下一个词 + 空格，继续联想 | 透传 |
| ⇧Tab | 提交短语（组词时为「建议词 + 短语续写」） | 接受整条短语 + 空格 | 透传 |
| ← / → | 移动高亮（循环） | 透传，收起 | 透传 |
| ↑ / ↓ | 提交原样，透传 | 透传，收起 | 透传 |
| 回车 | 提交高亮候选，不加空格，吞掉回车 | 透传，收起 | 透传 |
| Esc | 提交原样，收起，吞掉 | 收起，吞掉 | 透传 |
| 退格 | 删组词末字符；删空后清标记、收起 | 透传，收起 | 透传 |
| 标点等其它可打印字符 | 提交原样 + 该字符 | 透传 | 透传 |
| ⌘ / ⌃ / ⌥ 组合键 | 提交原样，透传 | 透传，收起 | 透传 |

- 空格默认提交**原样**而不是纠错结果：不在用户没看的时候改字。要用建议词按 Tab 或数字。
- 联想状态下数字透传：联想窗经常开着，用数字选词会让打数字变得不可靠。
- 所有「透传」的可打印字符同时追加进 SentenceContext；回车、方向键、⌘ 组合键、退格到空等无法确定光标位置的操作会重置或修正上下文（见下）。

### 当前句上下文

SentenceContext 只记输入法自己看得到的文本：提交的词、透传的可打印字符。句末符号（`.` `!` `?` 换行）之后算新的一句。方向键、回车、⌘ 组合键、切换应用、失焦都会让光标位置变得不可知，直接清空上下文。退格在空闲 / 联想状态下删掉上下文最后一个字符。App 能从客户端读到光标前文本时（`attributedSubstring`），在激活时用它做种子；读不到就从空开始。清空后不知道当前句从哪开始，这时既不补句首标记 `<s>`，也不按句首大写联想，直到遇到句末符号；种子从文档开头读起时句首是确定的。空闲时敲空格，只有前一个字符不是空白（刚打完一个词或标点）才进入联想，连续空格不弹窗。

### 候选排序

组词（前缀 p，上下文 c）：

1. 原样永远排第一（编号 1）。
2. 建议词按来源顺序合并去重（完全相同的字符串才算重复）：
   1. 原样不是已知词（词表和系统拼写都不认识）时，系统拼写纠错前两个排最前；
   2. 语言模型在上下文 c 下以 p 开头的续词，按得分（基础模型 stupid backoff + 用户学习加权）；
   3. 词频词表里以 p 开头的词，按词频排名；
   4. 系统拼写检查的补全。
3. 截到设置里的候选数量（默认 5，3–9；含原样）。
4. 大小写：词典显示形式本身带大写（I、London、iPhone）就保留；用户输入两个以上字母且全大写 → 全大写；首字母大写 → 首字母大写；其余小写。

联想（上下文 c，前缀空）：语言模型在 c 下有上下文证据的续词（退到一元的不算），按得分排序；句首（当前句为空）时首字母大写。没有联想词但整句翻译开着时，候选窗只显示译文行（没有语言模型也能边打边看整句翻译）。

短语：从第一个建议词 / 第一个联想词出发，用语言模型贪心向后接，每步取得分最高的词，最多再接 4 个；遇到句末标记、重复词或续词在该上下文下的出现次数低于 2 时停止。只有接上至少 1 个词才显示。

### 语言模型

接口：`nextWords(context: [String], prefix: String, limit: Int) -> [ScoredWord]`，context 为小写词序列，句首用 `<s>`。

参考实现 `NGramLanguageModel` 读 `ngram.sqlite`（格式见 `docs/data-formats.md`）：词表 + 各阶上下文的续词计数 + 上下文总数，用 stupid backoff（高阶命中直接用相对频率，退一阶乘 0.4）。最高阶由文件 meta 决定（默认 3）。

`scripts/build_ngram.py` 从一行一句的纯文本生成该格式：小写化、只保留字母词（含撇号缩写）、句首 `<s>` 句尾 `</s>`、按最小出现次数和每个上下文的续词上限剪枝、记录最常见的大小写形式作为显示形式、把语料名称和许可证写进 meta。语料选择留给维护者（要日常会话风格），脚本不下载任何语料。

加载顺序：`~/Library/Application Support/GlossType/ngram.sqlite`（用户自备）→ app 包内 `ngram.sqlite` → 无模型。无模型时补全退回词频词表和系统拼写检查，联想和短语为空。

### 用户学习

`UserHistoryStore`（`~/Library/Application Support/GlossType/user-history.sqlite`）：每次提交一个词 w（空格 / Tab / ⇧Tab / 数字选词 / 回车 / 常见标点结束的组词，短语中的每个词），以它前面 0–2 个词为上下文各记一次；Esc、方向键、快捷键、失焦打断的组词，以及被数字、`_`、`-` 等粘连字符结束的组词（v2、user_name）不记。只记纯字母词（允许撇号），含数字或其它符号的不记。`CompositeLanguageModel` 把用户得分（该上下文下的相对频率，权重 1.0）加到基础模型得分上，所以用户在某个上下文里用过的词很快排到前面。词表和系统拼写检查都不认识的词（生词或打错的词），在语言模型里（基础模型或学习记录）总共至少出现 2 次才进候选和联想，避免一次手滑的错字以后反复冒出来。设置里可关闭学习（关闭后不写入，已学的仍参与排序）和清除记录（删全部行）。

### 中文释义

`glossary.sqlite` 由 `scripts/build_glossary.py` 从 ECDICT（MIT）生成：只收单个词（字母、撇号、连字符）；释义压缩成短形式（去词性前缀和 `[计]` 这类领域标签，取前三个义项，用「，」连接）；按 COCA 词频（`frq`）排名，没有就用 BNC，都没有排在后面；默认收 60000 个词；从 `exchange` 字段把变形（过去式、分词、复数、比较级）展开成独立条目，指向原形的释义。

运行时查询：原词 → 小写 → 规则还原（-s/-es/-ies、-ed/-ied、-ing、双写辅音）→ 无。显示时超过 10 个字截断加「…」。

### 整句翻译

`TranslationCoordinator`（Core）：

- 翻译源文本 = 当前句 + 组词的「有效词」（用户主动移动过高亮就是高亮候选；否则原样是已知词就用原样，不是就用第一个建议词）；联想状态下就是当前句；刚打完句末符号时是刚结束的那一句。只取最后 300 个字符。
- 源文本变化后等待设置里的延迟（默认 300ms）再请求；期间再变就重新计时。
- 每个请求带序号，回来的结果不是最新请求的就丢弃。
- 结果按源文本缓存（最近 200 条），命中直接显示不请求。
- 等待时显示上一次的译文（变灰），失败显示「翻译失败」，语言包未安装显示「未下载英→中语言包，可在设置中下载」，关闭整句翻译时不显示也不请求。

`AppleTranslator`（App，macOS 15 Translation 框架）：一个 1×1、透明、不接收鼠标的宿主窗口里放 SwiftUI 视图，用 `.translationTask(configuration)` 拿到 `TranslationSession`，在任务闭包里循环处理请求队列；队列空了任务结束，有新请求时 `invalidate()` 配置重启任务。每次请求前用 `LanguageAvailability` 查 en → zh-Hans 状态，未安装时直接回报「未安装」，不调用 `translate`（避免在不可见窗口上弹下载框）。设置窗里用同样的 `.translationTask` + `prepareTranslation()` 触发系统下载。

### 候选窗

NSPanel（无边框、不激活、层级高于普通窗口、可出现在全屏应用上），内容为 SwiftUI：

```
 1 helo   2 hello   3 help   4 held   5 hell
          你好       帮助      握住      地狱
 ⇧⇥ hello there
 译 你好，你在那里吗
```

位置由 `PanelLayout`（Core，纯函数）计算：光标矩形下方 4pt、左对齐；下方放不下就放到光标行上方；左右夹在屏幕可见区域内；客户端给不出光标矩形（零矩形）时用鼠标位置。

### 设置

`Preferences`（Core，UserDefaults）：`showGloss`（开）、`showTranslation`（开）、`phrasePrediction`（开）、`learningEnabled`（开）、`candidateCount`（5，夹在 3–9）、`translationDelayMs`（300，夹在 100–2000）。设置窗（SwiftUI）从输入法菜单的「设置…」打开。

### 打包与安装

SwiftPM 构建可执行文件，`scripts/package_app.sh` 组装 `.app`：`Contents/MacOS/GlossType`、`Contents/Info.plist`（来自 `Packaging/`）、`Contents/Resources/`（图标、`glossary.sqlite`、可选 `ngram.sqlite`），ad-hoc 签名。`make install` 复制到 `~/Library/Input Methods/`，执行 `GlossType --register`：`TISRegisterInputSource` 注册，再按 Bundle ID 找到输入源 `TISEnableInputSource`。

## 备选与取舍

| 方案 | 好处 | 代价 | 结论 |
|---|---|---|---|
| 语言模型用 KenLM（C++） | 成熟、压缩好 | 要带 C++ 静态库和桥接；模型文件大；格式不透明 | 不用。自定 SQLite n-gram 格式，纯 Swift 读取，任何语料都能用脚本生成 |
| 内置一份语料训练好的模型 | 开箱即有联想 | 维护者要日常会话风格、要自己挑语料和许可证 | 不内置，只给格式和生成脚本 |
| 组词用标记文本 vs 直接透传字母 | 标记文本：组词内容完全由输入法掌控，替换候选不需要读客户端 | 有下划线 | 用标记文本 |
| 空格提交原样 vs 提交第一个建议 | 原样：不会悄悄改字 | 要用建议词得按 Tab / 数字 | 提交原样 |
| 候选窗用 IMKCandidates vs 自绘 NSPanel | 自绘：能放释义、短语、翻译三层内容 | 自己处理位置和层级 | 自绘 |
| 翻译用苹果本地翻译 vs 云端 | 免费、离线、隐私 | 质量中等；macOS 15 只能经 SwiftUI 拿会话 | 先用苹果本地翻译，接口留好可换 |
| 工程用 Xcode 工程 vs SwiftPM + Makefile | SwiftPM：纯文本、可审阅、命令行可构建 | 要自己组装 `.app` | SwiftPM + 脚本组装 |
| 测试用 XCTest vs Swift Testing | XCTest：维护者本机（Swift 5.7）也能借助替身跑 Core 测试 | 测试名只能用标识符 | XCTest，场景 ID 编进函数名 |

## 数据 / 配置 / 协议变化

新增三个 SQLite 文件格式与六个设置项，见 `docs/data-formats.md` 和上文「设置」。

## 兼容与迁移

新项目，无旧数据。数据文件 meta 带 `format` 和 `version`，读取时版本不认识就当作没有该文件（退化为无模型 / 无释义），不崩溃。

## 风险与回滚

- **app 层没在本机编译过**：InputMethodKit / Translation 的 Swift 签名可能与 SDK 有出入。缓解：Core 在本机用 Swift 5.7 编译并跑测试；app 层用 macOS 13.1 SDK 做类型检查（Translation 部分用 `#if canImport(Translation)` 隔开）；另请独立复核。维护者首次编译若报错，按报错修。
- **Translation 在输入法进程里的可用性**：后台进程里 `.translationTask` 是否稳定要真机验证（手动场景 `[translation.13]`）。不行就退化为只显示释义，接口不变。
- **输入法进程常驻**：SQLite 连接常开、缓存有上限（翻译缓存 200 条），避免内存增长。
- 回滚：从输入源里移除 GlossType，删除 `~/Library/Input Methods/GlossType.app`。

## 要更新的约定

`AGENTS.md`「不变量与踩过的坑」已写入：Bundle ID、控制器类名一致性、主线程、Translation 宿主窗口、重装要 killall、Core 兼容 Swift 5.7。
