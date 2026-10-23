# 规格增量：lmdata

能力 `lmdata`：语言模型数据格式——从语料生成（`scripts/build_ngram.py`）与读取。

## 新增

### 需求：生成

#### 场景 [lmdata.01] 分词保留缩写去掉数字标点

- GIVEN 语料一行是 I'm at home, 2 cats & a dog!
- WHEN 分词
- THEN 结果 SHALL 是 i'm、at、home、cats、a、dog

#### 场景 [lmdata.02] 句首句尾加标记

- GIVEN 语料一行是 Hi there
- WHEN 生成 n-gram
- THEN 计数 SHALL 包含 <s> → hi 和 there → </s>

#### 场景 [lmdata.03] 按最小次数剪枝

- GIVEN 最小次数为 2，how are you 出现 2 次，how are they 出现 1 次
- WHEN 生成 n-gram
- THEN 上下文 how are 下 SHALL 只有 you

#### 场景 [lmdata.04] 每个上下文的续词有上限

- GIVEN 每个上下文最多保留 2 个续词，the 后面有 5 种续词
- WHEN 生成 n-gram
- THEN 上下文 the 下 SHALL 只保留次数最多的 2 个

#### 场景 [lmdata.05] 显示形式取最常见的大小写

- GIVEN 语料里 I 出现 5 次、i 出现 1 次
- WHEN 生成词表
- THEN i 的显示形式 SHALL 是 I

#### 场景 [lmdata.06] 记录阶数、语料和许可证

- WHEN 用 --corpus-name 和 --license 生成
- THEN meta 表 SHALL 有 format=glosstype-ngram、version=1、order、corpus、license

#### 场景 [lmdata.07] 上下文总数等于剪枝前的续词次数之和

- GIVEN how are 后面 you 2 次、they 1 次，最小次数 2
- WHEN 生成 n-gram
- THEN 上下文 how are 的总数 SHALL 是 3

### 需求：读取

#### 场景 [lmdata.08] 高阶命中用相对频率

- GIVEN how are 的总数是 4，其中 you 3 次
- WHEN 查询 how are 之后的续词
- THEN you 的得分 SHALL 是 0.75

#### 场景 [lmdata.09] 未命中退一阶乘 0.4

- GIVEN how are 下没有 we，are 的总数是 10，其中 we 2 次
- WHEN 查询 how are 之后以 w 开头的续词
- THEN we 的得分 SHALL 是 0.4 × 0.2 = 0.08

#### 场景 [lmdata.10] 测试夹具与脚本输出一致

- GIVEN 仓库里的 Swift 测试夹具 tiny-ngram.sqlite
- WHEN 用脚本从夹具语料重新生成
- THEN 两份数据的内容 SHALL 一致
