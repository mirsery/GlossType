# 规格增量：learning

能力 `learning`：在本地记录用户提交的词和搭配，提高常用搭配的排序。

## 新增

### 需求：记录

#### 场景 [learning.01] 提交时记录前两个词的搭配

- GIVEN 当前句是 I see
- WHEN 用户提交 them
- THEN 学习记录 SHALL 各加一次：them（无上下文）、see → them、i see → them

#### 场景 [learning.02] 只记录字母词

- WHEN 要记录的词含数字或符号（如 v2、a.b）
- THEN 学习记录 SHALL 不变

#### 场景 [learning.03] 关闭学习后不再记录

- GIVEN 设置里关闭了学习
- WHEN 用户提交 them
- THEN 学习记录 SHALL 不变

#### 场景 [learning.04] 记录在重启后保留

- GIVEN 学习记录里有 see → them
- WHEN 输入法重启后重新打开学习记录
- THEN see → them SHALL 仍在

#### 场景 [learning.05] 清除学习记录

- GIVEN 学习记录里有数据
- WHEN 用户在设置里清除学习记录
- THEN 学习记录 SHALL 为空

### 需求：影响排序

#### 场景 [learning.06] 用过两次的搭配排第一

- GIVEN 语言模型里 see 后面 you 出现 10 次、them 出现 5 次
- WHEN 用户在 see 之后提交过两次 them
- THEN see 之后的联想里 them SHALL 排第一

#### 场景 [learning.07] 学会词表里没有的新词

- GIVEN 词表和系统拼写检查都不认识 grokking
- WHEN 用户提交过两次 grokking 之后再输入 grok
- THEN 候选 SHALL 包含 grokking

#### 场景 [learning.08] 只提交过一次的生词不进候选

- GIVEN 词表和系统拼写检查都不认识 helo，用户只提交过一次 helo（打错了）
- WHEN 用户输入 hel
- THEN 候选 SHALL 不包含 helo
