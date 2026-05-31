from pathlib import Path
from unittest.mock import patch

import pytest

from _orchestrator.commands import (
    _KNOWN_PREFIXES,
    _extract_feature_from_path,
    _resolve_input_to_feature,
)


class TestKnownPrefixes:

    def test_includes_all_commands(self) -> None:
        expected = {"new", "feature", "do", "modify", "bugfix", "delete", "merge", "deploy", "scaffold", "scan"}
        assert _KNOWN_PREFIXES == expected


class TestResolveInputToFeature:

    def test_known_feature_by_name(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        with patch("_orchestrator.commands.FEATURES_DIR", tmp_path):
            result = _resolve_input_to_feature("RunRatchetStrategy")
        assert result == "RunRatchetStrategy"

    def test_domain_slash_feature(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        with patch("_orchestrator.commands.FEATURES_DIR", tmp_path):
            result = _resolve_input_to_feature("strategy/RunRatchetStrategy")
        assert result == "RunRatchetStrategy"

    def test_full_path(self, tmp_path: Path) -> None:
        feature_dir = tmp_path / "strategy" / "RunRatchetStrategy"
        feature_dir.mkdir(parents=True)
        (feature_dir / "Handler.py").touch()
        file_path = str(tmp_path / "strategy" / "RunRatchetStrategy" / "Handler.py")
        with patch("_orchestrator.commands.FEATURES_DIR", tmp_path), \
             patch("_orchestrator.features.FEATURES_DIR", tmp_path), \
             patch("_orchestrator.commands.REPO_ROOT", tmp_path.parent):
            result = _resolve_input_to_feature(file_path)
        assert result == "RunRatchetStrategy"

    def test_new_feature_name_returns_as_is(self, tmp_path: Path) -> None:
        with patch("_orchestrator.commands.FEATURES_DIR", tmp_path):
            result = _resolve_input_to_feature("BrandNewFeature")
        assert result == "BrandNewFeature"

    def test_empty_input(self, tmp_path: Path) -> None:
        with patch("_orchestrator.commands.FEATURES_DIR", tmp_path):
            result = _resolve_input_to_feature("")
        assert result == ""

    def test_case_insensitive_match(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        with patch("_orchestrator.commands.FEATURES_DIR", tmp_path):
            result = _resolve_input_to_feature("runratchetstrategy")
        assert result == "RunRatchetStrategy"

    def test_nonexistent_path_returns_basename(self, tmp_path: Path) -> None:
        with patch("_orchestrator.commands.FEATURES_DIR", tmp_path):
            result = _resolve_input_to_feature("/nonexistent/path/MyFeature")
        assert result == "MyFeature"




class TestExtractFeatureFromPath:

    def test_extracts_from_features_subpath(self, tmp_path: Path) -> None:
        feature_dir = tmp_path / "strategy" / "RunRatchetStrategy"
        feature_dir.mkdir(parents=True)
        file_path = feature_dir / "Handler.py"
        file_path.touch()
        with patch("_orchestrator.commands.FEATURES_DIR", tmp_path):
            with patch("_orchestrator.commands.REPO_ROOT", tmp_path.parent):
                result = _extract_feature_from_path(str(file_path))
        assert result == "RunRatchetStrategy"

    def test_returns_none_for_nonexistent_path(self, tmp_path: Path) -> None:
        with patch("_orchestrator.commands.REPO_ROOT", tmp_path.parent):
            result = _extract_feature_from_path("/nonexistent/path")
        assert result is None
