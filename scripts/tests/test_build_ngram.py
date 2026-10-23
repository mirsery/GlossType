import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import build_ngram  # noqa: E402

FIXTURE_CORPUS = HERE / "fixtures" / "tiny-corpus.txt"
SWIFT_FIXTURE = HERE.parents[1] / "Tests" / "GlossTypeCoreTests" / "Fixtures" / "tiny-ngram.sqlite"


def build(lines, **options):
    folder = Path(tempfile.mkdtemp())
    corpus = folder / "corpus.txt"
    corpus.write_text("\n".join(lines) + "\n", encoding="utf-8")
    out = folder / "ngram.sqlite"
    params = dict(order=3, min_count=1, top_k=50, max_vocab=100000, corpus_name="test", license="CC0")
    params.update(options)
    build_ngram.build(corpus, out, **params)
    return sqlite3.connect(str(out))


def continuations(db, context):
    return db.execute(
        """SELECT v.word, n.count FROM context c
           JOIN ngram n ON n.context_id = c.id JOIN vocab v ON v.id = n.word_id
           WHERE c.words = ? ORDER BY n.count DESC, v.word""",
        (context,),
    ).fetchall()


class TokenizeTests(unittest.TestCase):
    def test_lmdata_01_keep_contractions_drop_digits_and_punctuation(self):
        words = [w for w, _ in build_ngram.tokenize("I'm at home, 2 cats & a dog!")]
        self.assertEqual(words, ["i'm", "at", "home", "cats", "a", "dog"])


class BuildTests(unittest.TestCase):
    def test_lmdata_02_sentence_markers(self):
        db = build(["Hi there"])
        self.assertIn(("hi", 1), continuations(db, "<s>"))
        self.assertIn(("</s>", 1), continuations(db, "there"))

    def test_lmdata_03_prune_by_min_count(self):
        db = build(["how are you", "how are you", "how are they"], min_count=2)
        self.assertEqual(continuations(db, "how are"), [("you", 2)])

    def test_lmdata_04_top_k_per_context(self):
        lines = ["the cat"] * 5 + ["the dog"] * 4 + ["the car"] * 3 + ["the cup"] * 2 + ["the end"]
        db = build(lines, top_k=2)
        self.assertEqual(continuations(db, "the"), [("cat", 5), ("dog", 4)])

    def test_lmdata_05_display_uses_most_common_case(self):
        lines = ["so I said", "and I know", "then I left", "but I came", "yes I do", "maybe i will"]
        db = build(lines)
        self.assertEqual(db.execute("SELECT display FROM vocab WHERE word = 'i'").fetchone()[0], "I")

    def test_lmdata_06_meta_records_order_corpus_license(self):
        db = build(["hello there"], corpus_name="my corpus", license="CC BY 4.0")
        meta = dict(db.execute("SELECT key, value FROM meta"))
        self.assertEqual(meta["format"], "glosstype-ngram")
        self.assertEqual(meta["version"], "1")
        self.assertEqual(meta["order"], "3")
        self.assertEqual(meta["corpus"], "my corpus")
        self.assertEqual(meta["license"], "CC BY 4.0")

    def test_lmdata_07_context_total_counts_before_pruning(self):
        db = build(["how are you", "how are you", "how are they"], min_count=2)
        total = db.execute("SELECT total FROM context WHERE words = 'how are'").fetchone()[0]
        self.assertEqual(total, 3)

    def test_lmdata_10_swift_fixture_matches_script_output(self):
        fresh = build(FIXTURE_CORPUS.read_text(encoding="utf-8").splitlines(), corpus_name="tiny fixture", license="CC0")
        fixture = sqlite3.connect(str(SWIFT_FIXTURE))
        queries = [
            "SELECT word, display, count FROM vocab ORDER BY word",
            "SELECT words, total FROM context ORDER BY words",
            """SELECT c.words, v.word, n.count FROM ngram n JOIN context c ON c.id = n.context_id
               JOIN vocab v ON v.id = n.word_id ORDER BY c.words, v.word""",
            "SELECT key, value FROM meta WHERE key IN ('format', 'version', 'order') ORDER BY key",
        ]
        for query in queries:
            self.assertEqual(fixture.execute(query).fetchall(), fresh.execute(query).fetchall(), query)


if __name__ == "__main__":
    unittest.main()
