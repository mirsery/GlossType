# 测试报告：一条命令用 Tatoeba 语料生成语言模型

## 门禁

### 本机辅助验证（2026-11-25）

| 项目 | 做法 | 结果 |
|---|---|---|
| Python 测试 | `python3 -m unittest discover -s scripts/tests` | 通过（新增 4 条） |
| 变异检查 | 把默认阶数改成 3、去掉语言过滤、清空许可证，再跑新测试 | 4 条全部失败，恢复后全部通过 |
| STDD 追溯检查 | `python3 scripts/stdd_check.py` | 通过 |
| Core 单测 | XCTest 替身（本变更不改 Swift 代码） | 97 / 97 通过 |
| `make lm-tatoeba` 全流程 | 本机真实运行（导出已在 `Data/downloads/`，跳过下载） | 退出码 0；5 分 34 秒；峰值内存 2.9 GB；`Data/ngram.sqlite` 89 MB，词表 8.1 万、上下文 113 万、n-gram 263 万、句子 210 万 |
| 真模型接 Core | 用 `NGramLanguageModel` 加载生成的模型，驱动 `InputSession` 打字 | 见下表 |

真模型接 `InputSession`（x86 Mac，macOS 12；「每键」含该句全部按键的平均耗时）：

| 输入后按空格 | 联想（前 5） | ⇧Tab 短语 | 平均每键 |
|---|---|---|---|
| I want to | know, be, go, do, see | know what happened | 13.7 ms（含首次查询的冷启动） |
| see you | in, at, tomorrow, next, on | in a few minutes | 5.2 ms |
| thank you for | your, the, coming, helping, a | your help | 3.9 ms |
| how are | you, we, things, Tom, your | you going to do that | 4.2 ms |
| could you please | tell, help, give, turn, speak | tell me what you want | 4.1 ms |

meta：`order=4`，`corpus=Tatoeba English sentences (downloaded 2026-11-25)`，`license=CC BY 2.0 FR`。

### 真机验证（待维护者补）

- `make lm-tatoeba`（含下载）：
- `make install` 后设置窗显示的语料与许可证：
- 备忘录里打字的联想与短语：

## 场景验证

| 场景 | 验证方式 | 测试 | 结果 |
|---|---|---|---|
| `[lmdata.11]` 从 Tatoeba 导出里只取英文句子文本 | script | `test_lmdata_11_only_english_sentence_text`<br>`test_lmdata_11_malformed_rows_skipped` | 通过 |
| `[lmdata.12]` Tatoeba 模型记录语料、下载日期和许可证 | script | `test_lmdata_12_meta_records_corpus_date_and_license` | 通过 |
| `[lmdata.13]` Tatoeba 模型默认 4 阶 | script | `test_lmdata_13_default_order_is_four` | 通过 |
| `[install.08]` 一条命令下载语料并生成语言模型 | 手动 | — | 本机生成部分通过（见上）；下载步骤在 2026-11-25 用同一 URL 手动验证过（200，24.9 MB）；`make install` 与设置窗待真机 |
| `[install.09]` 装了 Tatoeba 模型后联想出多词短语 | 手动 | — | 本机用 Core 驱动等价验证通过（见上表）；真机输入法里打字待验证 |

## 失败模式核查

| # | 结论 |
|---|---|
| 2 范围蔓延 | 改动：新脚本及测试、Makefile、README、AGENTS.md、THIRD_PARTY_NOTICES、stdd 文档，都在 tasks.md 里；没改 Swift |
| 3 静默吞错 | 解码用 `errors="replace"`，与 `build_ngram.py` 读语料一致；坏行跳过已记入 design-adjustments |
| 7 链路断档 | 新数据文件沿用已有路径：`Data/ngram.sqlite` → `package_app.sh` 打包 → `ResourceLocator` 加载，本变更未改这条链 |
| 8 内容质量 | THIRD_PARTY_NOTICES 补了 Tatoeba 署名、许可证链接，说明仓库不含句子和模型 |
| 11 契约断层 | 输出由 `build_ngram.build()` 写，表结构不变；Swift `NGramLanguageModel` 已实际加载生成的 4 阶模型 |

## 遗留

- 真机 `make install` 与打字验证后过 Gate 3。
- Tom、Mary 偏多：proposal 已列为「不做」，观察使用后再定是否降权。
