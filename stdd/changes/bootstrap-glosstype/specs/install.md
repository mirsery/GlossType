# 规格增量：install

能力 `install`：打包、注册与安装。

## 新增

### 需求：包结构

#### 场景 [install.01] Info.plist 带输入法必需的键

- WHEN 检查 Packaging/Info.plist
- THEN 它 SHALL 含 InputMethodConnectionName、InputMethodServerControllerClass、tsInputMethodCharacterRepertoireKey、tsInputMethodIconFileKey、LSUIElement、LSMinimumSystemVersion 15.0

#### 场景 [install.02] 控制器类名与代码一致

- WHEN 检查 Info.plist 的 InputMethodServerControllerClass
- THEN 它 SHALL 等于 App 源码里输入控制器的 @objc 名

#### 场景 [install.03] Bundle ID 含 inputmethod

- WHEN 检查 Info.plist 的 CFBundleIdentifier
- THEN 它 SHALL 含 .inputmethod.

#### 场景 [install.04] 打包脚本组装出完整的 app

- GIVEN 已有可执行文件和 glossary.sqlite
- WHEN 运行打包脚本
- THEN 产物 SHALL 含 Contents/MacOS/GlossType、Contents/Info.plist、Contents/Resources 下的图标与 glossary.sqlite

#### 场景 [install.05] 缺词典数据时打包失败并提示

- GIVEN 没有 glossary.sqlite
- WHEN 运行打包脚本
- THEN 脚本 SHALL 以非零退出并提示先运行 make data

### 需求：安装

#### 场景 [install.06] 安装后出现在输入源里

- WHEN 用户运行 make install
- THEN GlossType SHALL 出现在「系统设置 → 键盘 → 输入法」里并处于启用状态
- 验证：手动——依赖系统输入源服务

#### 场景 [install.07] 在真实应用里打字

- GIVEN 已切换到 GlossType
- WHEN 用户在文本编辑里输入 hello world
- THEN 文本编辑里 SHALL 得到 hello world，候选窗跟随光标
- 验证：手动——依赖真实输入法进程
