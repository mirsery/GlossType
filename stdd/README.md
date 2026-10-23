# stdd/

STDD（Spec + Test 双驱动）的规格与变更记录。流程、格式和规则见 [`docs/dev/stdd.md`](../docs/dev/stdd.md)。

| 目录 | 内容 |
|---|---|
| `specs/<能力>/spec.md` | 活规格：输入法现在的行为，唯一权威 |
| `changes/<变更>/` | 进行中的变更：proposal、design、规格增量、test-plan、tasks、design-adjustments、test-report |
| `changes/archive/<YYYY-MM-DD>-<变更>/` | 已交付的变更，只读 |
| `templates/` | 各阶段文件的模板，到哪个阶段复制哪份 |

规则由 `scripts/stdd_check.py` 检查（`make stdd-check`），也在 `make test` 里。
