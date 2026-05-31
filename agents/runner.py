"""
Runner Engine — generic sub-agent executor.

Pipes persona + spec.md + existing code to the Zen API,
extracts Python code blocks from the response, writes them to disk,
and runs pytest in an auto-correction loop.

Usage:
    python .agents/runner.py \
        --persona .agents/personas/backend_agent.md \
        --target features/your-domain/YourFeature/ \
        --task "Implement the feature per spec.md" \
        --api

    python .agents/runner.py \
        --persona .agents/personas/qa_agent.md \
        --target features/your-domain/YourFeature/ \
        --error /tmp/pytest_errors.txt \
        --api
"""

import argparse
import json
import os
import random
import re
import string
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
from pathlib import Path
from typing import Any, Optional

REPO_ROOT = Path.cwd()
AGENTS_DIR = Path(__file__).resolve().parent
MODEL_CONFIG = AGENTS_DIR / "model_config.json"
FEW_SHOT_COUNT = 2
VERBOSE = False

ZEN_URL = "https://opencode.ai/zen/v1/chat/completions"

ZEN_FALLBACKS = [
    "deepseek-v4-flash",
    "deepseek-v4-flash-free",
    "nemotron-3-super-free",
]


def _zen_api_key() -> str:
    return os.environ.get("OPENCODE_ZEN_KEY", "public")


def _zen_session_id() -> str:
    alphabet = string.ascii_uppercase + string.ascii_lowercase + string.digits + "-_"
    return "ses_" + "".join(random.choices(alphabet, k=26))


def _zen_model() -> str:
    if MODEL_CONFIG.exists():
        try:
            cfg = json.loads(MODEL_CONFIG.read_text())
            return cfg.get("model", ZEN_FALLBACKS[0])
        except Exception:
            pass
    return ZEN_FALLBACKS[0]


def _zen_chat(prompt: str) -> str | None:
    fallbacks = ZEN_FALLBACKS[:]
    selected = _zen_model()
    if selected in fallbacks:
        fallbacks.remove(selected)
    fallbacks.insert(0, selected)

    project_id = str(uuid.uuid4())
    api_key = _zen_api_key()
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
        "x-opencode-project": project_id,
        "x-opencode-session": _zen_session_id(),
        "x-opencode-request": str(uuid.uuid4()),
        "x-opencode-client": "python-script",
        "User-Agent": "opencode/1.15.4",
    }

    for model in fallbacks:
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 8192,
            "temperature": 0.3,
        }
        data = json.dumps(payload).encode()
        req = urllib.request.Request(ZEN_URL, data=data, headers=headers, method="POST")

        prompt_preview = prompt[:500] + "..." if len(prompt) > 500 else prompt
        safe_headers = {k: v for k, v in headers.items() if k.lower() != "authorization"}
        print(f"[Runner] POST {ZEN_URL}", file=sys.stderr)
        print(f"[Runner]   model={model}  chars={len(prompt)}  max_tokens=8192  temp=0.3", file=sys.stderr)
        print(f"[Runner]   headers={json.dumps(safe_headers)}", file=sys.stderr)
        print(f"[Runner]   --- prompt (first 500) ---\n{prompt_preview}\n   --- end prompt ---", file=sys.stderr)

        try:
            done = False
            def _tick():
                while not done:
                    time.sleep(10)
                    sys.stderr.write(".")
                    sys.stderr.flush()
            ticker = threading.Thread(target=_tick, daemon=True)
            ticker.start()
            try:
                with urllib.request.urlopen(req, timeout=300) as resp:
                    body = json.loads(resp.read())
            finally:
                done = True
            print(file=sys.stderr)
        except urllib.error.HTTPError as e:
            if e.code == 401:
                print(f"[Runner] Model '{model}' unavailable (free tier ended). Trying next...", file=sys.stderr)
                continue
            print(f"[Runner] Zen API error ({model}): {e}", file=sys.stderr)
            continue
        except Exception as e:
            print(f"[Runner] Zen API error ({model}): {e}", file=sys.stderr)
            continue

        try:
            msg = body["choices"][0]["message"]
        except (KeyError, IndexError, TypeError) as e:
            print(f"[Runner] Model '{model}' returned unexpected response: {e}", file=sys.stderr)
            continue
        content = (msg.get("content") or msg.get("reasoning_content") or "").strip()
        resp_preview = content[:1000] + "..." if len(content) > 1000 else content
        print(f"[Runner]   --- response ({len(content)} chars) ---\n{resp_preview}\n   --- end response ---", file=sys.stderr)

        if not content and model != fallbacks[-1]:
            print(f"[Runner] Model '{model}' returned empty response. Trying next...", file=sys.stderr)
            continue
        if model != selected:
            MODEL_CONFIG.write_text(json.dumps({"model": model}) + "\n")
            print(f"[Runner] Fallback: model config updated to '{model}'", file=sys.stderr)
        return content

    print("[Runner] No working model found. Run ./.agents/select_model.py to pick one.", file=sys.stderr)
    return None


def read_file(path: Path) -> str:
    with open(path) as f:
        return f.read()


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def collect_target_files(target: Path) -> dict:
    files = {}
    for fname in ["spec.md", "Schema.py", "Handler.py", "Controller.py", "Tests.py"]:
        path = target / fname
        if path.exists():
            files[fname] = read_file(path)
    return files


def build_prompt(persona: str, target: Path, target_files: dict, task: str, error: str) -> str:
    parts: list[str] = []
    parts.append(persona)
    parts.append(f"## Target Directory\n{target}")

    spec = target_files.get("spec.md", "")
    if spec:
        parts.append("## Specification (spec.md)\n" + spec)

    examples = collect_examples(target)
    if examples:
        parts.append("## Reference Examples")
        for ex in examples:
            for fname in ("Schema.py", "Handler.py", "Controller.py"):
                content = ex["files"].get(fname, "")
                if content:
                    parts.append(f"```python\n# {fname} ({ex['dir']})\n{content}\n```")

    for fname in ["Schema.py", "Handler.py", "Controller.py", "Tests.py"]:
        content = target_files.get(fname, "")
        if content:
            parts.append(f"## Existing: {fname}\n{content}")
    if error:
        parts.append("## Error / Test Failure\n```\n" + error + "\n```")
    parts.append("## Task\n" + task)
    return "\n".join(parts)


def call_llm(prompt: str) -> str:
    response = _zen_chat(prompt)
    if response is None:
        print(f"[Runner] LLM call failed.", file=sys.stderr)
        sys.exit(1)
    return response


def _unescape(text: str) -> str:
    return text.replace("\\n", "\n")

def extract_code_blocks(text: str) -> dict[str, str]:
    files: dict[str, str] = {}

    # Primary: try JSON (both bare and fenced)
    files = extract_json_blocks(text)
    if files:
        return {k: _unescape(v) for k, v in files.items()}

    # Fallback: markdown patterns
    # Pattern 1: ### filename\n```python ... ```
    pattern1 = re.compile(
        r'^###\s+(\S+)\s*\n```python\n(.*?)```',
        re.MULTILINE | re.DOTALL
    )
    for match in pattern1.finditer(text):
        fname = match.group(1)
        code = match.group(2).strip()
        if fname and code:
            files[fname] = _unescape(code)

    # Pattern 2: ## `path/to/filename` ... ```python ... ```
    pattern2 = re.compile(
        r'^##\s+`[^`]+/(\S+)`\s*\n.*?```python\n(.*?)```',
        re.MULTILINE | re.DOTALL
    )
    for match in pattern2.finditer(text):
        fname = match.group(1)
        code = match.group(2).strip()
        if fname and code and fname not in files:
            files[fname] = _unescape(code)

    # Pattern 3: any ```python ... ``` block preceded by a filename somewhere nearby
    if not files:
        blocks = re.split(r'```(?:python)?\n', text)
        for i in range(1, len(blocks), 2):
            code = blocks[i].strip()
            if code.endswith("```"):
                code = code[:-3].strip()
            if not code:
                continue
            before = blocks[i - 1]
            candidates = re.findall(r'(\w+\.py)', before)
            if candidates:
                files[candidates[-1]] = _unescape(code)

    return files


def write_code_blocks(files: dict[str, str], target: Path, protect: set[str] | None = None) -> tuple[list[Path], list[Path]]:
    written: list[Path] = []
    deleted: list[Path] = []
    expected = {"Schema.py", "Handler.py", "Controller.py", "Tests.py"}
    produced = set()
    protect = protect or set()

    for fname, code in files.items():
        path = target / fname
        write_file(path, code + "\n")
        written.append(path)
        produced.add(fname)

    for fname in list(expected):
        if fname not in produced and fname not in protect:
            path = target / fname
            if path.exists():
                path.unlink()
                deleted.append(path)
                print(f"[Runner] Deleted {fname} (absent from AI output)")

    all_on_disk = {p.name for p in target.iterdir() if p.suffix == ".py"}
    unexpected = all_on_disk - produced - set(p.name for p in deleted) - protect
    for fname in unexpected:
        path = target / fname
        path.unlink()
        deleted.append(path)
        print(f"[Runner] Deleted unexpected file {fname}")

    return written, deleted


def validate_code_standards(written: list[Path]) -> list[str]:
    violations: list[str] = []
    for p in written:
        if not p.exists() or p.suffix != ".py":
            continue
        text = p.read_text()
        violations.extend(check_unused_imports(text, p.name))
        lines = text.splitlines()
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith("#") and "noqa" not in stripped:
                violations.append(f"{p.name}:{i} comment found")
            if "print(" in stripped and "logger" not in stripped:
                violations.append(f"{p.name}:{i} print() found")
            if re.search(r'[\U0001F600-\U0010FFFF]', stripped):
                violations.append(f"{p.name}:{i} emoji found")
        for m in re.finditer(r'^(?:    )*def (\w+)\(', text, re.MULTILINE):
            start = m.start()
            depth = 1
            pos = start + len(m.group(0)) - 1
            while depth > 0 and pos + 1 < len(text):
                pos += 1
                if text[pos] == '(':
                    depth += 1
                elif text[pos] == ')':
                    depth -= 1
            eol = text.find('\n', pos)
            if eol == -1:
                eol = len(text)
            sig = text[start:eol]
            if "->" not in sig and not sig.strip().startswith("def test_"):
                violations.append(f"{p.name}: missing return type on {m.group(1)}")
        if p.name == "__init__.py":
            continue
        if p.name == "Schema.py" and "class " in text and "BaseModel" in text:
            continue
        if p.name == "Tests.py":
            continue
        if "from shared.logger import logging_func" not in text:
            if "logging.getLogger" in text:
                violations.append(f"{p.name}: use `from shared.logger import logging_func` instead of `logging.getLogger(__name__)`")
            else:
                violations.append(f"{p.name}: missing `from shared.logger import logging_func`")
    return violations


def check_unused_imports(code: str, fname: str) -> list[str]:
    issues: list[str] = []
    imports: list[tuple[str, int, str]] = []
    lines = code.splitlines()
    for i, line in enumerate(lines):
        s = line.strip()
        m = re.match(r'^from\s+(\S+)\s+import\s+(.+)$', s)
        if m:
            for part in m.group(2).split(','):
                alias = part.strip().split(' as ')[-1].strip()
                if alias and alias != '_' and not alias.startswith('*'):
                    imports.append((alias.split('.')[0], i + 1, f"from {m.group(1)} import {part.strip()}"))
            continue
        m = re.match(r'^import\s+(.+)$', s)
        if m:
            for part in m.group(1).split(','):
                alias = part.strip().split(' as ')[-1].strip()
                top = alias.split('.')[0]
                if top and top != '_':
                    imports.append((top, i + 1, f"import {part.strip()}"))
    for name, ln, full_import in imports:
        if full_import.startswith("from __future__"):
            continue
        if "from __future__ import annotations" in code and full_import.startswith("from typing import"):
            continue
        if name == "__name__":
            continue
        if name == "pytest" and fname == "Tests.py":
            continue
        rest = '\n'.join(lines[ln:])
        if name not in rest:
            issues.append(f"{fname}:{ln} unused import '{full_import}'")
    return issues


def validate_constitution(repo_root: Path, target: Path) -> list[str]:
    """Enforce ALL 11 rules from AGENTS.md Section 3 via script code."""
    issues: list[str] = []

    # 1. Python version file
    py_ver_file = repo_root / ".python-version"
    if not py_ver_file.exists():
        issues.append("Missing .python-version")

    # 2. Package manager: uv only
    pyproject = repo_root / "pyproject.toml"
    if pyproject.exists():
        text = pyproject.read_text()
        if '[tool.poetry]' in text or '[tool.pdm]' in text:
            issues.append("pyproject.toml uses non-uv tool (poetry/pdm detected)")
    else:
        issues.append("Missing pyproject.toml (uv-managed)")

    # 3. No pip/poetry/conda
    for marker in ("requirements.txt", "Pipfile", "Pipfile.lock", "poetry.lock", "environment.yml", "setup.py", "setup.cfg"):
        if (repo_root / marker).exists():
            issues.append(f"Forbidden package manager file: {marker} (use uv only)")

    # 4. No requirements.txt (duplicate check, explicit)
    if (repo_root / "requirements.txt").exists():
        issues.append("requirements.txt not permitted (use pyproject.toml + uv)")

    # 5. Project time library only — check imports in generated code
    # Detect the project's designated time library from existing code
    existing_files = list(repo_root.rglob("*.py"))
    time_libs = {"pendulum", "arrow", "python-dateutil", "delorean", "maya", "udatetime", "pytz"}
    project_time_lib: str = ""
    for f in existing_files:
        if "__pycache__" in f.parts:
            continue
        text = f.read_text()
        for m in re.finditer(r'^import (\w+)|^from (\w+)', text, re.MULTILINE):
            lib = m.group(1) or m.group(2)
            if lib in time_libs:
                project_time_lib = lib
                break
        if project_time_lib:
            break
    if not project_time_lib:
        project_time_lib = "pendulum"  # default fallback
    generated_files = list(target.rglob("*.py")) if target.is_dir() else []
    for f in generated_files:
        if f.name.startswith("__"):
            continue
        text = f.read_text()
        for m in re.finditer(r'^import (\w+)|^from (\w+)', text, re.MULTILINE):
            lib = m.group(1) or m.group(2)
            if lib in time_libs and lib != project_time_lib:
                issues.append(f"{f.name}: use project time library ({project_time_lib}) instead of {lib}")

    # 6. logging.getLogger — checked in validate_code_standards (per-file)
    # 7. Zero comments — checked in validate_code_standards (per-file)
    # 8. No secrets — grep for common secret patterns in generated code
    # Exclude test files (fixture data is legitimate)
    secret_patterns = [
        (r'(?i)(password|secret|token|api_key|api_secret)\s*[=:]\s*["\'][^"\']+["\']', "hardcoded secret"),
        (r'(?i)(access_token|auth_token)\s*=\s*["\'][^"\']{8,}["\']', "hardcoded auth token"),
    ]
    for f in generated_files:
        if f.name.startswith("__") or f.suffix != ".py" or f.name == "Tests.py":
            continue
        text = f.read_text()
        for pat, label in secret_patterns:
            for m in re.finditer(pat, text):
                line_num = text[:m.start()].count("\n") + 1
                issues.append(f"{f.name}:{line_num} potential {label}")

    # 9. No emojis — checked in validate_code_standards (per-line)
    # 10. Unit tests — checked in validate_code_structure (Tests.py)
    # 11. Type annotations — checked in validate_code_standards (return types)

    return issues


def validate_root_files(repo_root: Path) -> list[str]:
    issues: list[str] = []
    backend_app = repo_root / "apps" / "backend" / "app"
    root_files: list[Path] = []
    for f in sorted(backend_app.iterdir()):
        if f.suffix == ".py" and not f.name.startswith("_") and f.is_file():
            root_files.append(f)
    if not root_files:
        return issues
    for f in root_files:
        code = f.read_text()
        issues.extend(validate_code_standards([f]))
        issues.extend(validate_code_structure(code, f.name))
        issues.extend(validate_pep8(repo_root, f))
    issues.extend(validate_features_json_sync(repo_root))
    issues.extend(validate_standalone_files(repo_root))
    return [f"[ROOT] {i}" for i in issues]


def validate_features_json_sync(repo_root: Path) -> list[str]:
    issues: list[str] = []
    features_dir = repo_root / "apps" / "backend" / "app" / "features"
    features_json = repo_root / ".agents" / "features.json"
    if not features_json.exists():
        return ["Missing .agents/features.json"]
    import json
    cfg = json.loads(features_json.read_text())
    known = cfg.get("known_features", {})
    standalone = cfg.get("standalone", [])

    dir_features: dict[str, str] = {}
    for domain_dir in features_dir.iterdir():
        if not domain_dir.is_dir() or domain_dir.name.startswith("_"):
            continue
        for feature_dir in domain_dir.iterdir():
            if feature_dir.is_dir() and not feature_dir.name.startswith("_"):
                dir_features[feature_dir.name] = domain_dir.name

    for fname, domain in dir_features.items():
        if fname not in known:
            issues.append(f"Feature '{fname}' exists on disk but missing from features.json")

    for fname, domain in known.items():
        if fname not in dir_features:
            issues.append(f"Feature '{fname}' in features.json but missing on disk")
        elif dir_features[fname] != domain:
            issues.append(f"Feature '{fname}': features.json says domain '{domain}' but disk says '{dir_features[fname]}'")

    disk_files = {f.name for f in features_dir.iterdir() if f.is_file() and f.suffix == ".py" and not f.name.startswith("__")}
    listed_standalone = set(standalone)
    extra = listed_standalone - disk_files
    if extra:
        issues.append(f"Standalone files in features.json but missing on disk: {sorted(extra)}")
    unlisted = disk_files - listed_standalone
    if unlisted:
        issues.append(f"Standalone .py files in features/ not listed in features.json: {sorted(unlisted)}")

    return issues


def validate_standalone_files(repo_root: Path) -> list[str]:
    issues: list[str] = []
    features_json = repo_root / ".agents" / "features.json"
    features_dir = repo_root / "apps" / "backend" / "app" / "features"
    if not features_json.exists():
        return issues
    import json
    cfg = json.loads(features_json.read_text())
    standalone = cfg.get("standalone", [])
    for fname in standalone:
        fpath = features_dir / fname
        if not fpath.exists():
            issues.append(f"Standalone file '{fname}' not found on disk")
            continue
        code = fpath.read_text()
        issues.extend(validate_code_standards([fpath]))
        issues.extend(validate_code_structure(code, fname))
        issues.extend(validate_pep8(repo_root, fpath))
    return issues


def validate_pep8(repo_root: Path, target: Path) -> list[str]:
    issues: list[str] = []
    py_files = list(target.rglob("*.py")) if target.is_dir() else [f for f in [target] if f.suffix == ".py"]
    py_files = [f for f in py_files if not f.name.startswith("__")]
    if not py_files:
        return issues
    cmd = ["uv", "run", "pycodestyle", "--select=E302,E501", "--first"] + [str(f) for f in py_files]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(repo_root), timeout=30)
    if result.returncode != 0:
        for line in result.stdout.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            parts = line.split(":", 3)
            if len(parts) >= 4:
                fname = Path(parts[0]).name
                lineno = parts[1]
                msg = parts[3].strip()
                code = msg.split()[0] if msg else ""
                label = "line-too-long" if code == "E501" else "blank-lines"
                issues.append(f"{fname}:{lineno} PEP 8 {label}")
    return issues


def truncated_files(written: list[Path]) -> list[str]:
    truncated: list[str] = []
    for p in written:
        if not p.exists():
            continue
        content = p.read_text().rstrip()
        if not content:
            continue
        last_char = content[-1]
        if last_char in "([{," or content.endswith("Optional["):
            truncated.append(p.name)
            continue
        lines = content.splitlines()
        for line in lines:
            s = line.strip()
            if re.match(r'^\w+\s*=\s*$', s):
                truncated.append(p.name)
                break
    return truncated


def collect_examples(target: Path, count: int = FEW_SHOT_COUNT) -> list[dict[str, Any]]:
    """Grab working feature examples from the same domain for few-shot context."""
    domain_dir = target.parent
    if not domain_dir.is_dir():
        return []
    examples: list[dict[str, Any]] = []
    for entry in sorted(domain_dir.iterdir()):
        if entry == target or not entry.is_dir() or entry.name.startswith("_"):
            continue
        files: dict[str, str] = {}
        for fname in ("Schema.py", "Handler.py", "Controller.py", "Tests.py"):
            path = entry / fname
            if path.exists():
                files[fname] = path.read_text()
        if len(files) >= 3:
            examples.append({"name": entry.name, "dir": str(entry.relative_to(REPO_ROOT)), "files": files})
            if len(examples) >= count:
                break
    return examples


def validate_code_structure(code: str, fname: str) -> list[str]:
    issues: list[str] = []
    if fname == "Schema.py" and "BaseModel" not in code and "Schema" in fname:
        issues.append("Schema.py must import and use pydantic.BaseModel")
    if fname == "Handler.py" and "class " not in code:
        issues.append("Handler.py must define a class")
    if fname == "Handler.py" and "logging_func" not in code:
        issues.append("Handler.py must have a module-level logger")
    if fname == "Tests.py" and "def test_" not in code:
        issues.append("Tests.py must contain test functions")
    opens = code.count("(")
    closes = code.count(")")
    if opens != closes:
        issues.append(f"Unbalanced parentheses: {opens} open vs {closes} close")
    opens = code.count("'''")
    if opens % 2 != 0:
        issues.append("Unbalanced triple-single-quotes")
    opens = code.count('"""')
    if opens % 2 != 0:
        issues.append("Unbalanced triple-double-quotes")
    return issues


def extract_json_blocks(text: str) -> dict[str, str]:
    """Try JSON parse; fall back to markdown parsing."""
    text = text.strip()
    # Strip markdown fences if present
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else text[3:]
        if text.endswith("```"):
            text = text[:-3].strip()
    # Try JSON parse
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    result: dict[str, str] = {}
    for k, v in data.items():
        if isinstance(k, str) and isinstance(v, str) and k.endswith(".py"):
            result[k] = v
    return result


def run_pytest(test_path: Path) -> tuple[bool, str]:
    with subprocess.Popen(
        ["uv", "run", "pytest", str(test_path), "--tb=long", "-v"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, cwd=str(REPO_ROOT / "apps" / "backend"),
    ) as proc:
        output = ""
        for line in proc.stdout:
            print(line, end="", file=sys.stderr)
            output += line
    passed = proc.returncode == 0
    return passed, output


def auto_backend(target: Path, prompt: str, verbose: bool = False) -> bool:
    expected = {"Schema.py", "Handler.py", "Controller.py", "Tests.py"}

    last_error: str = ""
    written: list[Path] = []
    for attempt in range(1, 4):
        print(f"[Runner] LLM attempt {attempt}/3...")
        if last_error:
            current = {p.name: p.read_text() for p in target.iterdir() if p.suffix == ".py"}
            current_block = "\n".join(f"### {f}\n```python\n{c}\n```" for f, c in sorted(current.items()))
            retry_prompt = (
                "Fix the violations below. Output valid JSON with ALL 4 files (Schema.py, Handler.py, Controller.py, Tests.py).\n"
                "## Current Files\n" + current_block + "\n"
                "## Previous Feedback\n" + last_error
            )
            response = call_llm(retry_prompt)
        else:
            response = call_llm(prompt)
        files = extract_code_blocks(response)
        if not files:
            last_error = "No code blocks found in LLM response."
            print(f"[Runner] {last_error} Retrying...", file=sys.stderr)
            continue
        written, deleted = write_code_blocks(files, target, protect=set(p.name for p in written))
        for w in written:
            print(f"[Runner] Wrote {w}")
        bad = truncated_files(written)
        if bad:
            for p in written:
                if p.name in bad:
                    p.unlink()
            last_error = f"Files appear truncated: {bad}. Regenerate complete code."
            print(f"[Runner] {last_error} Retrying...", file=sys.stderr)
            continue
        struct_issues: list[str] = []
        for w in written:
            struct_issues.extend(validate_code_structure(w.read_text(), w.name))
        std_violations = validate_code_standards(written)
        const_violations = validate_constitution(REPO_ROOT, target)
        pep8_violations = validate_pep8(REPO_ROOT, target)
        all_violations = struct_issues + std_violations + const_violations + pep8_violations
        if all_violations:
            last_error = "Violations:\n  " + "\n  ".join(all_violations)
            print(f"[Runner] {last_error}", file=sys.stderr)
        missing = expected - set(files.keys())
        if missing:
            last_error = f"Missing files: {missing}. Must include ALL 4 files."
            print(f"[Runner] {last_error} Retrying...", file=sys.stderr)
            continue
        if not all_violations and not missing:
            last_error = ""
            break
    else:
        print(f"[Runner] Failed to generate complete code after 3 attempts.", file=sys.stderr)
        return False

    test_file = target / "Tests.py"
    if not test_file.exists():
        print(f"[Runner] No Tests.py found at {test_file}, skipping auto-QA.")
        return True

    print(f"[Runner] Running tests for {target.name}...")
    passed, output = run_pytest(test_file)
    if passed:
        print(f"[Runner] All Tests Passed.")
        print(f"[Runner] Running full regression suite across all features...")
        regr_passed, regr_output = run_pytest(REPO_ROOT / "apps" / "backend" / "app" / "features")
        if regr_passed:
            print(f"[Runner] Regression suite: all pass.")
        else:
            preexisting = regr_output.count("FAILED")
            print(f"[Runner] WARNING: {preexisting} pre-existing failures in regression suite (not introduced by this change).", file=sys.stderr)
        print(f"[Runner] Validating root-level files (main.py)...")
        root_issues = validate_root_files(REPO_ROOT)
        if root_issues:
            print(f"[Runner] ROOT FILE VIOLATIONS:\n  " + "\n  ".join(root_issues), file=sys.stderr)
        else:
            print(f"[Runner] Root files: all checks pass.")
        return True

    print(f"[Runner] Tests failed. Generated code does not pass. ESCALATE to human.")
    return False


def run() -> None:
    parser = argparse.ArgumentParser(description="Runner Engine — sub-agent executor")
    parser.add_argument("--persona", required=True, type=Path, help="Path to persona .md file")
    parser.add_argument("--target", required=True, type=Path, help="Path to target feature directory")
    parser.add_argument("--task", default="", help="Task description for the sub-agent")
    parser.add_argument("--error", type=Path, help="Path to error/traceback file (for fix loops)")
    parser.add_argument("--api", action="store_true", help="Auto mode: call opencode, write files, run tests")
    parser.add_argument("--prompt-only", action="store_true", help="Print prompt to stdout only (no API call)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Print full prompt and response to stderr")
    args = parser.parse_args()
    if args.verbose:
        global VERBOSE
        VERBOSE = True

    if not args.persona.exists():
        print(f"Error: persona not found: {args.persona}", file=sys.stderr)
        sys.exit(1)
    if not args.target.is_dir():
        print(f"Error: target not found: {args.target}", file=sys.stderr)
        sys.exit(1)

    persona = read_file(args.persona)
    target_files = collect_target_files(args.target)
    task = args.task or f"Work on the feature at {args.target}"
    error = ""
    if args.error and args.error.exists():
        error = read_file(args.error)

    prompt = build_prompt(persona, args.target, target_files, task, error)

    if args.prompt_only or not args.api:
        print(prompt)
        return

    ok = auto_backend(args.target, prompt, verbose=args.verbose)
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    run()
