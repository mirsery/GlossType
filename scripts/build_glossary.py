#!/usr/bin/env python3
"""从 ECDICT 生成 GlossType 的释义与词频数据。

用法：
    python3 scripts/build_glossary.py --input ecdict.csv --output Data/glossary.sqlite [--max-words 60000]

ECDICT：https://github.com/skywind3000/ECDICT（MIT）。输出格式见 docs/data-formats.md。
"""
from __future__ import annotations

import argparse
import csv
import re
import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path

FORMAT = "glosstype-glossary"
VERSION = "1"

SINGLE_WORD_RE = re.compile(r"^[A-Za-z]+(?:['-][A-Za-z]+)*$")
POS_TAGS = {
    "n", "v", "vt", "vi", "adj", "a", "adv", "ad", "prep", "conj", "pron",
    "int", "interj", "num", "art", "aux", "pl", "abbr",
}
POS_PREFIX_RE = re.compile(r"^((?:[a-z]+\.\s*)+)")
SENSE_SPLIT_RE = re.compile(r"[,，;；]")
# exchange 里要展开成独立条目的变形：过去式、过去分词、现在分词、第三人称单数、复数、比较级、最高级
EXPAND_TYPES = ("p", "d", "i", "3", "s", "r", "t")


@dataclass
class Entry:
    word: str           # 小写键
    display: str        # 原始写法
    translation: str
    frq: int
    bnc: int
    exchange: dict[str, str]

    @property
    def sort_key(self):
        if self.frq > 0:
            return (0, self.frq, self.word)
        if self.bnc > 0:
            return (1, self.bnc, self.word)
        return (2, 0, self.word)


def _pos_prefix(line: str) -> str | None:
    match = POS_PREFIX_RE.match(line)
    if not match:
        return None
    tags = [t.strip() for t in match.group(1).split(".") if t.strip()]
    if tags and all(t in POS_TAGS for t in tags):
        return match.group(1)
    return None


def _lines(translation: str) -> list[str]:
    text = translation.replace("\\n", "\n")
    return [line.strip() for line in text.split("\n") if line.strip()]


def short_gloss(translation: str, max_senses: int = 3) -> str:
    """去掉词性前缀和 [计] 这类领域标签行，取前几个义项，用「，」连接。"""
    lines = [line for line in _lines(translation) if not line.startswith("[")]
    senses: list[str] = []

    def take(body: str) -> bool:
        for part in SENSE_SPLIT_RE.split(body):
            part = part.strip()
            if part and part not in senses:
                senses.append(part)
                if len(senses) >= max_senses:
                    return True
        return False

    for line in lines:
        prefix = _pos_prefix(line)
        if prefix is not None and take(line[len(prefix):]):
            break
    if not senses:
        # 没有带词性的行（例如「go的过去式」），退而用第一行
        for line in lines:
            if take(line):
                break
    return "，".join(senses)


def looks_like_definition(translation: str) -> bool:
    """第一条非领域标签行以真正的词性开头（abbr. 不算）。"""
    for line in _lines(translation):
        if line.startswith("["):
            continue
        prefix = _pos_prefix(line)
        return prefix is not None and not prefix.startswith("abbr")
    return False


def is_single_word(word: str) -> bool:
    return bool(SINGLE_WORD_RE.match(word))


def parse_exchange(raw: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in (raw or "").split("/"):
        if ":" in item:
            kind, form = item.split(":", 1)
            if kind and form and kind not in result:
                result[kind] = form
    return result


def _int(value: str) -> int:
    try:
        return int(value or 0)
    except ValueError:
        return 0


def read_entries(path: Path) -> dict[str, Entry]:
    """读 ECDICT CSV，按小写词去重，同一个词保留排名最高的那条。"""
    entries: dict[str, Entry] = {}
    with open(path, newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            word = (row.get("word") or "").strip()
            translation = (row.get("translation") or "").strip()
            if not word or not translation or not is_single_word(word):
                continue
            entry = Entry(
                word=word.lower(),
                display=word,
                translation=translation,
                frq=_int(row.get("frq")),
                bnc=_int(row.get("bnc")),
                exchange=parse_exchange(row.get("exchange", "")),
            )
            existing = entries.get(entry.word)
            if existing is None or entry.sort_key[:2] < existing.sort_key[:2]:
                entries[entry.word] = entry
    return entries


def build(input_path, output_path, max_words: int = 60000, source: str = "", license: str = "") -> int:
    entries = read_entries(Path(input_path))
    ranked = sorted(entries.values(), key=lambda e: e.sort_key)
    rank_of = {e.word: index + 1 for index, e in enumerate(ranked)}

    def gloss_of(entry: Entry) -> tuple[str, str | None]:
        lemma = entry.exchange.get("0", "").lower()
        if lemma and lemma in entries and not looks_like_definition(entry.translation):
            return short_gloss(entries[lemma].translation), lemma
        return short_gloss(entry.translation), None

    rows: dict[str, tuple[str, str, str | None, int]] = {}
    for entry in ranked[:max_words]:
        gloss, lemma = gloss_of(entry)
        if not gloss:
            continue
        rank = rank_of[entry.word]
        if lemma and entry.frq == 0 and entry.bnc == 0:
            rank = rank_of[lemma]
        rows[entry.word] = (entry.display, gloss, lemma, rank)

    # 展开收录词的变形；已经是独立条目的不覆盖
    for entry in ranked[:max_words]:
        if entry.word not in rows or rows[entry.word][2] is not None:
            continue
        display, gloss, _, rank = rows[entry.word]
        for kind in EXPAND_TYPES:
            form = entry.exchange.get(kind)
            if not form or not is_single_word(form):
                continue
            key = form.lower()
            if key in rows:
                continue
            rows[key] = (form, gloss, entry.word, rank)

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    db = sqlite3.connect(str(output))
    db.executescript(
        """
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE entry(
            word TEXT PRIMARY KEY,
            display TEXT NOT NULL,
            gloss TEXT NOT NULL,
            lemma TEXT,
            rank INTEGER NOT NULL
        ) WITHOUT ROWID;
        CREATE INDEX entry_rank ON entry(rank);
        """
    )
    db.executemany(
        "INSERT INTO entry(word, display, gloss, lemma, rank) VALUES (?, ?, ?, ?, ?)",
        [(word, *values) for word, values in sorted(rows.items())],
    )
    meta = {
        "format": FORMAT,
        "version": VERSION,
        "source": source,
        "license": license,
        "entries": str(len(rows)),
    }
    db.executemany("INSERT INTO meta(key, value) VALUES (?, ?)", sorted(meta.items()))
    db.commit()
    db.execute("VACUUM")
    db.close()
    return len(rows)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", required=True, help="ECDICT 的 ecdict.csv")
    parser.add_argument("--output", required=True, help="输出的 glossary.sqlite")
    parser.add_argument("--max-words", type=int, default=60000, help="按词频保留的原形词条数（变形另算）")
    parser.add_argument("--source", default="ECDICT https://github.com/skywind3000/ECDICT")
    parser.add_argument("--license", default="MIT")
    args = parser.parse_args(argv[1:])
    count = build(args.input, args.output, args.max_words, args.source, args.license)
    print(f"已生成 {args.output}：{count} 个词条")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
