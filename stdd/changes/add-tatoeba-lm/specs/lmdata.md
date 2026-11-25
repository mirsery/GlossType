# 规格增量：lmdata

## 新增

### 需求：Tatoeba 语料

#### 场景 [lmdata.11] 从 Tatoeba 导出里只取英文句子文本

- GIVEN Tatoeba 导出有两行：1、eng、Let's try something. 和 2、fra、Essayons.
- WHEN 读取导出生成语料
- THEN 语料 SHALL 只有一行 Let's try something.

#### 场景 [lmdata.12] Tatoeba 模型记录语料、下载日期和许可证

- GIVEN 下载日期是 2026-11-25
- WHEN 用 Tatoeba 导出生成语言模型
- THEN meta 表的 corpus SHALL 是 Tatoeba English sentences (downloaded 2026-11-25)，license 是 CC BY 2.0 FR

#### 场景 [lmdata.13] Tatoeba 模型默认 4 阶

- WHEN 不指定阶数，用 Tatoeba 导出生成语言模型
- THEN meta 表的 order SHALL 是 4
