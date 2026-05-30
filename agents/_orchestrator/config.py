import json
from pathlib import Path
from typing import Any

REPO_ROOT = Path.cwd()
AGENTS_DIR = Path(__file__).resolve().parent.parent


def _detect_features_dir(repo_root: Path) -> Path:
    candidates = [
        repo_root / "apps" / "backend" / "app" / "features",
        repo_root / "backend" / "src" / "features",
        repo_root / "backend" / "app" / "features",
        repo_root / "src" / "features",
        repo_root / "app" / "features",
        repo_root / "features",
    ]
    for path in candidates:
        if path.is_dir():
            return path
    return candidates[0]


FEATURES_DIR = _detect_features_dir(REPO_ROOT)
FEATURES_CONFIG = REPO_ROOT / ".features.json"
if not FEATURES_CONFIG.exists():
    FEATURES_CONFIG = AGENTS_DIR / "features.json"
RUNNER = AGENTS_DIR / "runner.py"
PERSONAS_DIR = AGENTS_DIR / "personas"
MODEL_CONFIG = AGENTS_DIR / "model_config.json"


def load_features_config() -> dict[str, Any]:
    if not FEATURES_CONFIG.exists():
        return {"known_features": {}, "domain_keywords": {}}
    with open(FEATURES_CONFIG) as f:
        return json.load(f)


FEATURES_CFG = load_features_config()
KNOWN_FEATURES: dict[str, str] = FEATURES_CFG.get("known_features", {})
DOMAIN_KEYWORDS: dict[str, tuple[str, str]] = {
    k: tuple(v) for k, v in FEATURES_CFG.get("domain_keywords", {}).items()
}
