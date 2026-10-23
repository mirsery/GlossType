# 规格增量：dictdata

能力 `dictdata`：从 ECDICT 生成释义与词频数据（`scripts/build_glossary.py`）。

## 新增

### 需求：释义压缩

#### 场景 [dictdata.01] 去掉词性取前三个义项

- GIVEN 释义是「vi. 去, 走, 达到, 运转\nvt. 以...打赌」
- WHEN 压缩释义
- THEN 结果 SHALL 是「去，走，达到」

#### 场景 [dictdata.02] 跳过领域标签行

- GIVEN 释义是「[计] 电流, 中断\npron. 我」
- WHEN 压缩释义
- THEN 结果 SHALL 是「我」

#### 场景 [dictdata.03] 义项不够时接下一行

- GIVEN 释义是「n. 猫, 恶妇\nvi. 呕吐」
- WHEN 压缩释义
- THEN 结果 SHALL 是「猫，恶妇，呕吐」

### 需求：收词与排名

#### 场景 [dictdata.04] 只收单个词

- GIVEN 词条里有 hello、ice cream、3d、-gate、don't、well-known
- WHEN 生成词典
- THEN 词典 SHALL 只收 hello、don't、well-known

#### 场景 [dictdata.05] 按词频排名

- GIVEN hello 的 frq 是 2238，help 的 frq 是 300，ahoy 只有 bnc 5000，zzz 都没有
- WHEN 生成词典
- THEN 排名 SHALL 依次是 help、hello、ahoy、zzz

#### 场景 [dictdata.06] 只保留最常用的 N 个

- GIVEN 上限设为 2
- WHEN 生成词典
- THEN 词典 SHALL 只有排名前 2 的词

#### 场景 [dictdata.07] 同一个词多条时取排名高的

- GIVEN 词条里有 I（frq 11）和 i（无词频）
- WHEN 生成词典
- THEN 词典里 i SHALL 只有一条，显示形式是 I

### 需求：变形

#### 场景 [dictdata.08] 变形展开成独立条目

- GIVEN study 的 exchange 是 s:studies/d:studied/i:studying，词条里没有 studies
- WHEN 生成词典
- THEN 词典 SHALL 有 studies，释义与 study 相同，原形记为 study

#### 场景 [dictdata.09] 变形自带的释义不像释义时用原形的

- GIVEN cats 自带释义以 abbr. 开头，exchange 标明原形是 cat
- WHEN 生成词典
- THEN cats 的释义 SHALL 与 cat 相同

#### 场景 [dictdata.10] 变形没有词频时用原形的排名

- GIVEN went 没有词频，原形 go 的排名是 35
- WHEN 生成词典
- THEN went 的排名 SHALL 是 35

### 需求：元数据与契约

#### 场景 [dictdata.11] 记录来源与许可证

- WHEN 生成词典
- THEN meta 表 SHALL 有 format=glosstype-glossary、version=1、source、license

#### 场景 [dictdata.12] 测试夹具与脚本输出一致

- GIVEN 仓库里的 Swift 测试夹具 tiny-glossary.sqlite
- WHEN 用脚本从夹具 CSV 重新生成
- THEN 两份数据的内容 SHALL 一致
