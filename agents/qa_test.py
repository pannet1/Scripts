#!/usr/bin/env python3
"""
QA Test Runner — Full Feature Regression + Code Standards Audit.

Usage: python3 qa_test.py

Runs pytest on every feature listed in .features.json,
audits all .py files for code standard violations, and prints a report.
"""
import ast
import json
import subprocess
import sys
from pathlib import Path

REPO = Path.cwd()
_FEATURES_JSON = REPO / ".features.json"
FEATURES_FILE = _FEATURES_JSON if _FEATURES_JSON.exists() else REPO / ".agents" / "features.json"


def _get_features_dir() -> Path:
    if FEATURES_FILE.exists():
        try:
            cfg = json.loads(FEATURES_FILE.read_text())
            dir_name = cfg.get("features_dir", "features")
            return REPO / dir_name
        except Exception:
            pass
    return REPO / "features"


def _get_known_features() -> dict[str, str]:
    if FEATURES_FILE.exists():
        try:
            return json.loads(FEATURES_FILE.read_text()).get("known_features", {})
        except Exception:
            pass
    return {}


FEATURES_DIR = _get_features_dir()


def _should_skip(path: Path) -> bool:
    rel = path.relative_to(REPO)
    parts = rel.parts
    for skip in (".agents", "__pycache__", ".git", ".venv", ".mypy_cache", ".ruff_cache", "__init__.py"):
        if skip in parts:
            return True
    return False


def audit_py_file(path: Path) -> list[str]:
    text = path.read_text()
    violations: list[str] = []
    lines = text.splitlines()

    for i, line in enumerate(lines, 1):
        s = line.strip()
        if s and s[0] == "#" and "noqa" not in s and "# -*-" not in s and "#!/" not in s:
            violations.append(f"  comment at {path.name}:{i}")
            break

    for i, line in enumerate(lines, 1):
        s = line.strip()
        if "print(" in s and "logger" not in s and not s.startswith("#"):
            violations.append(f"  print() at {path.name}:{i}")
            break

    try:
        tree = ast.parse(text)
    except SyntaxError:
        violations.append(f"  syntax error in {path.name}")
        return violations

    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        fn = node.name
        if fn.startswith("test_"):
            continue
        if node.returns is None:
            violations.append(f"  {path.name}: {fn} missing return type")

        defaults = [None] * (len(node.args.args) - len(node.args.defaults)) + node.args.defaults
        for arg, default in zip(node.args.args, defaults):
            if arg.annotation is None:
                continue
            if isinstance(default, ast.Constant) and default.value is None:
                ann = arg.annotation
                if isinstance(ann, ast.Name) and ann.id != "Optional":
                    violations.append(f"  {path.name}: {fn} param {arg.arg} has bare {ann.id} = None")
                elif isinstance(ann, ast.Subscript):
                    pass
                elif isinstance(ann, ast.Attribute) and ann.attr != "Optional":
                    violations.append(f"  {path.name}: {fn} param {arg.arg} has bare {ann.attr} = None")
    return violations


def main() -> int:
    features = _get_known_features()

    all_passed: list[str] = []
    all_failed: list[str] = []
    all_violations: list[str] = []

    print("=" * 50)
    print(" QA Test Runner — Full Feature Regression")
    print("=" * 50)
    print()

    for py_file in sorted(REPO.glob("*.py")):
        if _should_skip(py_file):
            continue
        for v in audit_py_file(py_file):
            all_violations.append(f"    app/{v.lstrip()}")

    for name, domain in features.items():
        feat_dir = FEATURES_DIR / domain / name if domain else FEATURES_DIR / name
        test_file = feat_dir / "Tests.py"
        if not test_file.exists():
            continue

        print(f"  [{domain}/{name}]")

        for py_file in sorted(feat_dir.glob("*.py")):
            for v in audit_py_file(py_file):
                all_violations.append(f"    {domain}/{name}/{v}")

        result = subprocess.run(
            ["uv", "run", "pytest", str(test_file), "-v"],
            capture_output=True, text=True,
            cwd=str(REPO), timeout=120,
        )
        for line in result.stdout.splitlines():
            if " PASSED" in line:
                t = line.split("::")[-1].replace(" PASSED", "").strip()
                print(f"    PASS  {t}")
                all_passed.append(f"      {domain}/{name} :: {t}")
            elif " FAILED" in line:
                t = line.split("::")[-1].replace(" FAILED", "").strip()
                print(f"    FAIL  {t}")
                all_failed.append(f"      {domain}/{name} :: {t}")
        print()

    print("=" * 50)
    print(" Code Standards Violations")
    print("=" * 50)
    print()
    if all_violations:
        for v in sorted(set(all_violations)):
            print(v)
    else:
        print("  (none)")
    print()

    print("=" * 50)
    print(f" All Tests ({len(all_passed)} passed, {len(all_failed)} failed)")
    print("=" * 50)
    print()
    print("  Passing:")
    if all_passed:
        for p in all_passed:
            print(p)
    print()
    print("  Failing:")
    if all_failed:
        for f in all_failed:
            print(f)
    else:
        print("    (none)")
    print()

    n_features = sum(1 for n, d in features.items() if (FEATURES_DIR / d / n / "Tests.py" if d else FEATURES_DIR / n / "Tests.py").exists())
    print(f"{'=' * 50}")
    print(f" Summary: {len(all_passed)} passed, {len(all_failed)} failed, {n_features} feature slices")
    print(f"{'=' * 50}")

    return 1 if all_failed else 0


if __name__ == "__main__":
    sys.exit(main())
