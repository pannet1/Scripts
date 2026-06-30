#!/usr/bin/env python3
"""
Scaffolder — Project initializer and feature scanner.

Usage:
    python .agents/scaffolder.py init                      # create .features.json
    python .agents/scaffolder.py scan                      # discover existing features
    python .agents/scaffolder.py create <Name> [<domain>]  # new feature slice
    python .agents/scaffolder.py fix <Name>                # fix non-compliant feature dir

Operates on the current working directory as project root.
Reads/writes .features.json at project root.
"""
import json
import sys
from pathlib import Path
from typing import Any, Optional

REPO = Path.cwd()
AGENTS = Path(__file__).resolve().parent
FEATURES_CONFIG = REPO / ".features.json"
FALLBACK_CONFIG = AGENTS / "features.json"

EXPECTED_FILES = {"Schema.py", "Handler.py", "Controller.py", "Tests.py"}
CODE_TEMPLATES = {
    "Schema.py": 'from pydantic import BaseModel\n\n\nclass {action}Schema(BaseModel):\n    pass\n',
    "Handler.py": """from shared.logger import logging_func
from pydantic import BaseModel

logger = logging_func(__name__)


class {action}Handler:
    def execute(self, params: BaseModel) -> dict:
        logger.info("{action}Handler called")
        return {{"status": "ok"}}
""",
    "Controller.py": """from shared.logger import logging_func
from {action}Schema import {action}Schema
from {action}Handler import {action}Handler

logger = logging_func(__name__)


class {action}Controller:
    def __init__(self) -> None:
        self.handler = {action}Handler()

    def handle(self, raw: dict) -> dict:
        params = {action}Schema(**raw)
        return self.handler.execute(params)
""",
    "Tests.py": """import pytest
from {action}Handler import {action}Handler


def test_{action_lower}_handler() -> None:
    handler = {action}Handler()
    result = handler.execute({action}Schema())
    assert result["status"] == "ok"
""",
    "__init__.py": "",
}


def _read_config() -> dict[str, Any]:
    for path in (FEATURES_CONFIG, FALLBACK_CONFIG):
        if path.exists():
            return json.loads(path.read_text())
    return {}


def _write_config(data: dict[str, Any]) -> None:
    FEATURES_CONFIG.write_text(json.dumps(data, indent=2) + "\n")


def _get_features_dir() -> Path:
    cfg = _read_config()
    return REPO / cfg.get("features_dir", "features")


def _is_feature_dir(path: Path) -> bool:
    if not path.is_dir() or path.name.startswith("_") or path.name.startswith("."):
        return False
    files = {f.name for f in path.iterdir() if f.is_file()}
    if EXPECTED_FILES.issubset(files):
        return True
    has_test = any(f.startswith("test_") and f.endswith(".py") for f in files)
    if has_test:
        required = EXPECTED_FILES - {"Tests.py"}
        return required.issubset(files)
    return False


def cmd_init() -> int:
    if FEATURES_CONFIG.exists():
        print(f"[Scaffolder] {FEATURES_CONFIG} already exists.")
        return 0
    data: dict[str, Any] = {
        "features_dir": "features",
        "known_features": {},
        "domain_keywords": {},
    }
    _write_config(data)
    print(f"[Scaffolder] Created {FEATURES_CONFIG}")
    print(f'[Scaffolder] Features directory: {data["features_dir"]}/')
    features_dir = _get_features_dir()
    if not features_dir.exists():
        features_dir.mkdir(parents=True)
        print(f"[Scaffolder] Created features directory: {features_dir}/")
    print()
    print("Edit .features.json to change features_dir, then run:")
    print(f"  ./.agents/scaffolder.py scan")
    print(f"  ./.agents/orchestrator.py new/YourFeature")
    return 0


def cmd_scan() -> int:
    features_dir = _get_features_dir()
    if not features_dir.is_dir():
        print(f"[Scaffolder] Features directory not found: {features_dir}")
        print("  Run `./.agents/scaffolder.py init` first, or edit .features.json")
        return 1

    discovered: dict[str, str] = {}
    for entry in sorted(features_dir.iterdir()):
        if not entry.is_dir() or entry.name.startswith("_"):
            continue
        if _is_feature_dir(entry):
            discovered[entry.name] = entry.name
            print(f"  [feature] {entry.name}/")
        else:
            for sub in sorted(entry.iterdir()):
                if sub.is_dir() and not sub.name.startswith("_") and _is_feature_dir(sub):
                    discovered[sub.name] = entry.name
                    print(f"  [feature] {entry.name}/{sub.name}/")

    if not discovered:
        print("[Scaffolder] No compliant feature directories found.")
        return 1

    cfg = _read_config()
    known = cfg.setdefault("known_features", {})
    for name, domain in discovered.items():
        if name not in known:
            known[name] = domain
            keyword = name.lower().replace("feature", "").replace("handler", "").replace("controller", "")
            keywords = cfg.setdefault("domain_keywords", {})
            if keyword and keyword not in keywords:
                keywords[keyword] = [domain, name]
    _write_config(cfg)
    print(f"\n[Scaffolder] Registered {len(discovered)} features in .features.json")
    return 0


def cmd_create(name: str, domain: str = "") -> int:
    features_dir = _get_features_dir()
    if domain:
        target = features_dir / domain / name
    else:
        target = features_dir / name
    if target.exists():
        print(f"[Scaffolder] Already exists: {target}")
        return 1
    target.mkdir(parents=True)
    for fname, template in CODE_TEMPLATES.items():
        content = template.format(action=name, action_lower=name.lower()).lstrip("\n")
        (target / fname).write_text(content)
    spec = f"# {name}\n\n## Overview\n\nAutomatically scaffolded.\n"
    (target / "spec.md").write_text(spec)
    label = f"{domain}/{name}" if domain else name
    print(f"[Scaffolder] Created feature: {label}/")
    cfg = _read_config()
    known = cfg.setdefault("known_features", {})
    known[name] = domain
    keywords = cfg.setdefault("domain_keywords", {})
    kw = name.lower()
    if kw not in keywords:
        keywords[kw] = [domain, name]
    _write_config(cfg)
    return 0


def cmd_fix(name: str) -> int:
    features_dir = _get_features_dir()
    target = features_dir / name
    if not target.is_dir():
        for d in features_dir.iterdir():
            if d.is_dir() and (d / name).is_dir():
                target = d / name
                break
        else:
            print(f"[Scaffolder] Feature not found: {name}")
            return 1
    existing = {f.name for f in target.iterdir() if f.is_file()}
    created = 0
    for fname in EXPECTED_FILES:
        if fname not in existing:
            template = CODE_TEMPLATES.get(fname, "")
            content = template.format(action=name, action_lower=name.lower()).lstrip("\n")
            (target / fname).write_text(content)
            print(f"  Created missing: {target.name}/{fname}")
            created += 1
    if not created:
        print(f"[Scaffolder] {target.name}/ is already compliant.")
    return 0


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0
    command = sys.argv[1]
    args = sys.argv[2:]

    if command == "init":
        return cmd_init()
    elif command == "scan":
        return cmd_scan()
    elif command == "create":
        if not args:
            print("[Scaffolder] Usage: .agents/scaffolder.py create <Name> [<domain>]")
            return 1
        return cmd_create(args[0], args[1] if len(args) > 1 else "")
    elif command == "fix":
        if not args:
            print("[Scaffolder] Usage: .agents/scaffolder.py fix <Name>")
            return 1
        return cmd_fix(args[0])
    else:
        print(f"[Scaffolder] Unknown command: {command}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
