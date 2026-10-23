# 规格增量：gloss

能力 `gloss`：候选词下方的简短中文释义。

## 新增

### 需求：查释义

#### 场景 [gloss.01] 候选显示释义

- GIVEN 词典里 hello 的释义是「喂，嘿」
- WHEN 候选里有 hello
- THEN 这个候选的释义 SHALL 是「喂，嘿」

#### 场景 [gloss.02] 查释义不区分大小写

- GIVEN 词典里有 hello
- WHEN 候选是 Hello
- THEN 释义 SHALL 与 hello 相同

#### 场景 [gloss.03] 变形词还原到原形

- GIVEN 词典里只有 study、cat、run、stop
- WHEN 候选是 studies、studied、cats、running、stopped
- THEN 释义 SHALL 分别取 study、study、cat、run、stop 的释义

#### 场景 [gloss.04] 不认识的词没有释义

- GIVEN 词典里没有 xq
- WHEN 候选是 xq
- THEN 这个候选 SHALL 不带释义

#### 场景 [gloss.05] 过长的释义截断

- GIVEN 某个词的释义有 15 个字
- WHEN 显示这个词的释义
- THEN 输入法 SHALL 显示前 10 个字加「…」

#### 场景 [gloss.06] 关闭释义

- GIVEN 设置里关闭了释义
- WHEN 用户输入 hel
- THEN 候选 SHALL 都不带释义
