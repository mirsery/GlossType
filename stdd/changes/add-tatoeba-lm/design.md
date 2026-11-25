# 设计：一条命令用 Tatoeba 语料生成语言模型

## 方案

- 语料：`https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2`，每行 `id<TAB>eng<TAB>句子`。2026-11-25 下载：24.9 MB 压缩包，204 万句。
- `scripts/build_tatoeba_lm.py --export <tsv.bz2> --output Data/ngram.sqlite [--downloaded YYYY-MM-DD] [--order 4]`：流式解压，只取语言列为 eng 的第三列写成临时语料，再调用 `build_ngram.build()`。语料名写成 `Tatoeba English sentences (downloaded YYYY-MM-DD)`，许可证写 `CC BY 2.0 FR`。
- Makefile：`lm-tatoeba` 下载到 `Data/downloads/`（已有就不重复下载，`make lm-tatoeba-refresh` 删掉重下），再跑上面的脚本。

## 阶数：3 还是 4（本机实测，Tatoeba 全量）

| | 3 阶 | 4 阶 |
|---|---|---|
| 生成耗时 | 3.4 分钟 | 4.9 分钟 |
| 峰值内存 | 1.0 GB | 2.9 GB |
| 文件大小 | 37 MB | 89 MB |
| 上下文 / n-gram 行数 | 41 万 / 131 万 | 113 万 / 263 万 |

同一组输入的联想（前 5 个）和 ⇧Tab 短语：

| 已输入 | 3 阶 | 4 阶 |
|---|---|---|
| i want to | do, go, be, know, see ｜ do that | know, be, go, do, see ｜ know what happened |
| see you | again, in, at, tomorrow, next ｜ 无 | in, at, tomorrow, next, on ｜ in a few minutes |
| thank you for | your, a, the, all, this ｜ your help | your, the, coming, helping, all ｜ your help |
| i don't know | what, how, why, if, where ｜ what to do that | 同左 ｜ what to do |
| how are | you, we, things, Tom, your ｜ you going to be a | 同左 ｜ you going to do that |

4 阶短语明显更通顺；文件和内存的代价在桌面机上可以接受，选 4 阶。输入法查询走 SQLite 索引，模型大小对按键延迟影响很小，真机上再确认。

## 备选与取舍

| 方案 | 好处 | 代价 | 结论 |
|---|---|---|---|
| Tatoeba（本方案） | 日常会话短句，许可证明确，可再分发 | 人名 Tom / Mary 偏多；书面长句少 | 采用 |
| OpenSubtitles | 口语更自然 | 许可证不清，不能放心再分发 | 不采用 |
| 维基百科 | 量大、许可证明确（CC BY-SA） | 书面百科腔，和打字场景不符；体积大 | 不采用 |
| 把生成好的模型放进 GitHub Release | 使用者不用自己生成 | 每次都要维护者手动发版；CC BY 署名要跟着走 | 以后再议 |

## 数据 / 配置 / 协议变化

语言模型文件格式不变（`format=glosstype-ngram`、`version=1`），只是元数据里的 corpus / license 取固定值。

## 兼容与迁移

用户目录里已有 `ngram.sqlite` 的照旧优先；`make lm` 自备语料的用法不变。

## 风险与回滚

- Tatoeba 导出没有版本号，每次下载内容略有不同：元数据记下载日期，可追溯。
- 例句里 Tom、Mary 很多，联想会冒出这两个名字；学习记录积累后用户自己的用词会排到前面。需要时下一步可以在生成时把这两个名字降权。
- 下载地址变了或网络不通：`make lm-tatoeba` 失败并提示，不影响 `make install`（没有模型就退回学习记录，和现在一样）。
- 回滚：删掉 `Data/ngram.sqlite` 重新 `make install`。

## 要更新的约定

README「语言模型」一节；THIRD_PARTY_NOTICES；AGENTS.md 常用命令表加 `make lm-tatoeba`。
