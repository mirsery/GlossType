# 规格增量：prediction

## 新增

### 需求：空格接受联想词

#### 场景 [prediction.20] 联想时空格接受高亮联想词

- GIVEN 开启空格接受建议，处于联想状态，高亮的联想词是 you
- WHEN 用户按空格
- THEN 输入法 SHALL 插入 "you "

#### 场景 [prediction.21] 空格接受联想词后继续联想

- GIVEN 开启空格接受建议，处于联想状态，语言模型里 are you 后面常跟 ok
- WHEN 用户按空格接受 you
- THEN 候选窗 SHALL 显示 you 之后的联想词，第一个是 ok

#### 场景 [prediction.22] 没有联想词时空格交给应用

- GIVEN 开启空格接受建议，处于联想状态但没有联想词（只显示译文）
- WHEN 用户按空格
- THEN 输入法 SHALL 把空格交给应用

#### 场景 [prediction.23] 关闭时联想中按空格收起联想

- GIVEN 关闭空格接受建议，处于联想状态
- WHEN 用户按空格
- THEN 输入法 SHALL 收起联想并把空格交给应用
