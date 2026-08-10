from pathlib import Path
from unittest.mock import patch

import pytest

from _orchestrator.commands import (
    _KNOWN_PREFIXES,
    _extract_feature_from_path,
    _parse_request,
    _resolve_input_to_feature,
    orchestrate,
)


class TestParseRequest:

    def test_bare_action_domain_feature(self) -> None:
        assert _parse_request("modify shared/Payment") == ("modify", "shared", "Payment", "")

    def test_bare_action_domain_feature_with_prompt(self) -> None:
        assert _parse_request("modify shared/Payment make it seamless") == (
            "modify", "shared", "Payment", "make it seamless")

    def test_new_accepts_domain_feature_and_prompt(self) -> None:
        assert _parse_request("new shared/TestFeature test prompt") == (
            "new", "shared", "TestFeature", "test prompt")

    def test_new_bare_feature_with_prompt(self) -> None:
        assert _parse_request("new Payments auction payment flow") == (
            "new", "", "Payments", "auction payment flow")

    def test_do_domain_feature(self) -> None:
        assert _parse_request("do shared/Payment") == ("do", "shared", "Payment", "")

    def test_delete_bare_feature(self) -> None:
        assert _parse_request("delete Payment") == ("delete", "", "Payment", "")

    def test_rename_two_tokens(self) -> None:
        assert _parse_request("rename OldName NewName") == ("rename", "", "OldName", "NewName")

    def test_bare_merge(self) -> None:
        assert _parse_request("merge") == ("merge", "", "", "")

    def test_merge_with_target(self) -> None:
        assert _parse_request("merge shared/Payment") == ("merge", "shared", "Payment", "")

    def test_scan(self) -> None:
        assert _parse_request("scan") == ("scan", "", "", "")

    def test_legacy_slash_verb_not_parsed(self) -> None:
        assert _parse_request("modify/shared/Payment") == ("modify/shared/payment", "", "", "")

    def test_legacy_domain_slash_action_not_parsed(self) -> None:
        assert _parse_request("vps/modify/Subscription") == ("vps/modify/subscription", "", "", "")

    def test_empty_request(self) -> None:
        assert _parse_request("") == ("", "", "", "")


class TestMergeGuard:

    def test_merge_on_main_aborts(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "main")
        orchestrate("merge")
        out = capsys.readouterr().out
        assert "Checkout a feature branch before running merge" in out

    def test_merge_main_variant_aborts(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "main*")
        orchestrate("merge")
        assert "Checkout a feature branch before running merge" in capsys.readouterr().out

    def test_merge_detached_head_aborts(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "")
        orchestrate("merge")
        assert "Detached HEAD" in capsys.readouterr().out

    def test_merge_with_target_on_feature_branch_aborts(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "modify/Payment")
        orchestrate("merge shared/Payment")
        assert "merge takes no target" in capsys.readouterr().out


class TestKnownPrefixes:

    def test_includes_all_commands(self) -> None:
        expected = {"new", "feature", "do", "modify", "bugfix", "delete", "merge", "deploy", "scaffold", "scan", "rename"}
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
