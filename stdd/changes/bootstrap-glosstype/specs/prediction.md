# 规格增量：prediction

能力 `prediction`：提交一个词后联想下一个词和短语，以及语言模型的加载与退化。

## 新增

### 需求：下一个词

#### 场景 [prediction.01] 提交词后显示下一个词

- GIVEN 语言模型里 how are 后面最常跟 you
- WHEN 用户提交 how、are（按空格）
- THEN 候选窗 SHALL 进入联想状态，第一个联想词是 you

#### 场景 [prediction.02] 高阶上下文优先

- GIVEN 语言模型里 are you 后面常跟 ok，you 后面常跟 know
- WHEN 当前句是 how are you
- THEN 联想词里 ok SHALL 排在 know 前面

#### 场景 [prediction.03] 句首联想首字母大写

- GIVEN 语言模型里句首最常见的是 the
- WHEN 当前句为空时进入联想
- THEN 第一个联想词 SHALL 显示为 The

#### 场景 [prediction.04] 手动敲空格后也联想

- GIVEN 输入法空闲，当前句是 how are
- WHEN 用户敲空格（交给应用）
- THEN 候选窗 SHALL 显示 how are 之后的联想词

#### 场景 [prediction.05] Tab 接受联想词

- GIVEN 处于联想状态，第一个联想词是 you
- WHEN 用户按 Tab
- THEN 输入法 SHALL 插入 "you "

#### 场景 [prediction.06] 接受联想词后继续联想

- GIVEN 处于联想状态，语言模型里 are you 后面常跟 ok
- WHEN 用户按 Tab 接受 you
- THEN 候选窗 SHALL 显示 you 之后的联想词，第一个是 ok

### 需求：短语

#### 场景 [prediction.07] ⇧Tab 接受整条短语

- GIVEN 处于联想状态，短语是 you doing
- WHEN 用户按 ⇧Tab
- THEN 输入法 SHALL 插入 "you doing "

#### 场景 [prediction.08] 短语最多五个词

- GIVEN 语言模型能一直往后接
- WHEN 进入联想
- THEN 短语 SHALL 不超过 5 个词

#### 场景 [prediction.09] 短语遇到句末停止

- GIVEN 语言模型里 thanks 后面最常见的是句末
- WHEN 短语接到 thanks
- THEN 短语 SHALL 到 thanks 为止

#### 场景 [prediction.10] 短语遇到低频续词停止

- GIVEN 某个上下文下得分最高的续词只出现过 1 次
- WHEN 短语接到这个上下文
- THEN 短语 SHALL 在这里停止

#### 场景 [prediction.11] 关闭短语联想

- GIVEN 设置里关闭了短语联想
- WHEN 进入联想
- THEN 候选窗 SHALL 不显示短语

#### 场景 [prediction.12] 组词时也给出短语

- GIVEN 正在组词 tha，第一个建议词是 thank，语言模型里 thank 后面常跟 you
- WHEN 候选窗刷新
- THEN 短语 SHALL 是 thank you

### 需求：联想状态下的按键

#### 场景 [prediction.13] 联想时数字交给应用

- GIVEN 处于联想状态
- WHEN 用户按 2
- THEN 输入法 SHALL 不吞这个键

#### 场景 [prediction.14] 联想时输入字母开始带上下文的组词

- GIVEN 处于联想状态，当前句是 thank，语言模型里 thank 后面常跟 you
- WHEN 用户输入 y
- THEN 第二个候选 SHALL 是 you

#### 场景 [prediction.15] Esc 收起联想

- GIVEN 处于联想状态
- WHEN 用户按 Esc
- THEN 输入法 SHALL 吞掉这个键并收起候选窗

#### 场景 [prediction.16] 其它控制键收起联想并交给应用

- GIVEN 处于联想状态
- WHEN 用户按回车
- THEN 输入法 SHALL 收起联想并把回车交给应用

### 需求：语言模型加载

#### 场景 [prediction.17] 没有语言模型时不联想

- GIVEN 没有语言模型，也没有学习记录
- WHEN 用户提交一个词
- THEN 候选窗 SHALL 不显示联想词

#### 场景 [prediction.18] 用户自备的模型优先

- GIVEN 用户目录和 app 包里都有语言模型文件
- WHEN 输入法加载语言模型
- THEN 输入法 SHALL 使用用户目录里的那份

#### 场景 [prediction.19] 不认识的模型版本当作没有

- GIVEN 语言模型文件的格式版本是 99
- WHEN 输入法加载语言模型
- THEN 输入法 SHALL 当作没有语言模型，不崩溃
