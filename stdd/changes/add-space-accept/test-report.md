# 测试报告：空格接受建议词和联想词

## 门禁

### 本机辅助验证（2026-11-25）

本机是 macOS 12.7 + Swift 5.7.2 Command Line Tools，没有 XCTest，SwiftPM 也读不了 tools-version 6.0 的 Package.swift，所以和 bootstrap 一样分开验证：

| 项目 | 做法 | 结果 |
|---|---|---|
| Core 单测 | `swiftc` 编译 `GlossTypeCore` 和全部测试，链接最小 XCTest 替身，按测试函数逐个跑 | 110 / 110 通过（改动前 97 / 97；新增 13 条） |
| RED 确认 | 先只加设置项、不写行为，跑新测试 | 8 条按预期失败（初始高亮、联想空格、持久化），失败原因是行为不存在，不是编译错误 |
| Python 测试 | `python3 -m unittest discover -s scripts/tests` | 通过 |
| STDD 追溯检查 | `python3 scripts/stdd_check.py` | 通过 |
| App 层 | 只加了设置窗里一个 `Toggle`，绑定新设置项 | 本机没有 macOS 15 SDK，未编译，以真机 `make app` 为准 |

### 真机验证（待维护者补）

- `make test`：
- `make install`：

## 场景验证

| 场景 | 验证方式 | 测试 | 结果 |
|---|---|---|---|
| `[composition.22]` 拼错时高亮落在纠错词上 | unit | `test_composition_22_misspelling_highlights_correction` | 本机替身通过 |
| `[composition.23]` 拼错时空格提交纠错词 | unit | `test_composition_23_space_commits_correction` | 本机替身通过 |
| `[composition.24]` 已知词按空格提交原样 | unit | `test_composition_24_known_word_space_commits_literal` | 本机替身通过 |
| `[composition.25]` 只有补全没有纠错时按空格提交原样 | unit | `test_composition_25_completion_only_space_commits_literal` | 本机替身通过 |
| `[composition.26]` 高亮在纠错词上时 Esc 提交原样 | unit | `test_composition_26_escape_commits_literal_when_correction_highlighted` | 本机替身通过 |
| `[composition.27]` 移动过高亮后以用户选的为准 | unit | `test_composition_27_moved_highlight_wins`<br>`test_composition_27_typing_again_recomputes_highlight` | 本机替身通过 |
| `[prediction.20]` 联想时空格接受高亮联想词 | unit | `test_prediction_20_space_accepts_highlighted_prediction` | 本机替身通过 |
| `[prediction.21]` 空格接受联想词后继续联想 | unit | `test_prediction_21_space_accept_keeps_predicting` | 本机替身通过 |
| `[prediction.22]` 没有联想词时空格交给应用 | unit | `test_prediction_22_space_passes_through_without_predictions` | 本机替身通过 |
| `[prediction.23]` 关闭时联想中按空格收起联想 | unit | `test_prediction_23_space_dismisses_when_disabled` | 本机替身通过 |
| `[settings.09]` 空格接受建议默认开启 | unit | `test_settings_09_space_accepts_suggestion_defaults_on` | 本机替身通过 |
| `[settings.10]` 空格接受建议修改后持久保存 | unit | `test_settings_10_space_accepts_suggestion_persists` | 本机替身通过 |
| `[settings.11]` 设置窗里能切换空格接受建议 | 手动 | — | 待真机 |
| `[composition.07]`（改为关闭开关时） | unit | `test_composition_07_space_commits_literal` | 本机替身通过 |

## 失败模式核查

| # | 结论 |
|---|---|
| 1 幻觉 | 没有新用到系统 API；`Toggle` 用法与同文件已有开关一致 |
| 2 范围蔓延 | 改动文件：Preferences、SuggestionEngine、InputSession、SettingsWindow、三个测试文件、README、stdd 文档，都在 tasks.md 切片里 |
| 3 静默吞错 | 没有新增 catch / try? |
| 4 上下文丢失 | 只有纠错才移高亮，补全不移（proposal「不做」）；Esc、Tab、数字语义未变 |
| 7 链路断档 | 新设置项已进默认值、持久化读写、设置窗；README 设置清单已补 |
| 10 覆盖真空 | 追溯检查通过；settings.11 为手动场景，待真机 |

## 遗留

- 真机 `make test`、`make install`，以及 settings.11 和 proposal 成功标准里的真机打字验证。
