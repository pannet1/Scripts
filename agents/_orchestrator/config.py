from pathlib import Path

REPO_ROOT = Path.cwd()
AGENTS_DIR = Path(__file__).resolve().parent.parent

FEATURES_CONFIG = REPO_ROOT / ".features.json"
RUNNER = AGENTS_DIR / "runner.py"
PERSONAS_DIR = AGENTS_DIR / "personas"
MODEL_CONFIG = AGENTS_DIR / "model_config.json"
