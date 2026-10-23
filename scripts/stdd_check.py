#!/usr/bin/env python3
"""STDD 追溯检查：规格场景与测试互相对得上，变更的阶段、门记录和文件齐全。

规则见 docs/dev/stdd.md。用法：python3 scripts/stdd_check.py [仓库根目录]
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

PHASES = ["understand", "spec", "slice", "build", "verify", "deliver"]
# 到某个阶段（含）必须已有的门记录
GATE_REQUIRED_FROM = {"gate1": "spec", "gate2": "slice", "gate3": "deliver"}
# 到某个阶段（含）必须已有的文件
FILES_REQUIRED_FROM = {
    "proposal.md": "understand",
    "design.md": "spec",
    "test-plan.md": "spec",
    "tasks.md": "slice",
    "design-adjustments.md": "build",
    "test-report.md": "verify",
}
STUB_MARK = "stdd:todo"

SCENARIO_RE = re.compile(r"^(#{3,4}) 场景 \[([^\]]+)\] *(.*)$")
ID_RE = re.compile(r"^([a-z]+)\.(\d{2,3})$")
SWIFT_TEST_RE = re.compile(r"^\s*(?:@\w+\s+)*func (test_([a-z]+)_(\d{2,3})_\w*)\s*\(")
PY_TEST_RE = re.compile(r"^\s*def (test_([a-z]+)_(\d{2,3})_\w*)\s*\(")
FUNC_START_RE = re.compile(r"^\s*(?:@\w+\s+)*(?:func|def) ")


@dataclass
class Scenario:
    sid: str
    capability: str
    source: str
    manual: bool
    has_when: bool
    has_then_shall: bool
    section: str = ""  # 增量里的 新增 / 修改 / 删除；活规格为空


@dataclass
class TestRef:
    sid: str
    name: str
    source: str
    stub: bool


@dataclass
class Change:
    name: str
    path: Path
    archived: bool
    front: dict[str, str] = field(default_factory=dict)
    scenarios: list[Scenario] = field(default_factory=list)


def parse_front_matter(text: str) -> dict[str, str]:
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end < 0:
        return {}
    result = {}
    for line in text[3:end].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            result[key.strip()] = value.strip()
    return result


def parse_scenarios(text: str, capability: str, source: str, delta: bool) -> list[Scenario]:
    scenarios: list[Scenario] = []
    section = ""
    current: Scenario | None = None
    for line in text.splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            current = None
            continue
        match = SCENARIO_RE.match(line)
        if match:
            current = Scenario(
                sid=match.group(2).strip(),
                capability=capability,
                source=source,
                manual=False,
                has_when=False,
                has_then_shall=False,
                section=section if delta else "",
            )
            scenarios.append(current)
            continue
        if current is None:
            continue
        stripped = line.strip()
        if stripped.startswith("- WHEN"):
            current.has_when = True
        elif stripped.startswith("- THEN") and "SHALL" in stripped:
            current.has_then_shall = True
        elif stripped.startswith("- 验证：手动"):
            current.manual = True
    return scenarios


def collect_tests(root: Path) -> list[TestRef]:
    refs: list[TestRef] = []
    sources = [(p, SWIFT_TEST_RE, "XCTSkip") for p in sorted((root / "Tests").rglob("*.swift"))]
    sources += [(p, PY_TEST_RE, "skipTest") for p in sorted((root / "scripts" / "tests").glob("test_*.py"))]
    for path, pattern, _ in sources:
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            match = pattern.match(line)
            if not match:
                continue
            body = []
            for following in lines[index + 1:]:
                if FUNC_START_RE.match(following):
                    break
                body.append(following)
            refs.append(
                TestRef(
                    sid=f"{match.group(2)}.{match.group(3)}",
                    name=match.group(1),
                    source=str(path.relative_to(root)),
                    stub=STUB_MARK in "\n".join(body),
                )
            )
    return refs


def phase_at_least(phase: str, required: str) -> bool:
    if phase not in PHASES:
        return False
    return PHASES.index(phase) >= PHASES.index(required)


def check(root: Path) -> list[str]:
    errors: list[str] = []
    stdd = root / "stdd"

    live: dict[str, Scenario] = {}
    for spec in sorted((stdd / "specs").glob("*/spec.md")):
        capability = spec.parent.name
        for scenario in parse_scenarios(spec.read_text(encoding="utf-8"), capability, str(spec.relative_to(root)), False):
            if scenario.sid in live:
                errors.append(f"{scenario.source}: 场景 ID [{scenario.sid}] 在活规格里重复")
            live[scenario.sid] = scenario

    changes: list[Change] = []
    changes_dir = stdd / "changes"
    for path in sorted(changes_dir.glob("*")):
        if path.is_dir() and path.name != "archive":
            changes.append(Change(path.name, path, False))
    for path in sorted((changes_dir / "archive").glob("*")):
        if path.is_dir():
            changes.append(Change(path.name, path, True))

    active_new: dict[str, str] = {}
    for change in changes:
        proposal = change.path / "proposal.md"
        if proposal.exists():
            change.front = parse_front_matter(proposal.read_text(encoding="utf-8"))
        for delta in sorted((change.path / "specs").glob("*.md")):
            capability = delta.stem
            change.scenarios += parse_scenarios(
                delta.read_text(encoding="utf-8"), capability, str(delta.relative_to(root)), True
            )
        if change.archived:
            if not change.front.get("gate3"):
                errors.append(f"{change.path.relative_to(root)}: 已归档的变更缺 gate3 记录")
            continue
        for scenario in change.scenarios:
            if scenario.section == "新增":
                if scenario.sid in live:
                    errors.append(f"{scenario.source}: 新增的 [{scenario.sid}] 在活规格里已存在")
                if scenario.sid in active_new:
                    errors.append(f"{scenario.source}: 新增的 [{scenario.sid}] 与变更 {active_new[scenario.sid]} 重复")
                active_new[scenario.sid] = change.name
            elif scenario.section in ("修改", "删除"):
                if scenario.sid not in live:
                    errors.append(f"{scenario.source}: {scenario.section}的 [{scenario.sid}] 不在活规格里")
            else:
                errors.append(f"{scenario.source}: [{scenario.sid}] 不在 新增 / 修改 / 删除 标题下")

    # 场景格式
    all_defined = list(live.values()) + [s for c in changes if not c.archived for s in c.scenarios]
    for scenario in all_defined:
        match = ID_RE.match(scenario.sid)
        if not match:
            errors.append(f"{scenario.source}: 场景 ID [{scenario.sid}] 格式不对，应为 <能力>.<两到三位序号>")
            continue
        if match.group(1) != scenario.capability:
            errors.append(f"{scenario.source}: 场景 ID [{scenario.sid}] 的前缀与能力 {scenario.capability} 不一致")
        if scenario.section == "删除":
            continue
        if not scenario.has_when:
            errors.append(f"{scenario.source}: [{scenario.sid}] 缺 - WHEN 行")
        if not scenario.has_then_shall:
            errors.append(f"{scenario.source}: [{scenario.sid}] 的 - THEN 行缺大写 SHALL")

    tests = collect_tests(root)
    defined_ids = set(live) | {
        s.sid for c in changes if not c.archived for s in c.scenarios if s.section in ("新增", "修改")
    }
    removed_ids = {s.sid for c in changes if not c.archived for s in c.scenarios if s.section == "删除"}
    for ref in tests:
        if ref.sid not in defined_ids:
            errors.append(f"{ref.source}: {ref.name} 引用的 [{ref.sid}] 不存在于活规格或进行中的变更")

    real = {ref.sid for ref in tests if not ref.stub}
    any_ref = {ref.sid for ref in tests}

    for scenario in live.values():
        if scenario.manual or scenario.sid in removed_ids:
            continue
        if scenario.sid not in real:
            errors.append(f"{scenario.source}: 活规格场景 [{scenario.sid}] 没有真实测试")

    for change in changes:
        if change.archived:
            continue
        rel = change.path.relative_to(root)
        phase = change.front.get("phase", "")
        if phase not in PHASES:
            errors.append(f"{rel}/proposal.md: phase「{phase}」不是 {' / '.join(PHASES)} 之一")
            continue
        tier = change.front.get("tier", "full")
        if tier == "full":
            for gate, from_phase in GATE_REQUIRED_FROM.items():
                if phase_at_least(phase, from_phase) and not change.front.get(gate):
                    errors.append(f"{rel}/proposal.md: 阶段 {phase} 需要 {gate} 记录")
        for filename, from_phase in FILES_REQUIRED_FROM.items():
            if phase_at_least(phase, from_phase) and not (change.path / filename).exists():
                errors.append(f"{rel}: 阶段 {phase} 缺 {filename}")
        if phase_at_least(phase, "spec") and not list((change.path / "specs").glob("*.md")):
            errors.append(f"{rel}: 阶段 {phase} 缺 specs/<能力>.md")

        plan_path = change.path / "test-plan.md"
        plan = plan_path.read_text(encoding="utf-8") if plan_path.exists() else ""
        for scenario in change.scenarios:
            if scenario.section not in ("新增", "修改"):
                continue
            if phase_at_least(phase, "spec") and f"[{scenario.sid}]" not in plan:
                errors.append(f"{rel}/test-plan.md: 没有收录 [{scenario.sid}]")
            if scenario.manual:
                continue
            if phase == "build" and scenario.sid not in any_ref:
                errors.append(f"{scenario.source}: [{scenario.sid}] 在 build 阶段至少要有测试桩")
            if phase_at_least(phase, "verify") and scenario.sid not in real:
                errors.append(f"{scenario.source}: [{scenario.sid}] 在 {phase} 阶段必须有真实测试")
    return errors


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parent.parent
    errors = check(root)
    tests = collect_tests(root)
    stubs = sum(1 for t in tests if t.stub)
    if errors:
        for error in errors:
            print(f"✗ {error}")
        print(f"\nSTDD 检查失败：{len(errors)} 个问题")
        return 1
    print(f"✓ STDD 检查通过：{len(tests)} 条带场景 ID 的测试（桩 {stubs} 条）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
