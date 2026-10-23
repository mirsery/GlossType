# GlossType

An English input method for macOS 15+. Every candidate comes with a short Chinese gloss, the candidate panel shows a live Chinese translation of the sentence you are typing, and it predicts the next word or a whole phrase. It runs fully offline: glosses come from ECDICT, and translation uses Apple's on-device Translation framework.

macOS 15 及以上的英文输入法：

- 每个候选词下面有简短的中文释义。
- 候选窗底部实时显示正在写的这句话的中文翻译。
- 提交一个词后联想下一个词和整条短语。
- 在本地学习你的用词习惯。
- 全部离线运行：释义来自 ECDICT，翻译用苹果系统自带的本地翻译。

```
I want to say hel|
┌─────────────────────────────────────┐
│ 1 hel   2 hello   3 help   4 held   │
│         你好，喂    帮助     握住，拿着 │
│ 译 我想说你好                        │
└─────────────────────────────────────┘
```

## 安装

需要 macOS 15 及以上和 Xcode 16 及以上（Swift 6 工具链；`swift test` 要用 Xcode 自带的 XCTest）。

```sh
make data      # 下载 ECDICT，生成释义词典 Data/glossary.sqlite
make test      # 门禁：Swift 测试 + Python 测试 + STDD 追溯检查
make install   # 构建 build/GlossType.app，装到 ~/Library/Input Methods 并注册
```

装好之后：

1. 打开「系统设置 → 键盘 → 输入法 → 编辑」，添加「GlossType」。如果列表里没有，注销后重新登录一次。
2. 切到 GlossType，从菜单栏的输入法菜单打开「设置…」，下载「英文 → 简体中文」翻译语言包。没有语言包时不显示整句翻译。

卸载用 `make uninstall`。

## 按键

| 按键 | 组词时 | 联想时（刚提交完一个词） |
|---|---|---|
| 字母 | 继续组词 | 开始组下一个词 |
| 空格 | 提交原样 + 空格 | 收起联想，正常打空格 |
| `1`–`9` | 提交第 N 个候选 + 空格 | 正常打数字 |
| Tab | 提交第一个建议词 + 空格 | 接受高亮的下一个词，可以一直按下去 |
| ⇧Tab | 提交建议词和后面的短语 | 接受整条短语 |
| ← / → | 移动高亮 | 收起联想 |
| 回车 | 提交高亮的候选，不加空格 | 收起联想，正常回车 |
| Esc | 提交原样，收起候选窗 | 收起联想 |
| 退格 | 删掉组词的最后一个字母 | 收起联想，正常删除 |
| 标点 | 提交原样 + 标点 | 正常输入 |

空格永远提交你打的原样，不会悄悄改成别的词。想要建议词，按 Tab 或数字键。

## 语言模型

仓库**不带**语料，也不带训练好的语言模型。没有语言模型时，补全靠词频词表、系统拼写检查和你自己的学习记录，下一个词的联想要等学习记录积累起来才会出现。

### 生成语言模型

准备一份 UTF-8 纯文本语料，一行一段。日常会话风格的语料比新闻语料更贴近平时打字。然后运行：

```sh
make lm CORPUS=corpus.txt CORPUS_NAME="语料名称" CORPUS_LICENSE="语料许可证"
make install   # Data/ 里有 ngram.sqlite 时会一起打包
```

### 不重新打包，直接换模型

把 `ngram.sqlite` 放到 `~/Library/Application Support/GlossType/`，切换一次输入法就生效。用户目录里的模型优先于打包进 `.app` 的模型。

### 格式说明与自己实现

文件格式见 [`docs/data-formats.md`](docs/data-formats.md)。任何能产出这个格式的工具都可以用，也可以在 Swift 里实现 `LanguageModel` 协议直接接入。

## 设置

在输入法菜单里打开「设置…」，可以设置以下内容：

- 是否显示释义
- 是否显示整句翻译
- 是否开启短语联想
- 是否学习用词习惯
- 候选数量（3–9）
- 翻译延迟
- 下载翻译语言包
- 清除学习记录

学习记录保存在 `~/Library/Application Support/GlossType/user-history.sqlite`，只在本机。

## 开发

- 目录结构、约定和踩过的坑：[`AGENTS.md`](AGENTS.md)
- STDD 流程：[`docs/dev/stdd.md`](docs/dev/stdd.md)，规格与变更记录在 `stdd/`

`GlossTypeCore` 是纯逻辑，全部可以单测。`GlossTypeApp` 只做 InputMethodKit、AppKit、SwiftUI 和翻译框架的适配。

## 许可证与致谢

- 代码使用 [MIT](LICENSE) 许可证。
- 释义数据来自 [ECDICT](https://github.com/skywind3000/ECDICT)（MIT），见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
- 交互思路受 [mgxv/SwiftType](https://github.com/mgxv/SwiftType) 启发，未使用其代码。
