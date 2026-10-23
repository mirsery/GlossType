SWIFT ?= swift
PYTHON ?= python3

DATA_DIR := Data
BUILD_DIR := build
APP := $(BUILD_DIR)/GlossType.app
INSTALL_DIR := $(HOME)/Library/Input Methods

# ECDICT 固定到一个提交，保证每次生成的词典一样
ECDICT_COMMIT := bc015ed2e24a7abef49fc6dbbb7fe32c1dadaf8b
ECDICT_URL := https://raw.githubusercontent.com/skywind3000/ECDICT/$(ECDICT_COMMIT)/ecdict.csv
ECDICT_CSV := $(DATA_DIR)/downloads/ecdict.csv

CORPUS_NAME ?=
CORPUS_LICENSE ?=

.PHONY: test swift-test py-test stdd-check data lm app install uninstall clean

## 门禁：Swift 测试 + Python 测试 + STDD 追溯检查
test: swift-test py-test stdd-check

swift-test:
	$(SWIFT) test

py-test:
	$(PYTHON) -m unittest discover -s scripts/tests

stdd-check:
	$(PYTHON) scripts/stdd_check.py

## 下载 ECDICT，生成释义词典 + 词频词表
data: $(DATA_DIR)/glossary.sqlite

$(ECDICT_CSV):
	mkdir -p $(dir $@)
	curl -fL --retry 3 -o $@.tmp "$(ECDICT_URL)"
	mv $@.tmp $@

$(DATA_DIR)/glossary.sqlite: $(ECDICT_CSV) scripts/build_glossary.py
	$(PYTHON) scripts/build_glossary.py --input $(ECDICT_CSV) --output $@

## 用自备语料生成语言模型：make lm CORPUS=语料.txt CORPUS_NAME=名称 CORPUS_LICENSE=许可证
lm:
	@if [ -z "$(CORPUS)" ] || [ -z "$(CORPUS_NAME)" ] || [ -z "$(CORPUS_LICENSE)" ]; then \
		echo "用法：make lm CORPUS=<一行一句的 UTF-8 文本> CORPUS_NAME=<语料名称> CORPUS_LICENSE=<许可证>"; exit 2; \
	fi
	mkdir -p $(DATA_DIR)
	$(PYTHON) scripts/build_ngram.py --input "$(CORPUS)" --output $(DATA_DIR)/ngram.sqlite \
		--corpus-name "$(CORPUS_NAME)" --license "$(CORPUS_LICENSE)"

## release 构建并组装 build/GlossType.app（Data/ 里有 ngram.sqlite 就一起打包）
app:
	$(SWIFT) build -c release --product GlossType
	scripts/package_app.sh "$$($(SWIFT) build -c release --show-bin-path)/GlossType" $(APP) $(DATA_DIR)

## 安装到 ~/Library/Input Methods 并注册、启用输入源
install: app
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/GlossType.app"
	cp -R $(APP) "$(INSTALL_DIR)/"
	@# 复制完再杀旧进程：先杀的话，系统可能在复制前把旧版本又拉起来
	-killall GlossType 2>/dev/null || true
	"$(INSTALL_DIR)/GlossType.app/Contents/MacOS/GlossType" --register

uninstall:
	-killall GlossType 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/GlossType.app"
	@echo "已删除。若输入源列表里还有 GlossType，到「系统设置 → 键盘 → 输入法」里移除。"

clean:
	rm -rf .build $(BUILD_DIR)
