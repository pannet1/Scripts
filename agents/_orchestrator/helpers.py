import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional

from .config import (
    FEATURES_CONFIG,
    MODEL_CONFIG,
    PERSONAS_DIR,
    REPO_ROOT,
    RUNNER,
    SCAFFOLDER,
)
from .feature import detect_existing_features, detect_features_dir, register_target
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


def scaffold_new_feature(target, overview: str = "", no_controller: bool = False) -> Path:
    slice_dir = target.dir
    slice_dir.mkdir(parents=True, exist_ok=True)

    if overview:
        ai_spec = generate_spec_with_ai(target.domain, target.name, overview)
        if ai_spec:
            (slice_dir / "spec.md").write_text(ai_spec)
            _qa_spec(slice_dir / "spec.md", overview, f"new:{target.name}")
        else:
            overview_text = format_spec_overview(overview)
            spec = SPEC_TEMPLATE.format(
                domain_title=target.domain.title() if target.domain else target.name,
                action=target.name,
                overview=overview_text,
            ).rstrip("\n")
            (slice_dir / "spec.md").write_text(spec)
            print("[Orchestrator] LLM unavailable — using template spec.md", file=sys.stderr)
    else:
        spec = SPEC_TEMPLATE.format(
            domain_title=target.domain.title() if target.domain else target.name,
            action=target.name,
            overview=DEFAULT_OVERVIEW,
        ).rstrip("\n")
        (slice_dir / "spec.md").write_text(spec)

    for fname, template in CODE_TEMPLATES.items():
        if no_controller and fname == "Controller.py":
            continue
        content = template.format(action=target.name).lstrip("\n")
        (slice_dir / fname).write_text(content)

    (slice_dir / "__init__.py").touch()
    register_target(target)

    label = f"{target.domain}/{target.name}"
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


def do_scaffold() -> None:
    if FEATURES_CONFIG.exists():
        print(f"[Orchestrator] {FEATURES_CONFIG} already exists.")
        return

    features_dir = detect_features_dir(REPO_ROOT)
    existing = detect_existing_features(REPO_ROOT)

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
    from .compliance import fix_all
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
