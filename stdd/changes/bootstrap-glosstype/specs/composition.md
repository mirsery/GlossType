# 规格增量：composition

能力 `composition`：字母组词与按键语义。组词内容以标记文本显示在光标处，按键决定提交什么、是否交还给应用。

## 新增

### 需求：字母组词

#### 场景 [composition.01] 字母组成标记文本

- GIVEN 输入法空闲
- WHEN 用户依次输入 h、e
- THEN 输入法 SHALL 吞掉按键，把标记文本设为 he

#### 场景 [composition.02] Shift 加字母按大写组词

- GIVEN 输入法空闲
- WHEN 用户按 Shift+h
- THEN 输入法 SHALL 把标记文本设为 H

#### 场景 [composition.03] 词中间的撇号继续组词

- GIVEN 正在组词 don
- WHEN 用户输入 '
- THEN 标记文本 SHALL 变为 don'

#### 场景 [composition.04] 词首的撇号交还给应用

- GIVEN 输入法空闲
- WHEN 用户输入 '
- THEN 输入法 SHALL 不吞这个键

#### 场景 [composition.05] 退格删组词末尾字符

- GIVEN 正在组词 hel
- WHEN 用户按退格
- THEN 标记文本 SHALL 变为 he

#### 场景 [composition.06] 退格删空后收起

- GIVEN 正在组词 h
- WHEN 用户按退格
- THEN 输入法 SHALL 清掉标记文本并收起候选窗

### 需求：提交

#### 场景 [composition.07] 空格提交原样

- GIVEN 正在组词 helo，建议词里有 hello
- WHEN 用户按空格
- THEN 输入法 SHALL 插入 "helo "

#### 场景 [composition.08] 空格提交移动过的高亮候选

- GIVEN 正在组词 hel，用户按 → 把高亮移到第二个候选
- WHEN 用户按空格
- THEN 输入法 SHALL 插入第二个候选加一个空格

#### 场景 [composition.09] 数字提交第 N 个候选

- GIVEN 正在组词 hel，第二个候选是 hello
- WHEN 用户按 2
- THEN 输入法 SHALL 插入 "hello "

#### 场景 [composition.10] 数字超出候选数时提交原样加数字

- GIVEN 正在组词 xq，只有 1 个候选
- WHEN 用户按 7
- THEN 输入法 SHALL 插入 "xq7"

#### 场景 [composition.11] Tab 提交第一个建议词

- GIVEN 正在组词 hel，第一个建议词是 hello
- WHEN 用户按 Tab
- THEN 输入法 SHALL 插入 "hello "

#### 场景 [composition.12] 没有建议词时 Tab 提交原样

- GIVEN 正在组词 xq，没有建议词
- WHEN 用户按 Tab
- THEN 输入法 SHALL 插入 "xq "

#### 场景 [composition.13] 左右方向键循环移动高亮

- GIVEN 正在组词，有 3 个候选，高亮在第一个
- WHEN 用户按 ←
- THEN 高亮 SHALL 移到第三个候选

#### 场景 [composition.14] 回车只确认组词

- GIVEN 正在组词 hel
- WHEN 用户按回车
- THEN 输入法 SHALL 插入 hel、不加空格，回车不交给应用

#### 场景 [composition.15] Esc 提交原样并收起

- GIVEN 正在组词 hel
- WHEN 用户按 Esc
- THEN 输入法 SHALL 插入 hel 并收起候选窗

#### 场景 [composition.16] 标点提交原样加标点

- GIVEN 正在组词 hello
- WHEN 用户输入 ,
- THEN 输入法 SHALL 插入 "hello,"

#### 场景 [composition.17] 修饰键组合提交原样后交给应用

- GIVEN 正在组词 hel
- WHEN 用户按 ⌘A
- THEN 输入法 SHALL 先插入 hel，再把这个键交给应用

#### 场景 [composition.18] 上下方向键提交原样后交给应用

- GIVEN 正在组词 hel
- WHEN 用户按 ↓
- THEN 输入法 SHALL 先插入 hel，再把这个键交给应用

#### 场景 [composition.19] 失焦时提交原样

- GIVEN 正在组词 hel
- WHEN 系统要求输入法提交（用户切到别的应用或点了别处）
- THEN 输入法 SHALL 插入 hel

### 需求：空闲与按键映射

#### 场景 [composition.20] 空闲时非字母键交还给应用

- GIVEN 输入法空闲，候选窗没开
- WHEN 用户输入 5
- THEN 输入法 SHALL 不吞这个键

#### 场景 [composition.21] 系统按键映射成输入法按键

- WHEN 系统送来回车（36、小键盘 76）、Tab（48，带 Shift 为 ⇧Tab）、空格（49）、退格（51）、Esc（53）、方向键（123–126）或其它带字符的键
- THEN 输入法 SHALL 把它们识别成对应的按键，带 ⌘ / ⌃ / ⌥ 的识别为修饰键组合
