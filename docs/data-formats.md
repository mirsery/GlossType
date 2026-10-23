# 数据格式

GlossType 读三份 SQLite 文件，每份都有一张 `meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)` 表，`format` 和 `version` 两个键用来校验：格式不对的文件当作不存在。

| 文件 | `format` | 生成方式 | 是否必需 |
|---|---|---|---|
| `glossary.sqlite` | `glosstype-glossary` | `make data`（ECDICT） | 必需：候选词表与释义 |
| `ngram.sqlite` | `glosstype-ngram` | `make lm`（自备语料） | 可选：没有时只靠学习记录和词表 |
| `user-history.sqlite` | `glosstype-user-history` | 输入法运行时写入 | 自动创建 |

## 查找顺序

`glossary.sqlite` 和 `ngram.sqlite` 先找用户目录 `~/Library/Application Support/GlossType/`，再找 `GlossType.app/Contents/Resources/`。想换语言模型时把新的 `ngram.sqlite` 放进用户目录，再切换一次输入法（或 `killall GlossType`）即可，不用重新打包。

`user-history.sqlite` 只放在用户目录下。

## 公共约定

- **词键**：小写，弯撇号 `’` 统一成 `'`。查询都用词键。
- **显示形式**（`display`）：词通常的写法，例如 `iPhone`、`NASA`、`I'm`。候选按显示形式上屏，句首或用户按了 Shift 时再按规则改大小写。
- **句子标记**：`<s>` 表示句首，只出现在上下文里；`</s>` 表示句尾，只出现在续词里，永远不作为候选。

## glossary.sqlite（version 1）

```sql
CREATE TABLE entry(
    word TEXT PRIMARY KEY,   -- 词键
    display TEXT NOT NULL,   -- 显示形式
    gloss TEXT NOT NULL,     -- 简短释义，最多 3 个义项，用「，」连接
    lemma TEXT,              -- 变形条目指向的原形词键；原形本身为 NULL
    rank INTEGER NOT NULL    -- 词频排名，越小越常用
) WITHOUT ROWID;
CREATE INDEX entry_rank ON entry(rank);
```

`meta` 还包含 `source`、`license`、`entries`。

**用途**
- 补全按 `rank` 排序，同一排名再按 `word` 排序。
- 判断一个词是否「认识」：词表里有，或者系统拼写检查认为拼写正确。
- 查释义：先用词键查；查不到时按简单的词形还原规则（`-ies`、`-es`、`-s`、`-ied`、`-ed`、`-ing`）再试。

**生成规则**（`scripts/build_glossary.py`）
- 只收单个英文词，不收词组。
- 排名先看 ECDICT 的 `frq`，再看 `bnc`，两者都没有的排在最后。
- 保留前 `--max-words` 个原形，默认 60000。
- 收录词的过去式、分词、复数、比较级等变形展开成独立条目：`lemma` 指向原形，释义沿用原形的。

## ngram.sqlite（version 1）

```sql
CREATE TABLE vocab(
    id INTEGER PRIMARY KEY,
    word TEXT NOT NULL UNIQUE,   -- 词键，或 "</s>"
    display TEXT NOT NULL,
    count INTEGER NOT NULL       -- 一元计数
);
CREATE TABLE context(
    id INTEGER PRIMARY KEY,
    words TEXT NOT NULL UNIQUE,  -- 前文词键，空格分隔，可能以 "<s>" 开头；'' 表示空上下文
    total INTEGER NOT NULL       -- 这个上下文后面所有续词的计数之和（剪枝前）
);
CREATE TABLE ngram(
    context_id INTEGER NOT NULL,
    word_id INTEGER NOT NULL,
    count INTEGER NOT NULL,
    PRIMARY KEY(context_id, word_id)
) WITHOUT ROWID;
```

`meta` 必须有 `order`（最高阶数，≥ 2）。另外还包含 `corpus`、`license`、`min_count`、`top_k`、`sentences`、`tokens`。

**打分**：stupid backoff。
- 先用最长的上下文查，没有命中就去掉最前面的一个词再查。
- 每退一阶，分数乘以 0.4。
- 退到一阶时，用 `vocab.count / context('').total` 作为分数。
- 同一个词取最高阶的那次命中。只有一阶命中的词不作为「下一个词」联想。

**生成规则**（`scripts/build_ngram.py`）
- 语料是 UTF-8 纯文本，一行一段，行内按 `. ! ?` 切句。
- 词的正则是 `[A-Za-z]+('[A-Za-z]+)*`。
- 显示形式取非句首位置上最常见的写法。
- 二阶及以上的 n-gram 只保留出现次数 ≥ `--min-count` 的，每个上下文最多保留 `--top-k` 个续词。

**换语料**
- 任何能产出上述三张表的工具都可以用，不限于本仓库的脚本。
- 也可以不用 SQLite，在 Swift 里实现 `LanguageModel` 协议接入。
- 分发打包了 `ngram.sqlite` 的 `.app` 时，遵守语料本身的许可证。

## user-history.sqlite（version 1）

```sql
CREATE TABLE history(
    context TEXT NOT NULL,   -- 前文词键，0～2 个词，空格分隔，可能以 "<s>" 开头；'' 是一元
    word TEXT NOT NULL,      -- 词键
    display TEXT NOT NULL,   -- 最近一次的显示形式
    count INTEGER NOT NULL,
    PRIMARY KEY(context, word)
) WITHOUT ROWID;
```

**写入时机**：用空格、Tab、⇧Tab、数字键选词、回车或干净的标点（`.,!?;:)]}"”`）结束一个词时，记一次。

**写入内容**：同一次记录会同时写空上下文、一个词的上下文、两个词的上下文三行。

**显示形式**
- `I` 和 `I'…` 一律记成大写。
- 全大写的词（两个字母以上）记成小写。
- 因为在句首而首字母大写的词，记成小写。
- 其他情况保留原样。

**不记录的情况**
- 按 Esc、方向键、快捷键或失去焦点时，组到一半的词不记。
- 后面紧跟数字、`_`、`-` 等字符的词不记。
- 设置里关掉「记录我的用词习惯」后不再记录。
- 「清除学习记录」会清空 `history` 表。

**参与排序**
- 学习记录是一个独立的语言模型，打分同样用 stupid backoff。
- 它的分数以权重 1.0 加到 `ngram.sqlite` 的分数上。
- 一个不在词表里、拼写检查也不认识的词，累计提交两次后才会出现在候选里。
