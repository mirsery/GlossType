#!/bin/bash
# 把 SwiftPM 构建出的可执行文件组装成输入法 .app。
# 用法：scripts/package_app.sh <可执行文件> <输出的 .app 路径> <数据目录>
# 数据目录里必须有 glossary.sqlite（make data 生成）；有 ngram.sqlite 就一起打进去。
# 设置 SKIP_CODESIGN=1 跳过 ad-hoc 签名（测试用）。
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "用法：$0 <可执行文件> <输出的 .app 路径> <数据目录>" >&2
  exit 2
fi

BINARY=$1
APP=$2
DATA_DIR=$3
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [ ! -f "$BINARY" ]; then
  echo "找不到可执行文件 $BINARY，先运行 swift build -c release" >&2
  exit 1
fi
if [ ! -f "$DATA_DIR/glossary.sqlite" ]; then
  echo "缺少 $DATA_DIR/glossary.sqlite，先运行 make data" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/GlossType"
chmod +x "$APP/Contents/MacOS/GlossType"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$ROOT/Packaging/GlossType.pdf" "$APP/Contents/Resources/"
cp "$DATA_DIR/glossary.sqlite" "$APP/Contents/Resources/"
if [ -f "$DATA_DIR/ngram.sqlite" ]; then
  cp "$DATA_DIR/ngram.sqlite" "$APP/Contents/Resources/"
fi

if [ "${SKIP_CODESIGN:-0}" != "1" ]; then
  codesign --force --sign - --timestamp=none "$APP"
fi
echo "已生成 $APP"
