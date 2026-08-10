import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional

from .config import (
    DOMAIN_KEYWORDS,
    FEATURES_CONFIG,
    FEATURES_DIR,
    KNOWN_FEATURES,
    MODEL_CONFIG,
    PERSONAS_DIR,
    REPO_ROOT,
    RUNNER,
    SCAFFOLDER,
    app_features_dir,
)
from .features import find_feature_dir, resolve_feature
from .llm import generate_spec_with_ai, llm_complete
from .templates import CODE_TEMPLATES, DEFAULT_OVERVIEW, SPEC_TEMPLATE


def format_spec_overview(overview: str) -> str:
    if overview:
        return overview
    return DEFAULT_OVERVIEW


def resolve_change_prompt(rest: str, prompt_content: str, feature_name: str, prefix: str) -> str:
    if prompt_content:
        return prompt_content
    if not rest:
        print("=" * 60)
        print(f"ERROR: `{prefix} {feature_name}` requires a prompt.")
        print()
        print("Options:")
        print(f'  ./.agents/orchestrator.py {prefix} {feature_name} --prompt path/to/prompt.md')
        print(f'  ./.agents/orchestrator.py {prefix} {feature_name} "describe your change in words"')
        print(f'  ./.agents/orchestrator.py {prefix} {feature_name} path/to/prompt.md')
        print("=" * 60)
        sys.exit(1)
    path = Path(rest)
    if path.suffix == ".md":
        resolved = REPO_ROOT / rest
        if not resolved.exists():
            print(f"[Orchestrator] Prompt file not found: {resolved}")
            sys.exit(1)
        return resolved.read_text().strip()
    return rest.strip()


def scaffold_new_feature(domain: str, action: str, overview: str = "", no_controller: bool = False, app: str = "") -> Path:
    fdir = app_features_dir(app) if app else FEATURES_DIR
    if domain:
        base = fdir / domain
    else:
        base = fdir / "nodomain"
    slice_dir = base / action
    slice_dir.mkdir(parents=True, exist_ok=True)

    if overview:
        ai_spec = generate_spec_with_ai(domain, action, overview)
        if ai_spec:
            (slice_dir / "spec.md").write_text(ai_spec)
            _qa_spec(slice_dir / "spec.md", overview, f"new:{action}")
        else:
            overview_text = format_spec_overview(overview)
            spec = SPEC_TEMPLATE.format(
                domain_title=domain.title() if domain else action,
                action=action,
                overview=overview_text,
            ).rstrip("\n")
            (slice_dir / "spec.md").write_text(spec)
            print("[Orchestrator] Zen API unavailable — using template spec.md", file=sys.stderr)
    else:
        spec = SPEC_TEMPLATE.format(
            domain_title=domain.title() if domain else action,
            action=action,
            overview=DEFAULT_OVERVIEW,
        ).rstrip("\n")
        (slice_dir / "spec.md").write_text(spec)

    for fname, template in CODE_TEMPLATES.items():
        if no_controller and fname == "Controller.py":
            continue
        content = template.format(action=action).lstrip("\n")
        (slice_dir / fname).write_text(content)

    (slice_dir / "__init__.py").touch()

    label = f"{domain}/{action}" if domain else f"nodomain/{action}"
    note = " (no controller)" if no_controller else ""
    print(f"\nScaffolded new feature: {label}{note}\n")
    return slice_dir


MAX_SPEC_QA_ATTEMPTS = 3


def _validate_spec(spec: str, original_prompt: str) -> tuple[bool, str]:
    """Validate spec against the original prompt, returning (is_valid, corrected_spec)."""
    model = "deepseek-v4-flash"
    if MODEL_CONFIG.exists():
        try:
            cfg = json.loads(MODEL_CONFIG.read_text())
            model = cfg.get("model", model)
        except Exception:
            pass

    system = (
        "You are a spec QA validator. Compare the provided spec against the original prompt. "
        "List every discrepancy you find (wrong method signatures, missing sections, incorrect terminology, "
        "wrong response fields, wrong storage model, missing dependencies, wrong routes). "
        "Be pedantic. If the spec is fully correct, reply with exactly: VALID\n\n"
        "If there are issues, reply with ISSUES (one per line prefixed with -), "
        "then a blank line, then the COMPLETE corrected spec in markdown format."
    )

    result = llm_complete(
        f"## Original Prompt\n\n{original_prompt}\n\n## Generated Spec\n\n{spec}",
        system=system,
        model=model,
    )
    if result is None:
        return True, spec
    result = result.strip()
    if result.startswith("VALID"):
        return True, spec
    lines = result.split("\n")
    corrected = []
    in_spec = False
    for line in lines:
        if line.startswith("#") and not line.startswith("-") and not in_spec:
            in_spec = True
        if in_spec:
            corrected.append(line)
    if corrected:
        new_spec = "\n".join(corrected).strip()
        return False, new_spec
    return False, spec


def _qa_spec(spec_path: Path, original_prompt: str, label: str) -> None:
    """Run quality assurance loop on a spec file against the original prompt."""
    for attempt in range(1, MAX_SPEC_QA_ATTEMPTS + 1):
        spec = spec_path.read_text()
        is_valid, corrected = _validate_spec(spec, original_prompt)
        if is_valid:
            print(f"[Orchestrator] Spec QA passed ({label})")
            return
        print(f"[Orchestrator] Spec QA issue found ({label}), attempt {attempt}/{MAX_SPEC_QA_ATTEMPTS}")
        spec_path.write_text(corrected)
    print(f"[Orchestrator] Spec QA exhausted {MAX_SPEC_QA_ATTEMPTS} attempts — spec may still have issues ({label})")


def amend_spec(feature_dir: Path, heading: str, branch_prefix: str, feature_name: str = "") -> None:
    display = feature_name or feature_dir.name
    print(f"\n{'='*60}\n{heading} for {display}")
    print(f"Spec amended. Run do when ready:\n")
    print(f"  ./.agents/orchestrator.py do {display}")
    print("=" * 60)


def _rewrite_spec_with_ai(feature_dir: Path, change_prompt: str, section: str) -> bool:
    spec_path = feature_dir / "spec.md"
    existing = spec_path.read_text() if spec_path.exists() else ""
    heading = section.replace(" Request", "").replace(" Resolution", "")

    amendment = (
        f"\n## {heading}\n\n"
        f"{change_prompt}\n\n"
        "### Constraints\n"
        "* <!-- added by modification -->\n"
    )
    if existing:
        spec_path.write_text(existing + amendment)
    else:
        spec_path.write_text(amendment)
    print(f"[Orchestrator] spec.md amended with structured '{heading}' section")

    _qa_spec(spec_path, change_prompt, f"amend:{heading}")

    return True


def run_runner(persona_key: str, target: Path, task: str, error_path: Optional[Path] = None) -> bool:
    persona_path = PERSONAS_DIR / f"{persona_key}_agent.md"
    if not persona_path.exists():
        print(f"[Orchestrator] Persona not found: {persona_path}", file=sys.stderr)
        return False

    cmd = [
        sys.executable, str(RUNNER),
        "--persona", str(persona_path),
        "--target", str(target),
        "--task", task,
        "--api",
    ]
    if error_path:
        cmd += ["--error", str(error_path)]

    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1) as proc:
        for line in proc.stdout:
            print(line, end="", flush=True)
    return proc.returncode == 0


def run_scaffolder(args: list[str]) -> bool:
    cmd = [sys.executable, str(SCAFFOLDER)] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    return result.returncode == 0


def _derive_feature_name_from_path(path_str: str) -> str:
    clean = path_str.strip().strip('"').strip("'")
    m = re.search(r"features/([A-Za-z0-9_-]+)/([A-Za-z0-9_-]+)", clean)
    if m:
        return m.group(2)
    p = Path(clean)
    stem = p.stem
    if re.fullmatch(r"[A-Za-z0-9_./\\-]+", clean):
        name = "".join(word.capitalize() for word in stem.replace("-", "_").split("_"))
        if name:
            return name
        parent_name = "".join(word.capitalize() for word in p.parent.name.replace("-", "_").split("_"))
        if parent_name:
            return parent_name
    words = re.findall(r"[A-Za-z]+", clean)
    stopwords = {"the", "a", "an", "from", "into", "with", "for", "to", "in", "of", "and", "or", "is", "as", "by", "on", "at"}
    significant = [w for w in words if w.lower() not in stopwords]
    if len(significant) >= 2:
        return significant[0].capitalize() + significant[1].capitalize()
    if significant:
        return significant[0].capitalize() + "Feature"
    return "Feature"


def _resolve_current_file() -> Optional[str]:
    nvim_addr = os.environ.get("NVIM") or os.environ.get("NVIM_LISTEN_ADDRESS") or ""
    if nvim_addr:
        try:
            result = subprocess.run(
                ["nvim", "--headless", "--server", nvim_addr, "--remote-expr", "expand('%:p')"],
                capture_output=True, text=True, timeout=3,
            )
            if result.returncode == 0:
                path = result.stdout.strip().strip('"')
                if path:
                    return path
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            pass
    for var in ("OPENCODE_CURRENT_FILE", "VIM_FILEPATH"):
        val = os.environ.get(var)
        if val:
            p = Path(val)
            if p.is_file():
                return str(p.resolve())
    return None


def _resolve_prompt_for_implicit(rest: str, prompt_content: str) -> Optional[str]:
    if prompt_content:
        return prompt_content
    if not rest:
        return None
    p = Path(rest)
    if p.suffix == ".md":
        resolved = REPO_ROOT / rest
        if resolved.exists():
            return resolved.read_text().strip()
    return rest.strip()


def _ensure_shared_logger() -> None:
    logger_path = REPO_ROOT / "shared" / "logger.py"
    if logger_path.exists():
        return
    logger_path.parent.mkdir(parents=True, exist_ok=True)
    logger_path.write_text(
        'from __future__ import annotations\n'
        '\n'
        'import logging\n'
        'from typing import Any\n'
        '\n'
        '\n'
        'def logging_func(name: str) -> logging.Logger:\n'
        '    return logging.getLogger(name)\n'
    )
    print(f"[Orchestrator] Created {logger_path.relative_to(REPO_ROOT)}")


def _detect_features_dir(repo_root: Path) -> str:
    candidates = [
        "apps/backend/app/features",
        "backend/src/features",
        "backend/app/features",
        "src/features",
        "app/features",
        "features",
    ]
    for path in candidates:
        if (repo_root / path).is_dir():
            return path
    return "features"


FEATURE_SCAN_DIRS = frozenset({
    "scripts", "health", "web", "migrations", "private",
    "db", "common", "tests", "factory",
})


def _detect_existing_features() -> dict[str, str]:
    """Scan project directories for existing script/feature files."""
    features: dict[str, str] = {}
    for dirname in FEATURE_SCAN_DIRS:
        d = REPO_ROOT / dirname
        if not d.is_dir():
            continue
        for fp in sorted(d.rglob("*.py")):
            fname = fp.stem
            if fname.startswith("_"):
                continue
            if any(p.startswith(".") or p == "__pycache__" for p in fp.parts):
                continue
            dom = dirname
            if fname not in features:
                features[fname] = dom
    return features


def do_scaffold() -> None:
    if FEATURES_CONFIG.exists():
        print(f"[Orchestrator] {FEATURES_CONFIG} already exists.")
        return

    features_dir = _detect_features_dir(REPO_ROOT)
    existing = _detect_existing_features()

    payload: dict[str, Any] = {
        "features_dir": features_dir,
        "known_features": existing,
        "domain_keywords": {},
    }
    FEATURES_CONFIG.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"[Orchestrator] Created {FEATURES_CONFIG}")
    print(f"[Orchestrator] Features directory: {features_dir}/")

    if existing:
        print(f"[Orchestrator] Discovered {len(existing)} existing features:")
        for fname, dom in sorted(existing.items()):
            print(f"    {fname}  ({dom}/)")
    print()

    _ensure_shared_logger()

    print()
    print("[Orchestrator] === Compliance Fix ===")
    from .compliance_fixer import fix_all
    fix_all()

    print()
    print("[Orchestrator] === Verification ===")
    result = subprocess.run(
        ["uv", "run", "pytest", "tests/test_compliance.py", "-v", "--tb=no"],
        capture_output=True, text=True, cwd=str(REPO_ROOT),
    )
    print(result.stdout, end="")
    if result.returncode == 0:
        print("[Orchestrator] Project is compliant.")
    else:
        print("[Orchestrator] Some violations remain (see above). Re-run scaffold or fix manually.")
    print()


_KNOWN_PREFIXES = frozenset({
    "new", "feature", "modify", "do", "delete", "move", "merge", "undo", "deploy", "scaffold", "scan",
})


def _extract_feature_from_path(path_str: str) -> Optional[str]:
    candidates = [FEATURES_DIR]
    known_map = dict(KNOWN_FEATURES)
    for domain_key, (dom, act) in list(DOMAIN_KEYWORDS.items()):
        known_map[act] = dom

    resolved = REPO_ROOT / path_str
    if not resolved.exists():
        return None

    parts = resolved.resolve().parts
    features_parts = FEATURES_DIR.resolve().parts
    try:
        idx = next(i for i in range(len(parts) - len(features_parts) + 1)
                   if parts[i:i + len(features_parts)] == features_parts)
        remainder = parts[idx + len(features_parts):]
    except StopIteration:
        remainder = ()

    if len(remainder) >= 2:
        domain, feature_name = remainder[0], remainder[1]
        if (FEATURES_DIR / domain / feature_name).is_dir():
            return feature_name
    if remainder:
        last = remainder[-1]
        if known_map.get(last) or find_feature_dir(last):
            return last

    candidate = resolved.stem if resolved.suffix else resolved.name
    if find_feature_dir(candidate):
        return candidate
    return None


def _resolve_input_to_feature(raw_input: str) -> Optional[str]:
    cleaned = raw_input.strip().strip("/")
    feature_dir = find_feature_dir(cleaned)
    if feature_dir:
        return feature_dir.name

    parts = cleaned.split("/")
    for i in range(1, len(parts)):
        candidate = parts[-i]
        feature_dir = find_feature_dir(candidate)
        if feature_dir:
            return feature_dir.name

    path_feature = _extract_feature_from_path(cleaned)
    if path_feature:
        return path_feature

    for domain_dir in FEATURES_DIR.iterdir():
        if not domain_dir.is_dir() or domain_dir.name.startswith("_"):
            continue
        for entry in domain_dir.iterdir():
            if entry.is_dir() and not entry.name.startswith("_"):
                if entry.name.lower() == cleaned.lower():
                    return entry.name

    name = Path(cleaned).name if "/" in cleaned else cleaned
    return name


def _find_feature_or_resolve(raw: str, app: str = "") -> Optional[Path]:
    feature_dir = resolve_feature(raw, app=app)
    if feature_dir:
        return feature_dir
    name = _resolve_input_to_feature(raw)
    if name and name != raw:
        feature_dir = resolve_feature(name, app=app)
    return feature_dir


def _feature_from_branch(branch: str) -> str:
    if not branch or branch == "(unknown)" or branch == "main" or branch.startswith("main"):
        return ""
    return branch.rsplit("/", 1)[-1]


def _domain_of(feature_dir: Optional[Path]) -> str:
    if not feature_dir:
        return ""
    return feature_dir.parent.name if feature_dir.parent != FEATURES_DIR else "nodomain"


def _parse_request(request: str) -> tuple[str, str, str, str]:
    cmd = request.strip().split(None, 1)
    verb = cmd[0] if cmd else ""
    rest = cmd[1] if len(cmd) > 1 else ""
    domain = ""
    prefix = verb.lower()
    action = rest.strip()
    if prefix in _KNOWN_PREFIXES and rest:
        target, _, tail = rest.partition(" ")
        target = target.strip()
        if "/" in target:
            domain, action = target.split("/", 1)
            action = action.strip()
        else:
            action = target
        rest = tail.strip()
    return prefix, domain, action, rest
