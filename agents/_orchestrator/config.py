import json
from pathlib import Path
from typing import Any

REPO_ROOT = Path.cwd()
AGENTS_DIR = Path(__file__).resolve().parent.parent

FEATURES_CONFIG = REPO_ROOT / ".features.json"


def _read_features_config() -> dict[str, Any]:
    if FEATURES_CONFIG.exists():
        return json.loads(FEATURES_CONFIG.read_text())
    return {}


def _get_features_dir() -> Path:
    cfg = _read_features_config()
    dir_name = cfg.get("features_dir", "features")
    return REPO_ROOT / dir_name


FEATURES_DIR = _get_features_dir()
RUNNER = AGENTS_DIR / "runner.py"
SCAFFOLDER = AGENTS_DIR / "scaffolder.py"
PERSONAS_DIR = AGENTS_DIR / "personas"
MODEL_CONFIG = AGENTS_DIR / "model_config.json"
