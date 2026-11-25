---
tier: full
phase: spec
gate1: 2026-11-25 维护者确认：先提 issue，再做「空格接受建议」和「补上语言模型」两项
gate2:
gate3:
---

# 一条命令用 Tatoeba 语料生成语言模型

关联 issue：#1

## 为什么

仓库不带语料和语言模型，`make install` 只打包词典。没有 `ngram.sqlite` 时，下一个词联想和短语只能来自学习记录，新装时基本为空，维护者实际用下来「不会智能提示句子」。`make lm` 要使用者自己找语料、核对许可证，门槛高。

## 做什么

- 新增 `make lm-tatoeba`：下载 Tatoeba 英文句子导出（日常会话风格，CC BY 2.0 FR），取出句子文本，生成 4 阶语言模型到 `Data/ngram.sqlite`；之后 `make install` 照常把它打包进 `.app`。
- 模型元数据写明语料名称、下载日期和许可证，设置窗照现有逻辑显示。
- `THIRD_PARTY_NOTICES.md` 补 Tatoeba 的署名和许可证；README 的「语言模型」一节改成先推荐这条命令。

## 不做什么

- 仍不把语料和模型提交进仓库（Tatoeba 导出每周更新、没有固定版本，模型 89 MB）。
- 不改语言模型文件格式和 Swift 侧的读取、打分逻辑。
- 不做神经网络 / 大模型的整句补全。
- 不处理 Tatoeba 例句里人名 Tom、Mary 偏多的问题（见 design 风险）。

## 涉及的能力

- 修改：`lmdata`（Tatoeba 导出的读取与元数据）、`install`（新的构建命令）

## 影响

- 新增 `scripts/build_tatoeba_lm.py` 及其测试；Makefile 新目标；README、THIRD_PARTY_NOTICES。
- 生成一次约 5 分钟、峰值内存约 2.9 GB（本机实测，见 design）。
- 不改 Info.plist，不改 Swift 代码。

## 成功标准

- `make lm-tatoeba && make install` 之后，设置窗显示语料「Tatoeba」和许可证；提交 how are 后联想出 you，⇧Tab 能接受多词短语。
- `make test` 全绿。
