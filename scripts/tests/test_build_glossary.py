import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import build_glossary  # noqa: E402

FIXTURE_CSV = HERE / "fixtures" / "mini-ecdict.csv"
SWIFT_FIXTURE = HERE.parents[1] / "Tests" / "GlossTypeCoreTests" / "Fixtures" / "tiny-glossary.sqlite"


def build(max_words=60000):
    out = Path(tempfile.mkdtemp()) / "glossary.sqlite"
    build_glossary.build(FIXTURE_CSV, out, max_words=max_words, source="mini fixture", license="MIT")
    return sqlite3.connect(str(out))


def entry(db, word):
    return db.execute("SELECT display, gloss, lemma, rank FROM entry WHERE word = ?", (word,)).fetchone()


class ShortGlossTests(unittest.TestCase):
    def test_dictdata_01_strip_pos_and_take_three_senses(self):
        self.assertEqual(build_glossary.short_gloss("vi. 去, 走, 达到, 运转\\nvt. 以...打赌"), "去，走，达到")

    def test_dictdata_02_skip_domain_tag_lines(self):
        self.assertEqual(build_glossary.short_gloss("[计] 电流, 中断\\npron. 我"), "我")

    def test_dictdata_03_continue_on_next_line(self):
        self.assertEqual(build_glossary.short_gloss("n. 猫, 恶妇\\nvi. 呕吐"), "猫，恶妇，呕吐")


class BuildTests(unittest.TestCase):
    def test_dictdata_04_only_single_words(self):
        db = build()
        words = {row[0] for row in db.execute("SELECT word FROM entry WHERE lemma IS NULL")}
        self.assertIn("hello", words)
        self.assertIn("don't", words)
        self.assertIn("well-known", words)
        for rejected in ("ice cream", "3d", "-gate", "'hood"):
            self.assertNotIn(rejected, words)

    def test_dictdata_05_rank_by_frequency(self):
        db = build()
        ranks = [entry(db, w)[3] for w in ("help", "hello", "ahoy", "zzz")]
        self.assertEqual(ranks, sorted(ranks))
        self.assertEqual(len(set(ranks)), 4)

    def test_dictdata_06_keep_top_n(self):
        db = build(max_words=2)
        base = {row[0] for row in db.execute("SELECT word FROM entry WHERE lemma IS NULL")}
        self.assertEqual(base, {"the", "your"})

    def test_dictdata_07_duplicate_case_keeps_best_ranked(self):
        db = build()
        rows = db.execute("SELECT display, gloss FROM entry WHERE word = 'i'").fetchall()
        self.assertEqual(rows, [("I", "我")])

    def test_dictdata_08_expand_inflections(self):
        db = build()
        study = entry(db, "study")
        studies = entry(db, "studies")
        self.assertIsNotNone(studies)
        self.assertEqual(studies[1], study[1])
        self.assertEqual(studies[2], "study")

    def test_dictdata_09_inflection_without_real_gloss_uses_lemma(self):
        db = build()
        self.assertEqual(entry(db, "cats")[1], entry(db, "cat")[1])
        self.assertEqual(entry(db, "went")[1], entry(db, "go")[1])

    def test_dictdata_10_inflection_inherits_lemma_rank(self):
        db = build()
        self.assertEqual(entry(db, "went")[3], entry(db, "go")[3])

    def test_dictdata_11_meta_records_source_and_license(self):
        db = build()
        meta = dict(db.execute("SELECT key, value FROM meta"))
        self.assertEqual(meta["format"], "glosstype-glossary")
        self.assertEqual(meta["version"], "1")
        self.assertEqual(meta["source"], "mini fixture")
        self.assertEqual(meta["license"], "MIT")

    def test_dictdata_12_swift_fixture_matches_script_output(self):
        fresh = build()
        fixture = sqlite3.connect(str(SWIFT_FIXTURE))
        query = "SELECT word, display, gloss, lemma, rank FROM entry ORDER BY word"
        self.assertEqual(fixture.execute(query).fetchall(), fresh.execute(query).fetchall())
        meta_query = "SELECT key, value FROM meta WHERE key IN ('format', 'version') ORDER BY key"
        self.assertEqual(fixture.execute(meta_query).fetchall(), fresh.execute(meta_query).fetchall())


if __name__ == "__main__":
    unittest.main()
