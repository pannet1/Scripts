from pathlib import Path

from _orchestrator.config import _detect_features_dir


class TestDetectFeaturesDir:

    def test_returns_first_existing(self, tmp_path: Path) -> None:
        (tmp_path / "apps" / "backend" / "app" / "features").mkdir(parents=True)
        (tmp_path / "src" / "features").mkdir(parents=True)
        result = _detect_features_dir(tmp_path)
        assert result == tmp_path / "apps" / "backend" / "app" / "features"

    def test_returns_source_features(self, tmp_path: Path) -> None:
        (tmp_path / "src" / "features").mkdir(parents=True)
        result = _detect_features_dir(tmp_path)
        assert result == tmp_path / "src" / "features"

    def test_returns_first_candidate_when_none_exist(self, tmp_path: Path) -> None:
        result = _detect_features_dir(tmp_path)
        assert result == tmp_path / "apps" / "backend" / "app" / "features"

    def test_backend_app_features(self, tmp_path: Path) -> None:
        (tmp_path / "backend" / "app" / "features").mkdir(parents=True)
        result = _detect_features_dir(tmp_path)
        assert result == tmp_path / "backend" / "app" / "features"

    def test_root_features(self, tmp_path: Path) -> None:
        (tmp_path / "features").mkdir(parents=True)
        result = _detect_features_dir(tmp_path)
        assert result == tmp_path / "features"
