# 测试方案：从零实现 GlossType 输入法

Core 的测试用 XCTest，靠假的语言模型 / 词表 / 拼写检查 / 翻译器（`Tests/GlossTypeCoreTests/TestSupport.swift`）把输入法行为和系统能力隔开；涉及 SQLite 的用临时文件或脚本生成的夹具。数据脚本和打包用 Python unittest。

| 场景 | 层级 | 测试文件 | 要点 |
|---|---|---|---|
| `[composition.01]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 字母组成标记文本 |
| `[composition.02]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | Shift 加字母按大写组词 |
| `[composition.03]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 词中间的撇号继续组词 |
| `[composition.04]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 词首的撇号交还给应用 |
| `[composition.05]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 退格删组词末尾字符 |
| `[composition.06]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 退格删空后收起 |
| `[composition.07]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 空格提交原样 |
| `[composition.08]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 空格提交移动过的高亮候选 |
| `[composition.09]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 数字提交第 N 个候选 |
| `[composition.10]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 数字超出候选数时提交原样加数字 |
| `[composition.11]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | Tab 提交第一个建议词 |
| `[composition.12]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 没有建议词时 Tab 提交原样 |
| `[composition.13]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 左右方向键循环移动高亮 |
| `[composition.14]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 回车只确认组词 |
| `[composition.15]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | Esc 提交原样并收起 |
| `[composition.16]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 标点提交原样加标点 |
| `[composition.17]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 修饰键组合提交原样后交给应用 |
| `[composition.18]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 上下方向键提交原样后交给应用 |
| `[composition.19]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 失焦时提交原样 |
| `[composition.20]` | unit | `Tests/GlossTypeCoreTests/CompositionTests.swift` | 空闲时非字母键交还给应用 |
| `[composition.21]` | unit | `Tests/GlossTypeCoreTests/KeyMapperTests.swift` | 系统按键映射成输入法按键 |
| `[completion.01]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 原样排第一，补全按词频 |
| `[completion.02]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 上下文续词排在词频之前 |
| `[completion.03]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 原样不是已知词时纠错排最前 |
| `[completion.04]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 原样是已知词时不放纠错 |
| `[completion.05]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 系统拼写补全补位 |
| `[completion.06]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 不同来源的同一个词只出现一次 |
| `[completion.07]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 原样不重复出现 |
| `[completion.08]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 首字母大写跟随输入 |
| `[completion.09]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 全大写跟随输入 |
| `[completion.10]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 专有名词保留自身大小写 |
| `[completion.11]` | unit | `Tests/GlossTypeCoreTests/CompletionTests.swift` | 候选数量受设置限制 |
| `[prediction.01]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 提交词后显示下一个词 |
| `[prediction.02]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 高阶上下文优先 |
| `[prediction.03]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 句首联想首字母大写 |
| `[prediction.04]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 手动敲空格后也联想 |
| `[prediction.05]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | Tab 接受联想词 |
| `[prediction.06]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 接受联想词后继续联想 |
| `[prediction.07]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | ⇧Tab 接受整条短语 |
| `[prediction.08]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 短语最多五个词 |
| `[prediction.09]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 短语遇到句末停止 |
| `[prediction.10]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 短语遇到低频续词停止 |
| `[prediction.11]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 关闭短语联想 |
| `[prediction.12]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 组词时也给出短语 |
| `[prediction.13]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 联想时数字交给应用 |
| `[prediction.14]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 联想时输入字母开始带上下文的组词 |
| `[prediction.15]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | Esc 收起联想 |
| `[prediction.16]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 其它控制键收起联想并交给应用 |
| `[prediction.17]` | unit | `Tests/GlossTypeCoreTests/PredictionTests.swift` | 没有语言模型时不联想 |
| `[prediction.18]` | integration | `Tests/GlossTypeCoreTests/LanguageModelLoadingTests.swift` | 用户自备的模型优先 |
| `[prediction.19]` | integration | `Tests/GlossTypeCoreTests/LanguageModelLoadingTests.swift` | 不认识的模型版本当作没有 |
| `[gloss.01]` | integration | `Tests/GlossTypeCoreTests/GlossTests.swift` | 候选显示释义 |
| `[gloss.02]` | integration | `Tests/GlossTypeCoreTests/GlossTests.swift` | 查释义不区分大小写 |
| `[gloss.03]` | integration | `Tests/GlossTypeCoreTests/GlossTests.swift` | 变形词还原到原形 |
| `[gloss.04]` | integration | `Tests/GlossTypeCoreTests/GlossTests.swift` | 不认识的词没有释义 |
| `[gloss.05]` | integration | `Tests/GlossTypeCoreTests/GlossTests.swift` | 过长的释义截断 |
| `[gloss.06]` | integration | `Tests/GlossTypeCoreTests/GlossTests.swift` | 关闭释义 |
| `[translation.01]` | unit | `Tests/GlossTypeCoreTests/TranslationSourceTests.swift` | 组词时翻译当前句加原样 |
| `[translation.02]` | unit | `Tests/GlossTypeCoreTests/TranslationSourceTests.swift` | 原样不是已知词时用第一个建议词 |
| `[translation.03]` | unit | `Tests/GlossTypeCoreTests/TranslationSourceTests.swift` | 用户移动过高亮时用高亮候选 |
| `[translation.04]` | unit | `Tests/GlossTypeCoreTests/TranslationSourceTests.swift` | 联想时翻译当前句 |
| `[translation.05]` | unit | `Tests/GlossTypeCoreTests/TranslationSourceTests.swift` | 句末之后翻译刚结束的一句 |
| `[translation.06]` | unit | `Tests/GlossTypeCoreTests/TranslationSourceTests.swift` | 源文本最多 300 个字符 |
| `[translation.07]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 防抖只请求最新的源文本 |
| `[translation.08]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 丢弃过期的结果 |
| `[translation.09]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 翻译过的句子直接用缓存 |
| `[translation.10]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 源文本没变不重复请求 |
| `[translation.11]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 等待时显示上一次的译文 |
| `[translation.12]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 翻译失败时提示 |
| `[translation.13]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 语言包未安装时提示去设置下载 |
| `[translation.14]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 关闭整句翻译 |
| `[translation.15]` | unit | `Tests/GlossTypeCoreTests/TranslationCoordinatorTests.swift` | 源文本为空时隐藏译文行 |
| `[translation.16]` | 手动 | — | 苹果本地翻译在输入法里可用 |
| `[translation.17]` | 手动 | — | 在设置窗下载语言包 |
| `[learning.01]` | integration | `Tests/GlossTypeCoreTests/LearningTests.swift` | 提交时记录前两个词的搭配 |
| `[learning.02]` | integration | `Tests/GlossTypeCoreTests/LearningTests.swift` | 只记录字母词 |
| `[learning.03]` | integration | `Tests/GlossTypeCoreTests/LearningTests.swift` | 关闭学习后不再记录 |
| `[learning.04]` | integration | `Tests/GlossTypeCoreTests/LearningTests.swift` | 记录在重启后保留 |
| `[learning.05]` | integration | `Tests/GlossTypeCoreTests/LearningTests.swift` | 清除学习记录 |
| `[learning.06]` | integration | `Tests/GlossTypeCoreTests/LearningTests.swift` | 用过两次的搭配排第一 |
| `[learning.07]` | integration | `Tests/GlossTypeCoreTests/LearningTests.swift` | 学会词表里没有的新词 |
| `[learning.08]` | integration | `Tests/GlossTypeCoreTests/LearningTests.swift` | 只提交过一次的生词不进候选 |
| `[panel.01]` | unit | `Tests/GlossTypeCoreTests/PanelLayoutTests.swift` | 显示在光标下方 |
| `[panel.02]` | unit | `Tests/GlossTypeCoreTests/PanelLayoutTests.swift` | 下方放不下时显示在上方 |
| `[panel.03]` | unit | `Tests/GlossTypeCoreTests/PanelLayoutTests.swift` | 左右不超出屏幕 |
| `[panel.04]` | unit | `Tests/GlossTypeCoreTests/PanelLayoutTests.swift` | 拿不到光标位置时跟随鼠标 |
| `[panel.05]` | unit | `Tests/GlossTypeCoreTests/PanelLayoutTests.swift` | 输入法失活时收起 |
| `[panel.06]` | 手动 | — | 候选窗内容 |
| `[panel.07]` | 手动 | — | 跟随浅色与深色模式 |
| `[panel.08]` | 手动 | — | 在全屏应用上方显示 |
| `[settings.01]` | unit | `Tests/GlossTypeCoreTests/PreferencesTests.swift` | 没有存过设置时用默认值 |
| `[settings.02]` | unit | `Tests/GlossTypeCoreTests/PreferencesTests.swift` | 越界的值被夹到范围内 |
| `[settings.03]` | unit | `Tests/GlossTypeCoreTests/PreferencesTests.swift` | 修改后持久保存 |
| `[settings.04]` | 手动 | — | 设置窗 |
| `[install.01]` | static / script | `scripts/tests/test_install.py` | Info.plist 带输入法必需的键 |
| `[install.02]` | static / script | `scripts/tests/test_install.py` | 控制器类名与代码一致 |
| `[install.03]` | static / script | `scripts/tests/test_install.py` | Bundle ID 含 inputmethod |
| `[install.04]` | static / script | `scripts/tests/test_install.py` | 打包脚本组装出完整的 app |
| `[install.05]` | static / script | `scripts/tests/test_install.py` | 缺词典数据时打包失败并提示 |
| `[install.06]` | 手动 | — | 安装后出现在输入源里 |
| `[install.07]` | 手动 | — | 在真实应用里打字 |
| `[dictdata.01]` | script | `scripts/tests/test_build_glossary.py` | 去掉词性取前三个义项 |
| `[dictdata.02]` | script | `scripts/tests/test_build_glossary.py` | 跳过领域标签行 |
| `[dictdata.03]` | script | `scripts/tests/test_build_glossary.py` | 义项不够时接下一行 |
| `[dictdata.04]` | script | `scripts/tests/test_build_glossary.py` | 只收单个词 |
| `[dictdata.05]` | script | `scripts/tests/test_build_glossary.py` | 按词频排名 |
| `[dictdata.06]` | script | `scripts/tests/test_build_glossary.py` | 只保留最常用的 N 个 |
| `[dictdata.07]` | script | `scripts/tests/test_build_glossary.py` | 同一个词多条时取排名高的 |
| `[dictdata.08]` | script | `scripts/tests/test_build_glossary.py` | 变形展开成独立条目 |
| `[dictdata.09]` | script | `scripts/tests/test_build_glossary.py` | 变形自带的释义不像释义时用原形的 |
| `[dictdata.10]` | script | `scripts/tests/test_build_glossary.py` | 变形没有词频时用原形的排名 |
| `[dictdata.11]` | script | `scripts/tests/test_build_glossary.py` | 记录来源与许可证 |
| `[dictdata.12]` | script | `scripts/tests/test_build_glossary.py` | 测试夹具与脚本输出一致 |
| `[lmdata.01]` | script | `scripts/tests/test_build_ngram.py` | 分词保留缩写去掉数字标点 |
| `[lmdata.02]` | script | `scripts/tests/test_build_ngram.py` | 句首句尾加标记 |
| `[lmdata.03]` | script | `scripts/tests/test_build_ngram.py` | 按最小次数剪枝 |
| `[lmdata.04]` | script | `scripts/tests/test_build_ngram.py` | 每个上下文的续词有上限 |
| `[lmdata.05]` | script | `scripts/tests/test_build_ngram.py` | 显示形式取最常见的大小写 |
| `[lmdata.06]` | script | `scripts/tests/test_build_ngram.py` | 记录阶数、语料和许可证 |
| `[lmdata.07]` | script | `scripts/tests/test_build_ngram.py` | 上下文总数等于剪枝前的续词次数之和 |
| `[lmdata.08]` | integration | `Tests/GlossTypeCoreTests/NGramLanguageModelTests.swift` | 高阶命中用相对频率 |
| `[lmdata.09]` | integration | `Tests/GlossTypeCoreTests/NGramLanguageModelTests.swift` | 未命中退一阶乘 0.4 |
| `[lmdata.10]` | script | `scripts/tests/test_build_ngram.py` | 测试夹具与脚本输出一致 |

## 手动验证

在 macOS 15+ 真机上 `make data && make app && make install` 后逐条过：

- `[translation.16]` 苹果本地翻译在输入法里可用
- `[translation.17]` 在设置窗下载语言包
- `[panel.06]` 候选窗内容
- `[panel.07]` 跟随浅色与深色模式
- `[panel.08]` 在全屏应用上方显示
- `[settings.04]` 设置窗
- `[install.06]` 安装后出现在输入源里
- `[install.07]` 在真实应用里打字

## 真实输出与回放

- 用 ECDICT 全量 `ecdict.csv` 跑一次 `build_glossary.py`，核对条目数、文件大小和 hello / went / cats / I 几个词的释义与排名。
- 语言模型语料由维护者另定；拿到语料后用 `make lm` 生成一次，核对文件大小和 how are / thank 之后的联想。
