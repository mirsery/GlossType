import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import stdd_check  # noqa: E402

PROPOSAL = """---
tier: full
phase: {phase}
gate1: {gate1}
gate2: {gate2}
gate3:
---

# 示例
"""

DELTA = """# 规格增量：demo

## 新增

#### 场景 [demo.01] 第一个

- WHEN 做某事
- THEN 系统 SHALL 有结果

#### 场景 [demo.02] 手动的

- WHEN 做某事
- THEN 系统 SHALL 有结果
- 验证：手动——需要真机
"""


class StddCheckTests(unittest.TestCase):
    def make_repo(self, phase="build", gate1="ok", gate2="ok", tests="", delta=DELTA, plan="[demo.01] [demo.02]"):
        root = Path(tempfile.mkdtemp())
        change = root / "stdd" / "changes" / "add-demo"
        (change / "specs").mkdir(parents=True)
        (root / "stdd" / "specs").mkdir(parents=True)
        (change / "proposal.md").write_text(PROPOSAL.format(phase=phase, gate1=gate1, gate2=gate2))
        for name in ("design.md", "tasks.md", "design-adjustments.md", "test-report.md"):
            (change / name).write_text("x")
        (change / "test-plan.md").write_text(plan)
        (change / "specs" / "demo.md").write_text(delta)
        (root / "Tests" / "DemoTests").mkdir(parents=True)
        (root / "Tests" / "DemoTests" / "DemoTests.swift").write_text(textwrap.dedent(tests))
        (root / "scripts" / "tests").mkdir(parents=True)
        return root

    def test_build_phase_accepts_stub(self):
        root = self.make_repo(tests="""
            func test_demo_01_first() throws {
                throw XCTSkip("stdd:todo")
            }
        """)
        self.assertEqual(stdd_check.check(root), [])

    def test_build_phase_requires_at_least_stub(self):
        root = self.make_repo(tests="")
        errors = stdd_check.check(root)
        self.assertTrue(any("[demo.01]" in e and "测试桩" in e for e in errors), errors)

    def test_verify_phase_rejects_stub(self):
        root = self.make_repo(phase="verify", tests="""
            func test_demo_01_first() throws {
                throw XCTSkip("stdd:todo")
            }
        """)
        errors = stdd_check.check(root)
        self.assertTrue(any("必须有真实测试" in e for e in errors), errors)

    def test_unknown_id_is_reported(self):
        root = self.make_repo(tests="""
            func test_demo_01_first() { XCTAssertTrue(true) }
            func test_demo_09_made_up() { XCTAssertTrue(true) }
        """)
        errors = stdd_check.check(root)
        self.assertTrue(any("[demo.09]" in e and "不存在" in e for e in errors), errors)

    def test_missing_gate_is_reported(self):
        root = self.make_repo(gate2="", tests="func test_demo_01_first() { }\n")
        errors = stdd_check.check(root)
        self.assertTrue(any("gate2" in e for e in errors), errors)

    def test_then_without_shall_is_reported(self):
        root = self.make_repo(delta=DELTA.replace("THEN 系统 SHALL 有结果\n\n####", "THEN 系统有结果\n\n####", 1),
                              tests="func test_demo_01_first() { }\n")
        errors = stdd_check.check(root)
        self.assertTrue(any("SHALL" in e for e in errors), errors)

    def test_test_plan_must_list_scenarios(self):
        root = self.make_repo(plan="[demo.01]", tests="func test_demo_01_first() { }\n")
        errors = stdd_check.check(root)
        self.assertTrue(any("[demo.02]" in e and "test-plan" in e for e in errors), errors)

    def test_repository_itself_passes(self):
        root = Path(__file__).resolve().parents[2]
        self.assertEqual(stdd_check.check(root), [])


if __name__ == "__main__":
    unittest.main()
