import bz2
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import build_tatoeba_lm  # noqa: E402


def make_export(folder: Path, lines) -> Path:
    path = folder / "eng_sentences.tsv.bz2"
    with bz2.open(path, "wt", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    return path


SAMPLE = [
    "1\teng\tLet's try something.",
    "2\tfra\tEssayons.",
    "3\teng",
    "4\teng\tHow are you?",
    "5\teng\tHow are you doing?",
]


def meta(db_path: Path) -> dict:
    db = sqlite3.connect(str(db_path))
    try:
        return dict(db.execute("SELECT key, value FROM meta"))
    finally:
        db.close()


class TatoebaTests(unittest.TestCase):
    def setUp(self):
        self.folder = Path(tempfile.mkdtemp())

    def test_lmdata_11_only_english_sentence_text(self):
        export = make_export(self.folder, SAMPLE[:2])
        corpus = self.folder / "corpus.txt"
        count = build_tatoeba_lm.extract_sentences(export, corpus)
        self.assertEqual(count, 1)
        self.assertEqual(corpus.read_text(encoding="utf-8"), "Let's try something.\n")

    def test_lmdata_11_malformed_rows_skipped(self):
        export = make_export(self.folder, SAMPLE)
        corpus = self.folder / "corpus.txt"
        build_tatoeba_lm.extract_sentences(export, corpus)
        self.assertEqual(corpus.read_text(encoding="utf-8").splitlines(),
                         ["Let's try something.", "How are you?", "How are you doing?"])

    def test_lmdata_12_meta_records_corpus_date_and_license(self):
        export = make_export(self.folder, SAMPLE)
        output = self.folder / "ngram.sqlite"
        build_tatoeba_lm.build(export, output, downloaded="2026-11-25")
        values = meta(output)
        self.assertEqual(values["corpus"], "Tatoeba English sentences (downloaded 2026-11-25)")
        self.assertEqual(values["license"], "CC BY 2.0 FR")

    def test_lmdata_13_default_order_is_four(self):
        export = make_export(self.folder, SAMPLE)
        output = self.folder / "ngram.sqlite"
        build_tatoeba_lm.main(["build_tatoeba_lm.py", "--export", str(export), "--output", str(output),
                               "--downloaded", "2026-11-25"])
        self.assertEqual(meta(output)["order"], "4")


if __name__ == "__main__":
    unittest.main()
