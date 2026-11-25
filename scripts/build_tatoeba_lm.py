#!/usr/bin/env python3
"""用 Tatoeba 英文句子导出生成 GlossType 的语言模型。

用法：
    python3 scripts/build_tatoeba_lm.py --export Data/downloads/eng_sentences.tsv.bz2 \\
        --output Data/ngram.sqlite [--downloaded YYYY-MM-DD] [--order 4]

导出来自 https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2，
每行 `id<TAB>语言<TAB>句子`。Tatoeba 的句子按 CC BY 2.0 FR 授权（部分为 CC0），
署名见 THIRD_PARTY_NOTICES.md。导出每周更新、没有版本号，所以把下载日期写进模型元数据。
"""
from __future__ import annotations

import argparse
import bz2
import datetime
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_ngram  # noqa: E402

CORPUS_NAME = "Tatoeba English sentences (downloaded {date})"
LICENSE = "CC BY 2.0 FR"
DEFAULT_ORDER = 4


def extract_sentences(export_path, corpus_path) -> int:
    """把导出里语言列为 eng 的句子逐行写进语料，返回句子数。列数不对的行跳过。"""
    count = 0
    with bz2.open(export_path, "rt", encoding="utf-8", errors="replace") as source, \
            open(corpus_path, "w", encoding="utf-8") as target:
        for line in source:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3 or parts[1] != "eng" or not parts[2].strip():
                continue
            target.write(parts[2].strip() + "\n")
            count += 1
    return count


def build(export_path, output_path, downloaded: str, order: int = DEFAULT_ORDER) -> dict[str, int]:
    with tempfile.TemporaryDirectory() as folder:
        corpus = Path(folder) / "tatoeba-eng.txt"
        extract_sentences(export_path, corpus)
        return build_ngram.build(
            corpus, output_path, order=order,
            corpus_name=CORPUS_NAME.format(date=downloaded), license=LICENSE,
        )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--export", required=True, help="Tatoeba 英文句子导出（.tsv.bz2）")
    parser.add_argument("--output", required=True, help="输出的 ngram.sqlite")
    parser.add_argument("--downloaded", help="下载日期 YYYY-MM-DD（默认取导出文件的修改日期）")
    parser.add_argument("--order", type=int, default=DEFAULT_ORDER, help=f"最高阶数（默认 {DEFAULT_ORDER}）")
    args = parser.parse_args(argv[1:])
    downloaded = args.downloaded or datetime.date.fromtimestamp(Path(args.export).stat().st_mtime).isoformat()
    stats = build(args.export, args.output, downloaded, args.order)
    print(f"已生成 {args.output}：{stats}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
