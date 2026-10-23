# 规格增量：completion

能力 `completion`：组词时的候选——原样、补全、拼写纠错的来源、排序、去重、大小写和数量。

## 新增

### 需求：来源与排序

#### 场景 [completion.01] 原样排第一，补全按词频

- GIVEN 词表里 hello 比 help 常用，没有语言模型
- WHEN 用户输入 hel
- THEN 候选 SHALL 依次是 hel、hello、help

#### 场景 [completion.02] 上下文续词排在词频之前

- GIVEN 语言模型里 thank 后面常跟 you，词表里 your 比 you 常用
- WHEN 用户提交 thank 后输入 yo
- THEN 候选里 you SHALL 排在 your 前面

#### 场景 [completion.03] 原样不是已知词时纠错排最前

- GIVEN teh 不在词表里，系统拼写检查也不认识，纠错结果是 the
- WHEN 用户输入 teh
- THEN 第二个候选 SHALL 是 the

#### 场景 [completion.04] 原样是已知词时不放纠错

- GIVEN hello 在词表里，系统拼写检查对它给出的猜测是 hallo
- WHEN 用户输入 hello
- THEN 候选 SHALL 不包含 hallo

#### 场景 [completion.05] 系统拼写补全补位

- GIVEN 词表和语言模型里都没有以 zy 开头的词，系统拼写检查给出 zygote
- WHEN 用户输入 zy
- THEN 候选 SHALL 包含 zygote

#### 场景 [completion.12] 原形也匹配时不列出变形

- GIVEN 词表里有 help 和它的变形 helped、helping、helps（排名与 help 相同），还有排名靠后的 hello
- WHEN 用户输入 hel
- THEN 候选 SHALL 包含 help 和 hello，不包含 helped、helping、helps

#### 场景 [completion.13] 原形不匹配时照常列出变形

- GIVEN 词表里有 help 的变形 helping
- WHEN 用户输入 helpi
- THEN 候选 SHALL 包含 helping

### 需求：去重、大小写与数量

#### 场景 [completion.06] 不同来源的同一个词只出现一次

- GIVEN 语言模型和词表都给出 hello
- WHEN 用户输入 hel
- THEN hello SHALL 在候选里只出现一次

#### 场景 [completion.07] 原样不重复出现

- GIVEN 词表里有 hello
- WHEN 用户输入 hello
- THEN hello SHALL 只作为第一个候选出现

#### 场景 [completion.08] 首字母大写跟随输入

- GIVEN 词表里有 hello
- WHEN 用户输入 Hel
- THEN 建议词 SHALL 显示为 Hello

#### 场景 [completion.09] 全大写跟随输入

- GIVEN 词表里有 hello
- WHEN 用户输入 HEL
- THEN 建议词 SHALL 显示为 HELLO

#### 场景 [completion.10] 专有名词保留自身大小写

- GIVEN 词表里 london 的显示形式是 London
- WHEN 用户输入 lon
- THEN 建议词 SHALL 显示为 London

#### 场景 [completion.11] 候选数量受设置限制

- GIVEN 候选数量设为 3，词表里有很多以 a 开头的词
- WHEN 用户输入 a
- THEN 候选 SHALL 恰好 3 个（含原样）
