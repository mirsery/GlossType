# 测试报告：从零实现 GlossType 输入法

> 本报告分两部分：本机（维护者以外的机器）能做的验证已经做完，结果如下；`make test`、`make app` 和 8 条手动场景要在 macOS 15+ 真机上跑，跑完补到「真机验证」一节，再过 Gate 3。

## 门禁

### 本机辅助验证（2026-10-24）

本机只有 Swift 5.7.2 Command Line Tools 和 macOS 13.1 SDK，SwiftPM 不可用（缺 PackageDescription 模块），按约定不装 Xcode。所以没有跑 `make test` 本身，而是分开做了下面几项：

| 项目 | 做法 | 结果 |
|---|---|---|
| Core 单测 | `swiftc` 直接编译 `GlossTypeCore` 和全部测试，链接一个最小 XCTest 替身（只实现用到的断言和 `XCTUnwrap`），用 ObjC 运行时枚举 `XCTestCase` 子类和 `test` 方法逐个跑 | 96 / 96 通过 |
| Python 测试 | `python3 -m unittest discover -s scripts/tests` | 33 个通过 |
| STDD 追溯检查 | `python3 scripts/stdd_check.py` | 通过：121 条带场景 ID 的测试，桩 0 条 |
| App 层类型检查 | `swiftc -typecheck -swift-version 5 -target x86_64-apple-macos13.1`，链接上面编出的 Core 模块 | 通过，0 警告 |
| Translation 部分类型检查 | 13.1 SDK 没有 Translation 框架，按苹果文档的 macOS 15 签名写了一个替身模块（`TranslationSession`、`Configuration`、`LanguageAvailability`、`TranslationError`、`.translationTask`），再对 App 层做类型检查 | 修复后通过；替身能复现复核发现的 `TranslationError` 歧义错误。替身只验证本仓库代码自洽，不能证明苹果的签名，真机编译为准 |
| 独立复核 | 另起一个 agent，只给代码不给结论，专查本机编译不到的部分 | 见「独立复核」 |

替身不是真 XCTest：断言语义按 XCTest 文档实现，但没有覆盖异步期望、性能测试等本仓库没用到的功能。真机上的 `swift test` 才算数。

### 真机验证（待维护者补）

- `make data`：
- `make test`（`swift test` 用例数 / 通过、Python、stdd-check）：
- `make app`：
- `make install`：

## 场景验证

自动化场景的「结果」列是本机结果；真机 `swift test` 跑完后整体确认一次即可。

| 场景 | 验证方式 | 测试 | 结果 |
|---|---|---|---|
| `[composition.01]` 字母组成标记文本 | unit | `test_composition_01_letters_form_marked_text` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.02]` Shift 加字母按大写组词 | unit | `test_composition_02_shifted_letter_composes_uppercase` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.03]` 词中间的撇号继续组词 | unit | `test_composition_03_apostrophe_inside_word_continues` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.04]` 词首的撇号交还给应用 | unit | `test_composition_04_leading_apostrophe_passes_through` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.05]` 退格删组词末尾字符 | unit | `test_composition_05_backspace_deletes_last_character` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.06]` 退格删空后收起 | unit | `test_composition_06_backspace_to_empty_hides_panel` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.07]` 空格提交原样 | unit | `test_composition_07_space_commits_literal` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.08]` 空格提交移动过的高亮候选 | unit | `test_composition_08_space_commits_moved_highlight` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.09]` 数字提交第 N 个候选 | unit | `test_composition_09_digit_selects_candidate` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.10]` 数字超出候选数时提交原样加数字 | unit | `test_composition_10_digit_beyond_candidates_commits_literal_and_digit` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.11]` Tab 提交第一个建议词 | unit | `test_composition_11_tab_commits_first_suggestion` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.12]` 没有建议词时 Tab 提交原样 | unit | `test_composition_12_tab_without_suggestion_commits_literal` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.13]` 左右方向键循环移动高亮 | unit | `test_composition_13_left_arrow_wraps_highlight` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.14]` 回车只确认组词 | unit | `test_composition_14_enter_confirms_without_space` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.15]` Esc 提交原样并收起 | unit | `test_composition_15_escape_commits_literal_and_hides` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.16]` 标点提交原样加标点 | unit | `test_composition_16_punctuation_commits_literal_with_punctuation` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.17]` 修饰键组合提交原样后交给应用 | unit | `test_composition_17_shortcut_commits_literal_then_passes_through` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.18]` 上下方向键提交原样后交给应用 | unit | `test_composition_18_vertical_arrow_commits_literal_then_passes_through` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.19]` 失焦时提交原样 | unit | `test_composition_19_focus_loss_commits_literal` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.20]` 空闲时非字母键交还给应用 | unit | `test_composition_20_idle_non_letter_passes_through` | 本机替身通过；真机 `swift test` 待跑 |
| `[composition.21]` 系统按键映射成输入法按键 | unit | `test_composition_21_system_keys_map_to_input_keys`<br>`test_composition_21_modifier_combinations_are_shortcuts`<br>`test_composition_21_non_printable_keys_are_other` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.01]` 原样排第一，补全按词频 | unit | `test_completion_01_literal_first_then_by_frequency` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.02]` 上下文续词排在词频之前 | unit | `test_completion_02_context_continuations_before_frequency` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.03]` 原样不是已知词时纠错排最前 | unit | `test_completion_03_corrections_first_for_unknown_literal` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.04]` 原样是已知词时不放纠错 | unit | `test_completion_04_no_corrections_for_known_literal` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.05]` 系统拼写补全补位 | unit | `test_completion_05_spelling_completions_fill_in` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.06]` 不同来源的同一个词只出现一次 | unit | `test_completion_06_same_word_from_two_sources_once` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.07]` 原样不重复出现 | unit | `test_completion_07_literal_not_repeated` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.08]` 首字母大写跟随输入 | unit | `test_completion_08_capitalized_input_capitalizes_suggestions` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.09]` 全大写跟随输入 | unit | `test_completion_09_uppercase_input_uppercases_suggestions` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.10]` 专有名词保留自身大小写 | unit | `test_completion_10_proper_noun_keeps_its_casing` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.11]` 候选数量受设置限制 | unit | `test_completion_11_candidate_count_follows_preferences` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.12]` 原形也匹配时不列出变形 | integration | `test_completion_12_inflections_hidden_when_lemma_matches` | 本机替身通过；真机 `swift test` 待跑 |
| `[completion.13]` 原形不匹配时照常列出变形 | integration | `test_completion_13_inflection_listed_when_lemma_does_not_match` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.01]` 提交词后显示下一个词 | unit | `test_prediction_01_next_word_after_commit` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.02]` 高阶上下文优先 | unit | `test_prediction_02_longer_context_wins` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.03]` 句首联想首字母大写 | unit | `test_prediction_03_sentence_start_capitalized` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.04]` 手动敲空格后也联想 | unit | `test_prediction_04_manual_space_predicts` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.05]` Tab 接受联想词 | unit | `test_prediction_05_tab_accepts_prediction` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.06]` 接受联想词后继续联想 | unit | `test_prediction_06_prediction_chains_after_accept` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.07]` ⇧Tab 接受整条短语 | unit | `test_prediction_07_backtab_accepts_phrase` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.08]` 短语最多五个词 | unit | `test_prediction_08_phrase_at_most_five_words` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.09]` 短语遇到句末停止 | unit | `test_prediction_09_phrase_stops_at_sentence_end` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.10]` 短语遇到低频续词停止 | unit | `test_prediction_10_phrase_stops_at_rare_continuation` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.11]` 关闭短语联想 | unit | `test_prediction_11_phrase_can_be_disabled` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.12]` 组词时也给出短语 | unit | `test_prediction_12_phrase_while_composing` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.13]` 联想时数字交给应用 | unit | `test_prediction_13_digit_passes_through_while_predicting` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.14]` 联想时输入字母开始带上下文的组词 | unit | `test_prediction_14_letter_starts_contextual_composition` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.15]` Esc 收起联想 | unit | `test_prediction_15_escape_hides_predictions` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.16]` 其它控制键收起联想并交给应用 | unit | `test_prediction_16_control_key_hides_and_passes_through` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.17]` 没有语言模型时不联想 | unit | `test_prediction_17_no_model_no_predictions` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.18]` 用户自备的模型优先 | integration | `test_prediction_18_user_model_preferred`<br>`test_prediction_18_bundle_model_when_user_has_none` | 本机替身通过；真机 `swift test` 待跑 |
| `[prediction.19]` 不认识的模型版本当作没有 | integration | `test_prediction_19_unknown_version_treated_as_absent` | 本机替身通过；真机 `swift test` 待跑 |
| `[gloss.01]` 候选显示释义 | integration | `test_gloss_01_candidate_shows_gloss` | 本机替身通过；真机 `swift test` 待跑 |
| `[gloss.02]` 查释义不区分大小写 | integration | `test_gloss_02_lookup_ignores_case` | 本机替身通过；真机 `swift test` 待跑 |
| `[gloss.03]` 变形词还原到原形 | integration | `test_gloss_03_inflections_fall_back_to_lemma` | 本机替身通过；真机 `swift test` 待跑 |
| `[gloss.04]` 不认识的词没有释义 | integration | `test_gloss_04_unknown_word_has_no_gloss` | 本机替身通过；真机 `swift test` 待跑 |
| `[gloss.05]` 过长的释义截断 | integration | `test_gloss_05_long_gloss_truncated` | 本机替身通过；真机 `swift test` 待跑 |
| `[gloss.06]` 关闭释义 | integration | `test_gloss_06_gloss_can_be_disabled` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.01]` 组词时翻译当前句加原样 | unit | `test_translation_01_composing_uses_known_literal` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.02]` 原样不是已知词时用第一个建议词 | unit | `test_translation_02_unknown_literal_uses_first_suggestion` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.03]` 用户移动过高亮时用高亮候选 | unit | `test_translation_03_moved_highlight_wins` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.04]` 联想时翻译当前句 | unit | `test_translation_04_predicting_uses_current_sentence` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.05]` 句末之后翻译刚结束的一句 | unit | `test_translation_05_after_terminator_uses_finished_sentence` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.06]` 源文本最多 300 个字符 | unit | `test_translation_06_source_capped_at_300_characters` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.07]` 防抖只请求最新的源文本 | unit | `test_translation_07_debounce_requests_latest_only` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.08]` 丢弃过期的结果 | unit | `test_translation_08_stale_result_dropped` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.09]` 翻译过的句子直接用缓存 | unit | `test_translation_09_cached_result_reused` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.10]` 源文本没变不重复请求 | unit | `test_translation_10_unchanged_source_not_requested_again` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.11]` 等待时显示上一次的译文 | unit | `test_translation_11_previous_translation_shown_while_pending` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.12]` 翻译失败时提示 | unit | `test_translation_12_failure_shows_message` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.13]` 语言包未安装时提示去设置下载 | unit | `test_translation_13_missing_language_pack_shows_hint` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.14]` 关闭整句翻译 | unit | `test_translation_14_disabled_translation` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.15]` 源文本为空时隐藏译文行 | unit | `test_translation_15_empty_source_hides_line` | 本机替身通过；真机 `swift test` 待跑 |
| `[translation.16]` 苹果本地翻译在输入法里可用 | 手动 | — | 待真机验证 |
| `[translation.17]` 在设置窗下载语言包 | 手动 | — | 待真机验证 |
| `[learning.01]` 提交时记录前两个词的搭配 | integration | `test_learning_01_records_word_with_two_previous_words` | 本机替身通过；真机 `swift test` 待跑 |
| `[learning.02]` 只记录字母词 | integration | `test_learning_02_only_letter_words_recorded`<br>`test_learning_02_digit_glued_to_word_not_recorded` | 本机替身通过；真机 `swift test` 待跑 |
| `[learning.03]` 关闭学习后不再记录 | integration | `test_learning_03_disabled_learning_records_nothing` | 本机替身通过；真机 `swift test` 待跑 |
| `[learning.04]` 记录在重启后保留 | integration | `test_learning_04_records_survive_restart` | 本机替身通过；真机 `swift test` 待跑 |
| `[learning.05]` 清除学习记录 | integration | `test_learning_05_clear_removes_everything` | 本机替身通过；真机 `swift test` 待跑 |
| `[learning.06]` 用过两次的搭配排第一 | integration | `test_learning_06_twice_used_pair_ranks_first` | 本机替身通过；真机 `swift test` 待跑 |
| `[learning.07]` 学会词表里没有的新词 | integration | `test_learning_07_new_word_learned_after_two_commits` | 本机替身通过；真机 `swift test` 待跑 |
| `[learning.08]` 只提交过一次的生词不进候选 | integration | `test_learning_08_single_typo_not_suggested` | 本机替身通过；真机 `swift test` 待跑 |
| `[panel.01]` 显示在光标下方 | unit | `test_panel_01_below_caret` | 本机替身通过；真机 `swift test` 待跑 |
| `[panel.02]` 下方放不下时显示在上方 | unit | `test_panel_02_above_caret_when_no_room_below` | 本机替身通过；真机 `swift test` 待跑 |
| `[panel.03]` 左右不超出屏幕 | unit | `test_panel_03_clamped_to_screen_horizontally` | 本机替身通过；真机 `swift test` 待跑 |
| `[panel.04]` 拿不到光标位置时跟随鼠标 | unit | `test_panel_04_follows_mouse_without_caret` | 本机替身通过；真机 `swift test` 待跑 |
| `[panel.05]` 输入法失活时收起 | unit | `test_panel_05_deactivation_hides_panel` | 本机替身通过；真机 `swift test` 待跑 |
| `[panel.06]` 候选窗内容 | 手动 | — | 待真机验证 |
| `[panel.07]` 跟随浅色与深色模式 | 手动 | — | 待真机验证 |
| `[panel.08]` 在全屏应用上方显示 | 手动 | — | 待真机验证 |
| `[settings.01]` 没有存过设置时用默认值 | unit | `test_settings_01_defaults_when_never_saved` | 本机替身通过；真机 `swift test` 待跑 |
| `[settings.02]` 越界的值被夹到范围内 | unit | `test_settings_02_out_of_range_values_clamped` | 本机替身通过；真机 `swift test` 待跑 |
| `[settings.03]` 修改后持久保存 | unit | `test_settings_03_saved_values_persist` | 本机替身通过；真机 `swift test` 待跑 |
| `[settings.04]` 设置窗 | 手动 | — | 待真机验证 |
| `[install.01]` Info.plist 带输入法必需的键 | static / script | `test_install_01_info_plist_has_input_method_keys` | 通过 |
| `[install.02]` 控制器类名与代码一致 | static / script | `test_install_02_controller_class_matches_objc_name` | 通过 |
| `[install.03]` Bundle ID 含 inputmethod | static / script | `test_install_03_bundle_id_contains_inputmethod` | 通过 |
| `[install.04]` 打包脚本组装出完整的 app | static / script | `test_install_04_package_script_assembles_bundle` | 通过 |
| `[install.05]` 缺词典数据时打包失败并提示 | static / script | `test_install_05_package_script_requires_glossary` | 通过 |
| `[install.06]` 安装后出现在输入源里 | 手动 | — | 待真机验证 |
| `[install.07]` 在真实应用里打字 | 手动 | — | 待真机验证 |
| `[dictdata.01]` 去掉词性取前三个义项 | script | `test_dictdata_01_strip_pos_and_take_three_senses` | 通过 |
| `[dictdata.02]` 跳过领域标签行 | script | `test_dictdata_02_skip_domain_tag_lines` | 通过 |
| `[dictdata.03]` 义项不够时接下一行 | script | `test_dictdata_03_continue_on_next_line` | 通过 |
| `[dictdata.04]` 只收单个词 | script | `test_dictdata_04_only_single_words` | 通过 |
| `[dictdata.05]` 按词频排名 | script | `test_dictdata_05_rank_by_frequency` | 通过 |
| `[dictdata.06]` 只保留最常用的 N 个 | script | `test_dictdata_06_keep_top_n` | 通过 |
| `[dictdata.07]` 同一个词多条时取排名高的 | script | `test_dictdata_07_duplicate_case_keeps_best_ranked` | 通过 |
| `[dictdata.08]` 变形展开成独立条目 | script | `test_dictdata_08_expand_inflections` | 通过 |
| `[dictdata.09]` 变形自带的释义不像释义时用原形的 | script | `test_dictdata_09_inflection_without_real_gloss_uses_lemma` | 通过 |
| `[dictdata.10]` 变形没有词频时用原形的排名 | script | `test_dictdata_10_inflection_inherits_lemma_rank` | 通过 |
| `[dictdata.11]` 记录来源与许可证 | script | `test_dictdata_11_meta_records_source_and_license` | 通过 |
| `[dictdata.12]` 测试夹具与脚本输出一致 | script | `test_dictdata_12_swift_fixture_matches_script_output` | 通过 |
| `[lmdata.01]` 分词保留缩写去掉数字标点 | script | `test_lmdata_01_keep_contractions_drop_digits_and_punctuation` | 通过 |
| `[lmdata.02]` 句首句尾加标记 | script | `test_lmdata_02_sentence_markers` | 通过 |
| `[lmdata.03]` 按最小次数剪枝 | script | `test_lmdata_03_prune_by_min_count` | 通过 |
| `[lmdata.04]` 每个上下文的续词有上限 | script | `test_lmdata_04_top_k_per_context` | 通过 |
| `[lmdata.05]` 显示形式取最常见的大小写 | script | `test_lmdata_05_display_uses_most_common_case` | 通过 |
| `[lmdata.06]` 记录阶数、语料和许可证 | script | `test_lmdata_06_meta_records_order_corpus_license` | 通过 |
| `[lmdata.07]` 上下文总数等于剪枝前的续词次数之和 | script | `test_lmdata_07_context_total_counts_before_pruning` | 通过 |
| `[lmdata.08]` 高阶命中用相对频率 | integration | `test_lmdata_08_matched_context_uses_relative_frequency` | 本机替身通过；真机 `swift test` 待跑 |
| `[lmdata.09]` 未命中退一阶乘 0.4 | integration | `test_lmdata_09_backoff_multiplies_by_point_four` | 本机替身通过；真机 `swift test` 待跑 |
| `[lmdata.10]` 测试夹具与脚本输出一致 | script | `test_lmdata_10_swift_fixture_matches_script_output` | 通过 |

## RED 证据

- **本轮多数切片没有单独留下 RED 记录。** S5–S12 的测试和实现是在同一轮写完再一起编译运行的，没有逐个切片先跑出失败。这不符合 STDD 第 4 步的要求，如实记在这里。
- **补救一：变异检查。** 为了确认测试能区分对错，在 cb80cd9 上做了 9 个有针对性的变异，每次只改一处行为，9 个全部被测试抓到：

  | 变异 | 抓到它的测试 |
  |---|---|
  | 回退系数 0.4 → 0.5 | `lmdata.09` |
  | 空格提交第一个建议词（不再提交原样） | `composition.07` |
  | 去掉生词出现两次的门槛 | `learning.08` |
  | 不丢弃过期的翻译结果 | `translation.08` |
  | 联想不补句首标记 | `prediction.03`、`prediction.10` |
  | `-ing` 还原时不去双写 | `gloss.03` |
  | 学习只记无上下文的一元 | `learning.01`、`learning.04` |
  | 候选窗与光标间距 4 → 0 | `panel.01`、`panel.02`、`panel.04` |
  | 空闲时空格不触发联想 | `prediction.02`–`11`、`15`，`learning.06`，`translation.04` |

- **补救二：后补切片按顺序走了 RED。** 实测真实词典后补的 `completion.12`，先写测试再改实现。
  - RED：`test_completion_12_inflections_hidden_when_lemma_matches` 失败，原因是 `hello` 不在候选里、`helped` / `helping` / `helps` 在。失败原因是行为不对，不是编译错误。
  - 改实现后 96 / 96 通过。
  - `completion.13` 是防止过滤过头的保护性场景，修改前后都通过。
- **数据脚本切片（S2、S3）：** Python 测试同样是和脚本一起写的，没有留 RED 记录。

## 失败模式核查

| # | 失败模式 | 结论 |
|---|---|---|
| 1 | 幻觉 | 风险集中在 App 层：macOS 15 Translation、IMK、SwiftUI 的 API 签名本机编译不到。独立复核按苹果文档和开源输入法（Squirrel）逐条核对，发现 1 个编译错误，已修；其余签名核对无误，见「独立复核」 |
| 2 | 范围蔓延 | 没有超出 proposal「做什么」的功能。新增的 `completion.12` / `13` 修的是范围内的候选质量问题，记为调整 #8 |
| 3 | 静默吞错 | 打不开、格式不对的数据文件，查询失败、写入失败都记 `NSLog`。学习记录读路径原来用 `try?` 静默当空，已改为记日志（500b6d3）。翻译失败在候选窗显示「翻译失败」，语言包没装时提示去设置窗下载 |
| 4 | 上下文丢失 | 维护者的约束逐条核对，见本表下方 |
| 5 | 工具误用 | 本机 SwiftPM 坏了，改用 `swiftc` 直接编译加 XCTest 替身。替身和验证脚本放在会话临时目录，不进仓库 |
| 6 | 运行时偏差 | 本机是 Swift 5.7 + macOS 12/13 目标，真机是 Swift 6 工具链（Swift 5 语言模式）+ macOS 15。Core 刻意只用 Swift 5.7 能编的语法。差异以真机 `make test` 为准 |
| 7 | 链路断档 | IMK 事件 → `InputSession` → 候选窗 / 翻译 → 客户端这条链只能真机验证：`install.07`、`panel.06`、`translation.16` |
| 8 | 内容质量 | 见本表下方 |
| 9 | 指令衰减 | 提交信息全部中文、`<type>(<scope>):` 格式、无 AI 署名。没有在维护者本机编译 app，没有装 Xcode |
| 10 | 覆盖真空 | 追溯检查通过：125 条场景，117 条自动化、8 条手动。手动场景都写明了原因，结果待真机补 |
| 11 | 契约断层 | 见本表下方 |

**4. 上下文丢失：维护者约束逐条核对**
- 没有复用 SwiftType 的代码或数据。
- 目标系统是 macOS 15+。
- 按 STDD 走：规格、场景 ID、追溯检查都已就位。
- 不内置语料，语言模型可插拔。
- 规格和设计的调整都记在 `design-adjustments.md`。

**8. 内容质量：用 ECDICT 全量 `ecdict.csv`（提交 bc015ed）跑 `build_glossary.py`**
- 生成 87,399 个词条，文件 6.7 MB，用时约 6 秒。
- 抽查结果：

  | 词 | 释义 | 排名 | 备注 |
  |---|---|---|---|
  | hello | 喂，嘿 | 1995 | |
  | went | 去，走，达到 | 33 | 原形 go |
  | cats | 猫，恶妇，呕吐 | 1595 | 原形 cat |
  | I | 我 | 10 | |
  | the | 那 | 1 | |
  | okay | 好，可以，行 | 1482 | |
  | yeah | (非正式)是，是的 | 395 | |

- 实测发现变形挤占候选，已修复（调整 #8）。
- `gonna`、`wanna`、`lol` 等口语词不在词表里。它们要靠维护者的会话语料，或者在学习记录里提交两次才会出现。

**11. 契约断层**
- `Info.plist` 的控制器类名与代码一致，由 `install.02` 检查。
- 三份 SQLite 的格式写在 `docs/data-formats.md`，Swift 读取时校验 `format` / `version`。
- 测试夹具由脚本生成，并检查与脚本输出一致（`dictdata.12`、`lmdata.10`）。

## 独立复核

另起一个 agent，只给代码和背景，不给结论，专查本机编译不到的部分：macOS 15 SDK、Swift 6 工具链的 Swift 5 模式、SwiftPM 清单、打包与安装。它查了苹果文档、Swift 论坛和 Squirrel 的源码，并在本机用两个模块复现了第 1 条。

| # | 级别 | 问题 | 处理 |
|---|---|---|---|
| 1 | 编译错误 | Translation 框架也有 `TranslationError`，`AppleTranslator.swift` 同时 import 两个模块，类型查找有歧义 | Core 的类型写全名；AGENTS.md 记为坑 |
| 2 | 运行时 | `.translationTask` 万一没起来，请求永远挂着，没有日志 | 每个请求 8 秒超时，超时判失败、记日志、重建会话；宿主窗口挪到主屏可见区域并加 `.fullScreenAuxiliary` |
| 3 | 运行时 | 语言包被删后，`translate` 会在看不见的窗口上请求下载，队列被堵死；Core 已缓存的「已安装」也不会失效 | 每次取队列前查语言包，未安装就回报「未安装」不调 `translate`；出错时再查一次，未安装映射为 `.notInstalled`（Core 据此清掉缓存） |
| 4 | 运行时（少见，会崩） | 任务启动前又来请求会再次改配置；旧会话在配置变化后被使用会触发 `fatalError` | 等待任务启动期间不再改配置；用代数标记会话，旧任务发现会话已重建就停手；每个请求只回调一次 |
| 5 | 小 | 刷新、收起候选窗时会先用旧内容渲染一次，可能闪一帧 | 候选窗更新改成一次性渲染；收起时先收起再重置翻译 |
| 6 | 小 | 设置窗：下载失败的提示被立刻覆盖；下载在后台完成后状态不更新；下载中按钮还能点 | 失败时保留提示；每次打开设置窗重新检查；下载中禁用按钮 |
| 7 | 构建 | `make install` 先 `killall` 再复制，系统可能在中间把旧版本拉起来 | 改为复制完再 `killall` |
| 8 | 小 | 注册返回非 0 或注册后暂时找不到输入源时 `make install` 失败，但 app 其实已装好 | 只提示、不失败；已启用的输入源不再重复启用 |
| 9 | 小 | 没有覆盖 `hidePalettes` / `inputControllerWillClose`，客户端没走 `deactivateServer` 就消失时候选窗留在屏幕上 | 两个都覆盖；候选窗是共享的，只收起本控制器显示的那次 |

**复核确认没问题的部分**
- **Translation API 签名：**
  - `Configuration(source:target:)` 和 `invalidate()`；
  - `translationTask(_:action:)`，在 `body` 里创建，所以在主 actor 上运行；
  - `translate(_:)` 返回的 `.targetText`；
  - `prepareTranslation()`；
  - `LanguageAvailability().status(from:to:)` 及其三个状态。
- **IMK 覆盖方法：** 签名都与 Squirrel 当前的 Swift 源码一致。
- **构建与打包：**
  - `Package.swift` 的 `swiftLanguageModes: [.v5]` 和 `.macOS(.v15)`；
  - Makefile 里含空格的路径都加了引号；
  - `package_app.sh` 有可执行权限；
  - `Info.plist` 的必需键都在。
- **「App 层不加 `@MainActor`」：** 在 Swift 6 工具链的 Swift 5 模式下成立。
  - AppKit、IMK、SwiftUI 的主 actor 标注都是 preconcurrency，违反时最多是警告。
  - 反过来给 App 类加显式 `@MainActor`，会产生真正的编译错误。
  - 只有在 Swift 6 语言模式下才会出现「Sending 'session' risks causing data races」，本仓库不用该模式。

## 设计调整摘要

详见 `design-adjustments.md`，共 9 条。其中两条是 Major，要在 Gate 3 确认：

- **#1：生词要提交两次才学会。** `learning.07` 的 WHEN 改为「提交过两次」，新增 `learning.08`。
  - 原因：避免一次手滑的错字被永久学会。
  - 代价：新造词、专有名词要打两次才会出现在补全里。
- **#8：词表补全时，原形也匹配前缀的变形不列出。** 新增 `completion.12`、`completion.13`。
  - 原因：用真实词典实测，变形和原形同排名，打 `hel` 时 `helps`、`hells`、`helped` 占满候选，把 `hello` 挤了出去。

其余 7 条是 Minor 的实现细节，已写进 `design.md`：

- 句首未知时不补 `<s>`；
- 连续空格不弹联想；
- 联想只用有上下文证据的续词；
- 仅显示译文的候选窗；
- 学习的写入时机；
- `dictdata` 场景的措辞修正；
- 翻译请求超时与语言包检查（来自独立复核）。

## 遗留问题

- 8 条手动场景待真机验证：`translation.16`、`translation.17`、`panel.06`–`panel.08`、`settings.04`、`install.06`、`install.07`。
- 没有内置语言模型。在维护者提供语料之前，下一个词的联想只来自学习记录，初期基本为空。
- 词表缺少口语缩写。
- macOS 15 只能经 SwiftUI 拿到翻译会话，输入法进程里用隐藏窗口承载。不同版本系统上的行为要真机确认；macOS 26 起可以改用不依赖视图的 `TranslationSession(installedSource:target:)`。
- App 层的翻译、设置窗代码只经过替身类型检查，真机 `swift build` 是第一次真正编译。

## 生效方式

首次安装：

1. `make data && make install`。
2. 在「系统设置 → 键盘 → 输入法」里添加 GlossType。不出现时注销后重新登录。
3. 在输入法菜单的「设置…」里下载英→中语言包。
