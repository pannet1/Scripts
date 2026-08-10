import concurrent.futures
import re
from pathlib import Path
from typing import Any

from .config import REPO_ROOT, AGENTS_DIR
from .llm import default_model, llm_complete

PERSONA_PATH = AGENTS_DIR / "personas" / "compliance_agent.md"
PERSONA = PERSONA_PATH.read_text() if PERSONA_PATH.exists() else ""

EXCLUDE_DIRS: frozenset[str] = frozenset({
    ".venv", "venv", "env", ".env",
    "node_modules", "__pycache__", ".git",
    ".agents", ".tmp", ".pytest_cache",
    ".mypy_cache", ".ruff_cache",
})


def _is_python_code(text: str) -> bool:
    stripped = text.strip()
    return any(stripped.startswith(p) for p in (
        "import ", "from ", "def ", "class ", "async def ",
        "\"\"\"", "'''", "#!/usr", "from __future__",
        "print", "if __name__", "@",
    ))


def _extract_code(text: str) -> str | None:
    m = re.search(r"```python\s*\n(.*?)```", text, re.DOTALL)
    if m:
        return m.group(1).strip()
    m = re.search(r"```\s*\n(.*?)```", text, re.DOTALL)
    if m:
        return m.group(1).strip()
    cleaned = text.strip().strip("`").strip()
    if _is_python_code(cleaned):
        return cleaned
    return None


def _fix_file(persona: str, filepath: Path, rel: Path, content: str) -> dict:
    result = llm_complete(
        f"Scan and fix this file for compliance violations.\n"
        f"File: {rel}\n\n```python\n{content}\n```\n\n"
        f"Return the COMPLETE fixed file content inside a single ```python code block. No explanations.",
        system=persona,
        model=default_model(),
    )
    if not result:
        return {"path": str(rel), "error": True, "fixed": "", "changed": False}

    fixed = _extract_code(result.strip())
    if fixed is None:
        return {"path": str(rel), "error": True, "fixed": "", "changed": False}

    changed = fixed != content.strip()
    return {"path": str(rel), "error": False, "fixed": fixed, "changed": changed}


def _py_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for p in root.rglob("*.py"):
        if any(part in EXCLUDE_DIRS for part in p.parts):
            continue
        files.append(p)
    return sorted(files)


BATCH_SIZE = 5


def run_compliance_scan() -> None:
    if not PERSONA:
        print("[Compliance] Missing compliance_agent.md persona")
        return

    files = _py_files(REPO_ROOT)
    if not files:
        print("[Compliance] No .py files found")
        return

    print(f"[Compliance] Scanning {len(files)} files (batch size {BATCH_SIZE})...")
    changed = 0
    errors = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=BATCH_SIZE) as executor:
        futures = []
        for fp in files:
            rel = fp.relative_to(REPO_ROOT)
            content = fp.read_text()
            if not content.strip():
                continue
            futures.append(executor.submit(_fix_file, PERSONA, fp, rel, content))

        for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
            result = future.result()
            rel = result["path"]
            status = "ERROR" if result["error"] else ("FIXED" if result["changed"] else "ok")
            print(f"[Compliance] [{i}/{len(files)}] {rel} ... {status}", flush=True)
            if result["changed"]:
                fp = REPO_ROOT / rel
                fp.write_text(result["fixed"] + "\n")
                changed += 1
            if result["error"]:
                errors += 1

    print(f"\n[Compliance] Done: {changed} fixed, {errors} errors")


if __name__ == "__main__":
    run_compliance_scan()
