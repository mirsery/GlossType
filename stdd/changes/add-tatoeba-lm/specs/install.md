# 规格增量：install

## 新增

### 需求：现成的语言模型

#### 场景 [install.08] 一条命令下载语料并生成语言模型

- GIVEN 仓库里没有 Data/ngram.sqlite
- WHEN 维护者运行 make lm-tatoeba
- THEN SHALL 下载 Tatoeba 英文句子并生成 Data/ngram.sqlite，再 make install 后设置窗显示语料 Tatoeba 和许可证 CC BY 2.0 FR
- 验证：手动——要联网下载约 25 MB，生成约 5 分钟

#### 场景 [install.09] 装了 Tatoeba 模型后联想出多词短语

- GIVEN 装了 make lm-tatoeba 生成的模型
- WHEN 在备忘录里输入 I want to 并按空格
- THEN 候选窗 SHALL 显示联想词，并有 ⇧Tab 可接受的多词短语
- 验证：手动——要在真机输入法里打字
