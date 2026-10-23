# STDD 开发流程（Spec + Test 双驱动）

本仓库所有行为改动都按 STDD 走：规格定义「做对的事」，测试保证「把事做对」。先把要做的行为写成 GIVEN / WHEN / THEN 场景、维护者确认，再按场景逐条 RED → GREEN → REFACTOR，最后用自动追溯检查和失败模式核查验收。

## 1. 先定级

| 级别 | 适用 | 走法 |
|---|---|---|
| `full` | 新功能；用户可见行为变化（按键语义、候选排序、窗口显示）；数据文件格式（词典 / 语言模型 / 学习记录）；Info.plist 与安装方式 | 六阶段 + 三道门（第 5 节） |
| `fix` | 缺陷修复，正确行为已有场景或显然正确 | 复现 → 补场景 → RED → 修 → 门禁 → 交付（第 6 节） |
| `none` | 文档、注释、构建脚本、测试自身的修正、不改行为的重构 | 直接改 → `make test` → 提交 |

- 开工后第一条说明写明级别；拿不准就往上一级。`fix` 做到一半发现要改既定行为，停下，升级为 `full`。
- 三道门只认维护者本人的明确确认。门的记录写进 `proposal.md` 的 front matter：`gate1: 2026-10-24 维护者确认：<原话摘要>`。仓库公开，不写消息 ID、邮箱、内部地址。

## 2. 目录

```
stdd/
  specs/<能力>/spec.md              活规格：输入法现在的行为，唯一权威
  changes/<变更>/                   进行中的变更
    proposal.md                     Phase 1，front matter 记级别、阶段、三道门
    design.md                       Phase 2
    specs/<能力>.md                 Phase 2，规格增量（新增 / 修改 / 删除）
    test-plan.md                    Phase 2
    tasks.md                        Phase 3，切片
    design-adjustments.md           Phase 4 起
    test-report.md                  Phase 5
  changes/archive/<YYYY-MM-DD>-<变更>/   已交付的变更，只读
  templates/                        以上文件的模板
```

- **能力**按使用者能感知的功能划分，名字只用小写字母（不带连字符，测试函数名要用它）：`composition`、`completion`、`prediction`、`gloss`、`translation`、`learning`、`panel`、`settings`、`install`、`dictdata`、`lmdata`。
- **变更**名 kebab-case，说清做什么：`add-phrase-prediction`、`fix-gloss-plural`。
- 规格按需生长：变更碰到哪个能力，只写本次涉及的场景。

## 3. 规格格式

```markdown
### 场景 [completion.01] 输入字母时列出原样和按词频排序的补全

- GIVEN 词表里 hello 比 help 常用
- WHEN 用户输入 hel
- THEN 候选窗 SHALL 第一个显示原样 hel，后面依次是 hello、help
```

规则（标 ✓ 的由 `scripts/stdd_check.py` 自动检查）：

- ✓ 场景标题 `### 场景 [<能力>.<序号>] <名字>`（增量文件里是 `####`），序号两到三位；ID 前缀等于能力目录名（增量里等于文件名）。ID 全库唯一，删掉的序号不复用。
- ✓ 每个场景有 `- WHEN` 行，`- THEN` 行带大写 `SHALL`。没有前置条件时 GIVEN 可省。
- 一个场景只验一件事：THEN 里出现「并且」「同时」就拆成两个场景。
- 写「做什么」，不写「怎么做」：不点类名、函数名。
- ✓ 没法自动化的场景（要真机打字、要苹果翻译、要系统设置里添加输入源）在场景下加一行 `- 验证：手动——<原因>`，追溯检查不要求它有测试，test-report 里要记手动验证结果。

增量 `stdd/changes/<变更>/specs/<能力>.md`：场景写在 `## 新增` / `## 修改` / `## 删除` 下面。修改写改后的完整场景；删除只写一行原因。

- ✓ 新增的 ID 在活规格里不能已存在，也不能和别的进行中变更重复；修改 / 删除的 ID 必须在活规格里。
- ✓ 新增 / 修改的每个场景 ID 都要出现在本变更的 `test-plan.md`。

## 4. 测试与场景的追溯

测试函数名带场景 ID，一条测试只对应一个场景，一个场景可以有多条测试：

| 语言 | 写法 | 对应场景 |
|---|---|---|
| Swift（XCTest） | `func test_completion_01_literalThenFrequency()` | `[completion.01]` |
| Python（unittest） | `def test_dictdata_03_rank_by_frequency(self):` | `[dictdata.03]` |

- 桩：Swift 测试体里写 `throw XCTSkip("stdd:todo")`，Python 写 `self.skipTest("stdd:todo")`。BUILD 开始时先给所有新增 / 修改的场景写桩。
- ✓ 测试引用的 ID 必须在活规格或进行中变更的增量里存在（防编造）。
- ✓ 覆盖：活规格里每个非手动场景都要有真实测试（桩不算）；进行中的变更在 `build` 阶段至少要有桩，`verify` / `deliver` 阶段必须有真实测试。
- 单独跑：`make stdd-check`。它也在 `make test` 里。

## 5. full 级：六个阶段

阶段写在 `proposal.md` 的 `phase:`，取值 `understand` → `spec` → `slice` → `build` → `verify` → `deliver`。✓ 追溯检查按阶段要求文件齐全、门有记录：到 `spec` 要有 `gate1`，到 `slice` 要有 `gate2`，`deliver` 或已归档要有 `gate3`。

1. **UNDERSTAND**：建 `stdd/changes/<变更>/`，写 `proposal.md`（为什么、做什么、不做什么、涉及能力、影响、成功标准）。**Gate 1**：维护者确认范围。
2. **SPEC**（最重要）：`design.md`（方案、备选与取舍、数据格式变化、兼容、风险）、`specs/<能力>.md`、`test-plan.md`（场景 → 层级 → 测试文件 → 要点）。**Gate 2**：确认方案、场景清单和测试方案。
3. **SLICE**：`tasks.md`，每个切片 = 一到几个场景 → 测试 → 实现单元，30 分钟内做得完。
4. **BUILD**：先写桩；每个切片 RED（确认失败原因是功能不存在或行为不对，不是编译错）→ GREEN → `make test` → 提交并勾掉切片。与 design 或场景不一致的调整记进 `design-adjustments.md`：Minor（实现细节）记下继续；Major（改范围、改 THEN、改用户可见行为、改数据格式）停下等维护者确认。
5. **VERIFY**：`make test` 全绿；手动场景在真机逐条过；按第 7 节核查；写 `test-report.md`。**Gate 3**：确认验收。
6. **DELIVER**：增量并进 `stdd/specs/<能力>/spec.md`，`git mv` 到 `changes/archive/<YYYY-MM-DD>-<变更>/`，`phase: deliver`，提交 `docs(stdd): 归档 <变更>`。

## 6. fix 级

复现 → 在活规格里补上或改正场景 → 写带场景 ID 的回归测试，修复前必须失败 → 修 → `make test` → 提交。

## 7. 失败模式核查（VERIFY 用）

| # | 失败模式 | 在本仓库查什么 |
|---|---|---|
| 1 | 幻觉 | 用到的 InputMethodKit / Translation / NSSpellChecker / TIS API 真实存在、签名对得上 SDK；不凭记忆写 |
| 2 | 范围蔓延 | `git diff --stat` 的每个文件都落在 `tasks.md` 的切片里 |
| 3 | 静默吞错 | 新增的 `catch` / `try?` 要么记日志，要么注释说明为什么可以忽略 |
| 4 | 上下文丢失 | 逐个场景对照 THEN 看实现；与 proposal「不做什么」、design 取舍不矛盾 |
| 5 | 工具误用 | 交付前跑的是全量 `make test`；git 不 force push |
| 6 | 运行时偏差 | 静态对、跑起来错：IMK 回调线程、候选窗在全屏 / 多屏下的位置、翻译回调乱序、输入法进程常驻后的内存 |
| 7 | 链路断档 | 新设置项要同时进默认值、设置窗、读取处；新数据文件要同时进构建脚本、打包、加载路径 |
| 8 | 内容质量 | 界面文案中文；README 与行为一致；第三方数据的许可证与署名写进 `THIRD_PARTY_NOTICES.md` |
| 9 | 指令衰减 | README / 设置窗里承诺的行为（离线、可关闭学习、可清除记录）代码里真的做到 |
| 10 | 覆盖真空 | 追溯检查通过；手动场景写明原因，test-report 里有手动验证结果 |
| 11 | 契约断层 | Info.plist 里的控制器类名与 Swift `@objc` 名一致；构建脚本产出的 SQLite 表结构与 Swift 读取代码一致 |

## 8. 门禁消息怎么写

只写要维护者拍板的东西：Gate 1 写做什么、不做什么、成功标准；Gate 2 写方案取舍、场景清单（ID + 一句话）、测试方案、风险；Gate 3 写门禁结果、场景验证结论、设计调整、遗留问题。结尾明确问「确认，还是要改哪里」。
