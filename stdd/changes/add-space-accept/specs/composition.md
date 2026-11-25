# 规格增量：composition

## 新增

### 需求：空格接受建议

#### 场景 [composition.22] 拼错时高亮落在纠错词上

- GIVEN 开启空格接受建议，拼写检查把 helo 纠正为 hello
- WHEN 用户输入 helo
- THEN 候选窗 SHALL 把高亮放在 hello 上

#### 场景 [composition.23] 拼错时空格提交纠错词

- GIVEN 开启空格接受建议，拼写检查把 helo 纠正为 hello
- WHEN 用户输入 helo 后按空格
- THEN 输入法 SHALL 插入 "hello "

#### 场景 [composition.24] 已知词按空格提交原样

- GIVEN 开启空格接受建议，help 是已知词，候选里还有 helpful
- WHEN 用户输入 help 后按空格
- THEN 输入法 SHALL 插入 "help "

#### 场景 [composition.25] 只有补全没有纠错时按空格提交原样

- GIVEN 开启空格接受建议，tomo 不是已知词，拼写检查没有纠错，候选里有补全 tomorrow
- WHEN 用户输入 tomo 后按空格
- THEN 输入法 SHALL 插入 "tomo "

#### 场景 [composition.26] 高亮在纠错词上时 Esc 提交原样

- GIVEN 开启空格接受建议，正在组词 helo，高亮在 hello 上
- WHEN 用户按 Esc
- THEN 输入法 SHALL 插入 "helo"

#### 场景 [composition.27] 移动过高亮后以用户选的为准

- GIVEN 开启空格接受建议，正在组词 helo，高亮在 hello 上
- WHEN 用户按 ← 把高亮移回 helo 再按空格
- THEN 输入法 SHALL 插入 "helo "
