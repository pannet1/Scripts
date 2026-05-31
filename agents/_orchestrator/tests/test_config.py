import json
from pathlib import Path
from unittest.mock import patch

from _orchestrator.config import _get_features_dir


class TestGetFeaturesDir:

    def test_defaults_to_features(self, tmp_path: Path) -> None:
        with patch("_orchestrator.config.REPO_ROOT", tmp_path):
            with patch("_orchestrator.config.FEATURES_CONFIG", tmp_path / ".features.json"):
                result = _get_features_dir()
        assert result == tmp_path / "features"

    def test_reads_from_config(self, tmp_path: Path) -> None:
        cfg = tmp_path / ".features.json"
        cfg.write_text(json.dumps({"features_dir": "src/features"}) + "\n")
        with patch("_orchestrator.config.REPO_ROOT", tmp_path):
            with patch("_orchestrator.config.FEATURES_CONFIG", cfg):
                result = _get_features_dir()
        assert result == tmp_path / "src" / "features"

    def test_default_when_config_empty(self, tmp_path: Path) -> None:
        cfg = tmp_path / ".features.json"
        cfg.write_text("{}")
        with patch("_orchestrator.config.REPO_ROOT", tmp_path):
            with patch("_orchestrator.config.FEATURES_CONFIG", cfg):
                result = _get_features_dir()
        assert result == tmp_path / "features"
