import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from .config import FEATURES_CONFIG, REPO_ROOT
from .feature import detect_existing_features, detect_features_dir, register_target
from .llm import generate_spec_with_ai
from .specs import _qa_spec
from .templates import CODE_TEMPLATES, DEFAULT_OVERVIEW, SPEC_TEMPLATE


def format_spec_overview(overview: str) -> str:
    if overview:
        return overview
    return DEFAULT_OVERVIEW


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


def init_project() -> None:
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
