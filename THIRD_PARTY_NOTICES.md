# 第三方声明

## ECDICT

`make data` 从 [ECDICT](https://github.com/skywind3000/ECDICT) 生成 `glossary.sqlite`（中文释义与词频排名）。生成的文件随 `make app` 打进 `GlossType.app`。

```
MIT License

Copyright (c) 2017 Linwei

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 语言模型语料

仓库不带任何语料，也不带训练好的语言模型。用 `make lm` 自备语料生成的 `ngram.sqlite` 会把语料名称和许可证写进文件的 `meta` 表，分发打包了该文件的 `.app` 时请遵守语料本身的许可证。

## 致谢

交互思路（候选窗显示释义与整句翻译、下一个词联想）受 [mgxv/SwiftType](https://github.com/mgxv/SwiftType) 启发。本仓库没有使用它的任何代码或数据。
