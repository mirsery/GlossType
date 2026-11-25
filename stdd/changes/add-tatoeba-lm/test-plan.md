# 测试方案：一条命令用 Tatoeba 语料生成语言模型

| 场景 | 层级 | 测试文件 | 要点 |
|---|---|---|---|
| `[lmdata.11]` | script | `scripts/tests/test_build_tatoeba_lm.py` | 用 bz2 夹具（含 eng、fra 各一行、缺列的坏行），断言语料只剩英文句子 |
| `[lmdata.12]` | script | `scripts/tests/test_build_tatoeba_lm.py` | 生成后读 meta 表 |
| `[lmdata.13]` | script | `scripts/tests/test_build_tatoeba_lm.py` | 不传 --order 时 meta.order=4 |
| `[install.08]` | 手动 | — | 真机 `make lm-tatoeba && make install` |
| `[install.09]` | 手动 | — | 真机备忘录打字 |

## 手动验证

macOS 15 真机：`make lm-tatoeba`、`make install`，打开设置窗看语料与许可证；备忘录里输入 I want to、see you、thank you for，各按一次空格看联想，按 ⇧Tab 看短语。

## 真实输出与回放

Tatoeba 英文导出全量（2026-11-25 下载，204 万句）。3 阶 / 4 阶的实测数据和联想样例见 design.md。
