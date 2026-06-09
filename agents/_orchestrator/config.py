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


def load_features_config() -> dict[str, Any]:
    if FEATURES_CONFIG.exists():
        return json.loads(FEATURES_CONFIG.read_text())
    return {"known_features": {}, "domain_keywords": {}}


def app_features_dir(app: str = "") -> Path:
    cfg = _read_features_config()
    dir_name = cfg.get("features_dir", "features")
    if app:
        apps = cfg.get("apps", {})
        if app in apps:
            dir_name = apps[app].get("features_dir", dir_name)
    return REPO_ROOT / dir_name


def app_features_config(app: str = "") -> Path:
    if not app:
        return FEATURES_CONFIG
    cfg = _read_features_config()
    apps = cfg.get("apps", {})
    if app in apps:
        path = apps[app].get("config", "")
        if path:
            return REPO_ROOT / path
    return FEATURES_CONFIG


FEATURES_CFG = load_features_config()
KNOWN_FEATURES: dict[str, str] = FEATURES_CFG.get("known_features", {})
DOMAIN_KEYWORDS: dict[str, tuple[str, str]] = {
    k: tuple(v) for k, v in FEATURES_CFG.get("domain_keywords", {}).items()
}
