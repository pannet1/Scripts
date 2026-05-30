import json
from pathlib import Path
from unittest.mock import patch

import pytest

from _orchestrator.features import (
    find_feature_dir,
    infer_domain_action,
    register_feature_in_json,
    unregister_feature_from_json,
    _fuzzy_suggest,
    _scan_existing_features,
)


class TestInferDomainAction:

    @patch("_orchestrator.features.KNOWN_FEATURES", {"TrackHoldings": "state"})
    def test_returns_known_feature(self) -> None:
        domain, action = infer_domain_action("TrackHoldings")
        assert domain == "state"
        assert action == "TrackHoldings"

    @patch("_orchestrator.features.KNOWN_FEATURES", {})
    @patch("_orchestrator.features.DOMAIN_KEYWORDS", {"candle": ("candle", "ManageCandle")})
    def test_returns_from_keyword(self) -> None:
        domain, action = infer_domain_action("candle")
        assert domain == "candle"
        assert action == "ManageCandle"

    @patch("_orchestrator.features.KNOWN_FEATURES", {})
    @patch("_orchestrator.features.DOMAIN_KEYWORDS", {"managecandle": ("candle", "ManageCandle")})
    def test_returns_from_keyword_lowercase(self) -> None:
        domain, action = infer_domain_action("ManageCandle")
        assert domain == "candle"
        assert action == "ManageCandle"

    def test_returns_unknown(self) -> None:
        domain, action = infer_domain_action("NonexistentFeature")
        assert domain == ""
        assert action == "NonexistentFeature"


class TestScanExistingFeatures:

    def test_returns_empty_for_nonexistent_dir(self, tmp_path: Path) -> None:
        result = _scan_existing_features(tmp_path / "nonexistent")
        assert result == {}

    def test_finds_flat_features(self, tmp_path: Path) -> None:
        (tmp_path / "TrackHoldings").mkdir(parents=True)
        (tmp_path / "TrackHoldings" / "Handler.py").touch()
        result = _scan_existing_features(tmp_path)
        assert result == {"TrackHoldings": "TrackHoldings"}

    def test_finds_nested_features(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        result = _scan_existing_features(tmp_path)
        assert result == {"RunRatchetStrategy": "strategy"}

    def test_skips_underscore_dirs(self, tmp_path: Path) -> None:
        (tmp_path / "_private").mkdir(parents=True)
        (tmp_path / "_private" / "Secret").mkdir()
        result = _scan_existing_features(tmp_path)
        assert result == {}

    def test_skips_dirs_without_handler(self, tmp_path: Path) -> None:
        (tmp_path / "ValidFeature").mkdir(parents=True)
        (tmp_path / "ValidFeature" / "Something.py").touch()
        result = _scan_existing_features(tmp_path)
        assert result == {}

    def test_flat_and_nested_mixed(self, tmp_path: Path) -> None:
        (tmp_path / "JournalTrades").mkdir(parents=True)
        (tmp_path / "JournalTrades" / "Handler.py").touch()
        (tmp_path / "strategy" / "Ratchet").mkdir(parents=True)
        result = _scan_existing_features(tmp_path)
        assert result == {"JournalTrades": "JournalTrades", "Ratchet": "strategy"}


class TestFindFeatureDir:

    @patch("_orchestrator.features.KNOWN_FEATURES", {"TrackHoldings": "state"})
    def test_finds_fully_specified(self, tmp_path: Path) -> None:
        (tmp_path / "state" / "TrackHoldings").mkdir(parents=True)
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            result = find_feature_dir("TrackHoldings")
        assert result is not None
        assert result.name == "TrackHoldings"

    @patch("_orchestrator.features.KNOWN_FEATURES", {"TrackHoldings": "state"})
    def test_finds_flat_feature(self, tmp_path: Path) -> None:
        (tmp_path / "state").mkdir(parents=True)
        (tmp_path / "state" / "Handler.py").touch()
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            result = find_feature_dir("state")
        assert result is not None
        assert result.name == "state"

    def test_finds_by_lowercase_nested(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            result = find_feature_dir("runratchetstrategy")
        assert result is not None
        assert result.name == "RunRatchetStrategy"

    def test_finds_by_lowercase_flat(self, tmp_path: Path) -> None:
        (tmp_path / "TrackHoldings").mkdir(parents=True)
        (tmp_path / "TrackHoldings" / "Handler.py").touch()
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            result = find_feature_dir("trackholdings")
        assert result is not None
        assert result.name == "TrackHoldings"

    def test_returns_none_for_unknown(self, tmp_path: Path) -> None:
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            result = find_feature_dir("NoSuchFeature")
        assert result is None


class TestRegisterFeatureInJson:

    def test_registers_new_feature(self, tmp_path: Path) -> None:
        config_file = tmp_path / ".features.json"
        config_file.write_text(json.dumps({"known_features": {}, "domain_keywords": {}}) + "\n")
        with patch("_orchestrator.config.FEATURES_CONFIG", config_file), \
             patch("_orchestrator.features.FEATURES_CONFIG", config_file):
            register_feature_in_json("ManageCandle", "candle")
        data = json.loads(config_file.read_text())
        assert data["known_features"]["ManageCandle"] == "candle"

    def test_skips_duplicate(self, tmp_path: Path) -> None:
        config_file = tmp_path / ".features.json"
        config_file.write_text(json.dumps({"known_features": {"ManageCandle": "candle"}, "domain_keywords": {}}) + "\n")
        with patch("_orchestrator.config.FEATURES_CONFIG", config_file), \
             patch("_orchestrator.features.FEATURES_CONFIG", config_file):
            register_feature_in_json("ManageCandle", "candle")
        data = json.loads(config_file.read_text())
        assert data["known_features"]["ManageCandle"] == "candle"

    def test_adds_keyword(self, tmp_path: Path) -> None:
        config_file = tmp_path / ".features.json"
        config_file.write_text(json.dumps({"known_features": {}, "domain_keywords": {}}) + "\n")
        with patch("_orchestrator.config.FEATURES_CONFIG", config_file), \
             patch("_orchestrator.features.FEATURES_CONFIG", config_file):
            register_feature_in_json("ManageCandle", "candle")
        data = json.loads(config_file.read_text())
        assert data["domain_keywords"]["managecandle"] == ["candle", "ManageCandle"]


class TestUnregisterFeatureFromJson:

    def test_removes_feature(self, tmp_path: Path) -> None:
        config_file = tmp_path / ".features.json"
        config_file.write_text(
            json.dumps({"known_features": {"ManageCandle": "candle"}, "domain_keywords": {"candle": ["candle", "ManageCandle"]}}) + "\n"
        )
        with patch("_orchestrator.config.FEATURES_CONFIG", config_file), \
             patch("_orchestrator.features.FEATURES_CONFIG", config_file):
            unregister_feature_from_json("ManageCandle")
        data = json.loads(config_file.read_text())
        assert "ManageCandle" not in data["known_features"]

    def test_removes_stale_keywords(self, tmp_path: Path) -> None:
        config_file = tmp_path / ".features.json"
        config_file.write_text(
            json.dumps({"known_features": {"ManageCandle": "candle"}, "domain_keywords": {"candle": ["candle", "ManageCandle"]}}) + "\n"
        )
        with patch("_orchestrator.config.FEATURES_CONFIG", config_file), \
             patch("_orchestrator.features.FEATURES_CONFIG", config_file):
            unregister_feature_from_json("ManageCandle")
        data = json.loads(config_file.read_text())
        assert "candle" not in data["domain_keywords"]

    def test_does_nothing_for_unknown(self, tmp_path: Path) -> None:
        config_file = tmp_path / ".features.json"
        config_file.write_text(json.dumps({"known_features": {}, "domain_keywords": {}}) + "\n")
        with patch("_orchestrator.config.FEATURES_CONFIG", config_file), \
             patch("_orchestrator.features.FEATURES_CONFIG", config_file):
            unregister_feature_from_json("NoSuchFeature")
        data = json.loads(config_file.read_text())
        assert data["known_features"] == {}


class TestFuzzySuggest:

    def test_suggests_close_match(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        (tmp_path / "candle" / "ManageCandle").mkdir(parents=True)
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            with patch("builtins.input", return_value="1"):
                result = _fuzzy_suggest("RunRatchet")
        assert result is not None
        assert result.name == "RunRatchetStrategy"

    def test_returns_none_for_no_match(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            result = _fuzzy_suggest("Xyzzy")
        assert result is None

    def test_cancel_returns_none(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        (tmp_path / "candle" / "ManageCandle").mkdir(parents=True)
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            with patch("builtins.input", return_value="n"):
                result = _fuzzy_suggest("RunRatchet")
        assert result is None

    def test_invalid_choice_returns_none(self, tmp_path: Path) -> None:
        (tmp_path / "strategy" / "RunRatchetStrategy").mkdir(parents=True)
        with patch("_orchestrator.features.FEATURES_DIR", tmp_path):
            with patch("builtins.input", return_value="99"):
                result = _fuzzy_suggest("RunRatchet")
        assert result is None
