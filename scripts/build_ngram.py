#!/usr/bin/env python3
"""从语料生成 GlossType 的 n-gram 语言模型。

用法：
    python3 scripts/build_ngram.py --input corpus.txt --output Data/ngram.sqlite \\
        --corpus-name "语料名称" --license "语料许可证" [--order 3] [--min-count 2] [--top-k 50]

语料是 UTF-8 纯文本，一行一段，行内按 . ! ? 再切句。脚本不下载任何语料：选哪份语料、
它的许可证是否允许再分发，由使用者决定。输出格式见 docs/data-formats.md。
"""
from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path

FORMAT = "glosstype-ngram"
VERSION = "1"
BOS = "<s>"
EOS = "</s>"

WORD_RE = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)*")
SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")


def tokenize(text: str) -> list[tuple[str, str]]:
    """返回 (小写词, 原始写法)。只保留字母词和撇号缩写，数字与标点去掉。"""
    text = text.replace("’", "'").replace("‘", "'")
    return [(m.group(0).lower(), m.group(0)) for m in WORD_RE.finditer(text)]


def sentences(path: Path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            for part in SENTENCE_SPLIT_RE.split(line.strip()):
                tokens = tokenize(part)
                if tokens:
                    yield tokens


def build(input_path, output_path, order: int = 3, min_count: int = 2, top_k: int = 50,
          max_vocab: int = 100000, corpus_name: str = "", license: str = "") -> dict[str, int]:
    if order < 2:
        raise ValueError("order 至少为 2")

    unigram: Counter[str] = Counter()
    surface: dict[str, Counter[str]] = defaultdict(Counter)
    sentence_count = 0
    token_count = 0
    for tokens in sentences(Path(input_path)):
        sentence_count += 1
        token_count += len(tokens)
        for index, (word, raw) in enumerate(tokens):
            unigram[word] += 1
            # 句首的大写多半只是句首规则，不算进显示形式
            if index > 0:
                surface[word][raw] += 1
        unigram[EOS] += 1

    vocab_words = [w for w, _ in sorted(unigram.items(), key=lambda item: (-item[1], item[0]))[:max_vocab]]
    vocab = set(vocab_words) | {EOS}

    # 第二遍计 2..order 阶；含词表外词的 n-gram 丢弃
    counts: dict[tuple[str, ...], Counter[str]] = defaultdict(Counter)
    for tokens in sentences(Path(input_path)):
        sequence = [BOS] + [word for word, _ in tokens] + [EOS]
        for position in range(1, len(sequence)):
            word = sequence[position]
            if word not in vocab:
                continue
            for size in range(1, order):
                start = position - size
                if start < 0:
                    break
                context = tuple(sequence[start:position])
                if any(w != BOS and w not in vocab for w in context):
                    break
                counts[context][word] += 1

    def display_of(word: str) -> str:
        forms = surface.get(word)
        if not forms:
            return word
        best = sorted(forms.items(), key=lambda item: (-item[1], item[0] != word, item[0]))[0][0]
        return best

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    db = sqlite3.connect(str(output))
    db.executescript(
        """
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE vocab(id INTEGER PRIMARY KEY, word TEXT NOT NULL UNIQUE, display TEXT NOT NULL, count INTEGER NOT NULL);
        CREATE TABLE context(id INTEGER PRIMARY KEY, words TEXT NOT NULL UNIQUE, total INTEGER NOT NULL);
        CREATE TABLE ngram(
            context_id INTEGER NOT NULL,
            word_id INTEGER NOT NULL,
            count INTEGER NOT NULL,
            PRIMARY KEY(context_id, word_id)
        ) WITHOUT ROWID;
        """
    )
    ordered_vocab = sorted(vocab, key=lambda w: (-unigram[w], w))
    word_id = {}
    for index, word in enumerate(ordered_vocab, start=1):
        word_id[word] = index
        db.execute(
            "INSERT INTO vocab(id, word, display, count) VALUES (?, ?, ?, ?)",
            (index, word, EOS if word == EOS else display_of(word), unigram[word]),
        )

    # 空上下文：一元总数，供退到一阶时算相对频率
    db.execute("INSERT INTO context(id, words, total) VALUES (1, '', ?)", (sum(unigram[w] for w in vocab),))
    next_context_id = 2
    ngram_rows = 0
    for context in sorted(counts):
        followers = counts[context]
        total = sum(followers.values())
        kept = [(w, c) for w, c in followers.items() if c >= min_count]
        kept.sort(key=lambda item: (-item[1], item[0]))
        kept = kept[:top_k]
        if not kept:
            continue
        db.execute(
            "INSERT INTO context(id, words, total) VALUES (?, ?, ?)",
            (next_context_id, " ".join(context), total),
        )
        db.executemany(
            "INSERT INTO ngram(context_id, word_id, count) VALUES (?, ?, ?)",
            [(next_context_id, word_id[w], c) for w, c in kept],
        )
        next_context_id += 1
        ngram_rows += len(kept)

    meta = {
        "format": FORMAT,
        "version": VERSION,
        "order": str(order),
        "corpus": corpus_name,
        "license": license,
        "min_count": str(min_count),
        "top_k": str(top_k),
        "sentences": str(sentence_count),
        "tokens": str(token_count),
    }
    db.executemany("INSERT INTO meta(key, value) VALUES (?, ?)", sorted(meta.items()))
    db.commit()
    db.execute("VACUUM")
    db.close()
    return {"vocab": len(vocab), "contexts": next_context_id - 1, "ngrams": ngram_rows, "sentences": sentence_count}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", required=True, help="语料文件（UTF-8，一行一段）")
    parser.add_argument("--output", required=True, help="输出的 ngram.sqlite")
    parser.add_argument("--corpus-name", required=True, help="语料名称，写进 meta")
    parser.add_argument("--license", required=True, help="语料许可证，写进 meta")
    parser.add_argument("--order", type=int, default=3, help="最高阶数（默认 3）")
    parser.add_argument("--min-count", type=int, default=2, help="二阶及以上 n-gram 的最小出现次数")
    parser.add_argument("--top-k", type=int, default=50, help="每个上下文最多保留的续词数")
    parser.add_argument("--max-vocab", type=int, default=100000, help="词表上限")
    args = parser.parse_args(argv[1:])
    stats = build(args.input, args.output, args.order, args.min_count, args.top_k, args.max_vocab,
                  args.corpus_name, args.license)
    print(f"已生成 {args.output}：{stats}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
