# 规格增量：translation

能力 `translation`：候选窗底部的整句中文翻译——翻译什么、什么时候翻、结果怎么显示。

## 新增

### 需求：翻译源文本

#### 场景 [translation.01] 组词时翻译当前句加原样

- GIVEN 当前句是 I like，正在组词 cat，cat 是已知词
- WHEN 计算翻译源文本
- THEN 源文本 SHALL 是 I like cat

#### 场景 [translation.02] 原样不是已知词时用第一个建议词

- GIVEN 当前句是 I like，正在组词 ca，ca 不是已知词，第一个建议词是 cat
- WHEN 计算翻译源文本
- THEN 源文本 SHALL 是 I like cat

#### 场景 [translation.03] 用户移动过高亮时用高亮候选

- GIVEN 当前句是 I like，正在组词 ca，用户把高亮移到了 car
- WHEN 计算翻译源文本
- THEN 源文本 SHALL 是 I like car

#### 场景 [translation.04] 联想时翻译当前句

- GIVEN 当前句是 I like cats，处于联想状态
- WHEN 计算翻译源文本
- THEN 源文本 SHALL 是 I like cats

#### 场景 [translation.05] 句末之后翻译刚结束的一句

- GIVEN 用户刚输入完 I like cats.
- WHEN 计算翻译源文本
- THEN 源文本 SHALL 是 I like cats.

#### 场景 [translation.06] 源文本最多 300 个字符

- GIVEN 当前句有 500 个字符
- WHEN 计算翻译源文本
- THEN 源文本 SHALL 是最后 300 个字符

### 需求：调度

#### 场景 [translation.07] 防抖只请求最新的源文本

- GIVEN 翻译延迟是 300ms
- WHEN 源文本在 300ms 内依次变成 I、I like、I like cats
- THEN 输入法 SHALL 只请求翻译一次，内容是 I like cats

#### 场景 [translation.08] 丢弃过期的结果

- GIVEN 已经请求翻译 I like，结果还没回来
- WHEN 源文本变成 I like cats 后，I like 的结果才回来
- THEN 输入法 SHALL 不显示 I like 的结果

#### 场景 [translation.09] 翻译过的句子直接用缓存

- GIVEN I like cats 已经翻译过
- WHEN 源文本再次变成 I like cats
- THEN 输入法 SHALL 立即显示缓存的译文，不再请求

#### 场景 [translation.10] 源文本没变不重复请求

- GIVEN 已经请求过 I like
- WHEN 源文本仍是 I like（例如只移动了高亮又移回来）
- THEN 输入法 SHALL 不发起新的请求

### 需求：显示

#### 场景 [translation.11] 等待时显示上一次的译文

- GIVEN 上一次显示的译文是「我喜欢」
- WHEN 源文本变化、新的结果还没回来
- THEN 译文行 SHALL 显示「我喜欢」并标为等待中

#### 场景 [translation.12] 翻译失败时提示

- GIVEN 翻译接口返回错误
- WHEN 结果回来
- THEN 译文行 SHALL 显示「翻译失败」

#### 场景 [translation.13] 语言包未安装时提示去设置下载

- GIVEN 系统没有安装英文到简体中文的翻译语言包
- WHEN 源文本变化
- THEN 译文行 SHALL 显示「未下载英→中语言包，可在设置中下载」，不发起翻译

#### 场景 [translation.14] 关闭整句翻译

- GIVEN 设置里关闭了整句翻译
- WHEN 源文本变化
- THEN 输入法 SHALL 不请求翻译，也不显示译文行

#### 场景 [translation.15] 源文本为空时隐藏译文行

- GIVEN 正在显示译文
- WHEN 源文本变为空
- THEN 译文行 SHALL 隐藏

### 需求：系统翻译

#### 场景 [translation.16] 苹果本地翻译在输入法里可用

- GIVEN macOS 15+，已安装英→简中语言包
- WHEN 用户在文本编辑里输入 I would like a cup of coffee
- THEN 候选窗底部 SHALL 在停顿后显示对应的中文译文
- 验证：手动——依赖系统翻译服务和真实输入法进程

#### 场景 [translation.17] 在设置窗下载语言包

- GIVEN 未安装英→简中语言包
- WHEN 用户在设置窗点「下载语言包」
- THEN 系统 SHALL 弹出语言包下载确认，下载后设置窗显示「已安装」
- 验证：手动——依赖系统下载界面
