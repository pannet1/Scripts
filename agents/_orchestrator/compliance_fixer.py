"""Two-phase compliance fixer: mechanical transforms then AI only on violators."""
import ast
import concurrent.futures
import re
import uuid
from pathlib import Path
from typing import Any

from .config import REPO_ROOT
from .compliance_scanner import _py_files, PERSONA as SCANNER_PERSONA
from .zen_api import _zen_api_key, _zen_model, _zen_session_id, _zen_chat


def _fresh_headers() -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + _zen_api_key(),
        "x-opencode-project": str(uuid.uuid4()),
        "x-opencode-session": _zen_session_id(),
        "x-opencode-request": str(uuid.uuid4()),
        "x-opencode-client": "python-script",
        "User-Agent": "opencode/1.15.4",
    }


def _ai_fix_file(headers: dict, persona: str, rel: Path, content: str) -> dict:
    """Like compliance_scanner._fix_file but with higher token limit."""
    import json
    payload = {
        "model": _zen_model(),
        "messages": [
            {"role": "system", "content": persona},
            {"role": "user", "content": (
                f"Scan and fix this file for compliance violations.\n"
                f"File: {rel}\n\n```python\n{content}\n```\n\n"
                f"Return the COMPLETE fixed file content inside a single ```python code block. No explanations."
            )},
        ],
        "max_tokens": 16384,
        "temperature": 0.1,
    }
    result = _zen_chat(headers, payload)
    if not result:
        return {"path": str(rel), "error": True}

    # Extract code block (same logic as compliance_scanner._extract_code)
    text = result.strip()
    m = re.search(r"```python\s*\n(.*?)```", text, re.DOTALL)
    if m:
        fixed = m.group(1).strip()
    else:
        m = re.search(r"```\s*\n(.*?)```", text, re.DOTALL)
        if m:
            fixed = m.group(1).strip()
        else:
            cleaned = text.strip().strip("`").strip()
            if any(cleaned.startswith(p) for p in (
                "import ", "from ", "def ", "class ", "async def ",
                "\"\"\"", "'''", "#!/usr", "from __future__",
            )):
                fixed = cleaned
            else:
                return {"path": str(rel), "error": True}

    changed = fixed != content.strip()
    return {"path": str(rel), "error": False, "fixed": fixed, "changed": changed}

EMOJI_PATTERN = re.compile(
    "[\U0001F600-\U0001F64F"
    "\U0001F300-\U0001F5FF"
    "\U0001F680-\U0001F6FF"
    "\U0001F1E0-\U0001F1FF"
    "\U00002702-\U000027B0"
    "\U000024C2-\U0001F251"
    "\U0001F900-\U0001F9FF"
    "\U0001FA00-\U0001FA6F"
    "\U0001FA70-\U0001FAFF"
    "\U00002600-\U000026FF"
    "\U0000FE00-\U0000FE0F"
    "\U0000200D"
    "]"
)

EXCLUDE_DIRS: frozenset[str] = frozenset({
    ".venv", "venv", "env", ".env", "node_modules",
    "__pycache__", ".git", ".agents", ".tmp",
    ".pytest_cache", ".mypy_cache", ".ruff_cache",
})


def _check_has_violations(fp: Path) -> bool:
    """Quick static check: does this file still have any fixable violations?"""
    text = fp.read_text()
    if re.search(r"^import logging(?:\s|$)", text, re.MULTILINE):
        return True
    if "from __future__ import annotations" not in text:
        return True
    for mod in ("datetime", "time", "calendar"):
        if re.search(rf"^import {mod}(?:\s|$)", text, re.MULTILINE):
            return True
    if re.search(r"\bprint\s*\(", text):
        return True
    try:
        tree = ast.parse(text)
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if not node.returns:
                    return True
                for arg in node.args.args + node.args.kwonlyargs + [node.args.vararg, node.args.kwarg]:
                    if arg and arg.arg not in ("self", "cls") and arg.annotation is None:
                        return True
    except SyntaxError:
        return True
    return False


# ---------------------------------------------------------------------------
# Phase 1: Mechanical transforms
# ---------------------------------------------------------------------------

def _fix_import_logging(text: str) -> str:
    result = re.sub(
        r"^import logging\s*(?:#[^\n]*)?$",
        "from shared.logger import logging_func\nlogger = logging_func(__name__)",
        text,
        flags=re.MULTILINE,
    )
    return result


def _fix_future_annotations(text: str) -> str:
    if "from __future__ import annotations" in text:
        return text
    lines = text.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if i == 0 and line.startswith("#!"):
            insert_at = i + 1
            continue
        if line.startswith(('"""', "'''")):
            insert_at = i + 1
            continue
        if not line.strip():
            insert_at = i + 1
            continue
        break
    insert_at = max(insert_at, 0)
    lines.insert(insert_at, "from __future__ import annotations")
    if insert_at + 1 < len(lines) and lines[insert_at + 1].strip():
        lines.insert(insert_at + 1, "")
    return "\n".join(lines)


def _fix_comment_lines(text: str) -> str:
    in_docstring = False
    out_lines: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith(('"""', "'''")):
            count = stripped.count('"""' if stripped.startswith('"""') else "'''")
            if count % 2 == 1:
                in_docstring = not in_docstring
            out_lines.append(line)
            continue
        if in_docstring:
            out_lines.append(line)
            continue
        if stripped.startswith("#!/"):
            out_lines.append(line)
            continue
        if "#" in stripped:
            idx = stripped.index("#")
            before = stripped[:idx].strip()
            if not before:
                continue
        out_lines.append(line)
    return "\n".join(out_lines)


def _fix_emojis(text: str) -> str:
    return EMOJI_PATTERN.sub("", text)


def _mechanical_fix(fp: Path) -> bool:
    original = fp.read_text()
    text = original
    text = _fix_import_logging(text)
    text = _fix_future_annotations(text)
    text = _fix_comment_lines(text)
    text = _fix_emojis(text)
    if text != original:
        fp.write_text(text + "\n")
    return text != original


def run_mechanical_phase() -> tuple[int, int]:
    files = _py_files(REPO_ROOT)
    fixed = 0
    for fp in files:
        if _mechanical_fix(fp):
            fixed += 1
    print(f"[Fixer] Phase-1 (mechanical): {fixed}/{len(files)} files fixed")
    return fixed, len(files)


# ---------------------------------------------------------------------------
# Phase 2: AI fixes (only on files with remaining violations)
# ---------------------------------------------------------------------------

def _validate_syntax(text: str, original_lines: int) -> bool:
    try:
        ast.parse(text)
    except SyntaxError:
        return False
    current_lines = text.count("\n") + 1
    if current_lines < original_lines * 0.5:
        return False
    return True


def run_ai_phase() -> tuple[int, int, int]:
    """Phase-2: AI-fix only files that still have violations after mechanical phase."""
    if not SCANNER_PERSONA:
        print("[Fixer] Missing compliance_agent.md persona -- skipping AI phase")
        return 0, 0, 0

    files = _py_files(REPO_ROOT)
    violators = [fp for fp in files if _check_has_violations(fp) and fp.name not in ("test_compliance.py", "conftest.py")]
    clean = len(files) - len(violators)

    if not violators:
        print(f"[Fixer] Phase-2 (AI): all {len(files)} files already clean, skipping")
        return 0, 0, 0

    headers = None
    fixed = 0
    failures: list[str] = []
    skipped = len(files) - len(violators)

    print(f"[Fixer] Phase-2 (AI): {len(violators)} violators of {len(files)} files (skipping {skipped} clean)...")

    def _process(fp: Path) -> dict:
        rel = fp.relative_to(REPO_ROOT)
        content = fp.read_text()
        original_lines = content.count("\n") + 1
        headers = _fresh_headers()
        result = _ai_fix_file(headers, SCANNER_PERSONA, rel, content)
        if result.get("error"):
            return {"path": str(rel), "status": "FAILED (API error)"}
        if not result.get("changed"):
            return {"path": str(rel), "status": "ok"}
        fixed_text = result["fixed"]
        if not _validate_syntax(fixed_text, original_lines):
            return {"path": str(rel), "status": "FAILED (syntax/truncation)"}
        fp.write_text(fixed_text + "\n")
        return {"path": str(rel), "status": "fixed"}

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(_process, fp): fp for fp in violators}
        for future in concurrent.futures.as_completed(futures):
            out = future.result()
            status = out["status"]
            if status.startswith("FAILED"):
                failures.append(out["path"])
            elif status == "fixed":
                fixed += 1
            print(f"  [AI] {out['path']} {status}")

    if failures:
        print(f"[Fixer] AI failures ({len(failures)}):")
        for f in failures:
            print(f"  - {f}")
    print(f"[Fixer] Phase-2: {fixed} fixed, {len(failures)} failures, {clean} clean")
    return fixed, len(failures), clean


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

def fix_all() -> dict[str, Any]:
    """Full two-phase compliance fix. Report at end."""
    print("[Fixer] === Phase 1: Mechanical transforms ===")
    mech_fixed, mech_total = run_mechanical_phase()

    print()
    print("[Fixer] === Phase 2: AI fixes (violators only) ===")
    ai_fixed, ai_failures, ai_clean = run_ai_phase()

    report = {
        "mechanical_fixed": mech_fixed,
        "mechanical_skipped": mech_total - mech_fixed,
        "ai_fixed": ai_fixed,
        "ai_failures": ai_failures,
        "ai_clean": ai_clean,
        "total_unresolved": ai_failures,
    }
    print(f"\n[Fixer] Result: {mech_fixed} mechanical, {ai_fixed} AI-fixed, {ai_failures} unresolved, {ai_clean} clean")
    return report
