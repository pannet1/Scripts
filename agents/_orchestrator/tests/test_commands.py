import json
from pathlib import Path
from unittest.mock import patch

import pytest

from _orchestrator.commands import (
    _KNOWN_PREFIXES,
    _domain_of,
    _extract_feature_from_path,
    _feature_from_branch,
    _parse_request,
    _resolve_input_to_feature,
    orchestrate,
    scaffold_new_feature,
)
from _orchestrator.git_ops import check_branch


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

    def test_move_two_tokens(self) -> None:
        assert _parse_request("move OldName NewName") == ("move", "", "OldName", "NewName")

    def test_move_across_domains(self) -> None:
        assert _parse_request("move shared/Payment vps/Payments") == ("move", "shared", "Payment", "vps/Payments")

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


class TestFeatureFromBranch:

    def test_feature_prefix(self) -> None:
        assert _feature_from_branch("feature/Payment") == "Payment"

    def test_modify_prefix(self) -> None:
        assert _feature_from_branch("modify/Payment") == "Payment"

    def test_domain_slash_feature_branch(self) -> None:
        assert _feature_from_branch("shared/Payment") == "Payment"

    def test_main_returns_empty(self) -> None:
        assert _feature_from_branch("main") == ""

    def test_plain_branch_returns_branch_name(self) -> None:
        assert _feature_from_branch("dev") == "dev"


class TestDoDeleteInferFromBranch:

    def test_do_without_target_on_feature_branch(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "feature/Payment")
        monkeypatch.setattr("_orchestrator.commands._find_feature_or_resolve", lambda raw, app="": None)
        orchestrate("do")
        assert "Feature not found: Payment" in capsys.readouterr().out

    def test_do_without_target_on_main(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "main")
        orchestrate("do")
        assert "cannot infer from current branch" in capsys.readouterr().out

    def test_delete_without_target_on_modify_branch(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "shared/Payment")
        monkeypatch.setattr("_orchestrator.commands.resolve_feature", lambda raw, app="": None)
        monkeypatch.setattr("_orchestrator.commands.branch_exists", lambda name: False)
        calls: list[list[str]] = []

        def fake_run(cmd: list[str], **kwargs: object) -> object:
            calls.append(cmd)
            return type("R", (), {"returncode": 0, "stdout": "", "stderr": ""})()

        monkeypatch.setattr("_orchestrator.commands.subprocess.run", fake_run)
        orchestrate("delete")
        out = capsys.readouterr().out
        assert "Nothing to delete: feature 'Payment' not found." in out
        assert not any("stash" in c for c in calls)


class TestMoveHandler:

    def _patch_env(self, tmp_path: Path, monkeypatch: object, known: dict[str, str]) -> None:
        (tmp_path / "features" / "shared" / "Payment").mkdir(parents=True)
        (tmp_path / "features" / "shared" / "Payment" / "spec.md").touch()
        cfg = tmp_path / ".features.json"
        cfg.write_text(json.dumps({"known_features": known}))
        monkeypatch.setattr("_orchestrator.commands.FEATURES_DIR", tmp_path / "features")
        monkeypatch.setattr("_orchestrator.commands.FEATURES_CONFIG", cfg)
        monkeypatch.setattr("_orchestrator.commands.load_features_config", lambda: json.loads(cfg.read_text()))
        monkeypatch.setattr("_orchestrator.features.FEATURES_DIR", tmp_path / "features")

        def fake_run(cmd: list[str], **kwargs: object) -> object:
            return type("R", (), {"returncode": 0, "stdout": "", "stderr": ""})()

        monkeypatch.setattr("_orchestrator.commands.subprocess.run", fake_run)
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "main")

    def test_move_within_domain(self, tmp_path: Path, capsys: object, monkeypatch: object) -> None:
        self._patch_env(tmp_path, monkeypatch, {"Payment": "shared"})
        orchestrate("move Payment Payments")
        out = capsys.readouterr().out
        assert "Moving Payment -> Payments" in out
        assert (tmp_path / "features" / "shared" / "Payments" / "spec.md").exists()
        assert not (tmp_path / "features" / "shared" / "Payment").exists()
        data = json.loads((tmp_path / ".features.json").read_text())
        assert data["known_features"] == {"Payments": "shared"}

    def test_move_across_domains(self, tmp_path: Path, capsys: object, monkeypatch: object) -> None:
        self._patch_env(tmp_path, monkeypatch, {"Payment": "shared"})
        orchestrate("move Payment vps/Payments")
        out = capsys.readouterr().out
        assert "Moving Payment -> Payments" in out
        assert (tmp_path / "features" / "vps" / "Payments" / "spec.md").exists()
        assert not (tmp_path / "features" / "shared" / "Payment").exists()
        data = json.loads((tmp_path / ".features.json").read_text())
        assert data["known_features"] == {"Payments": "vps"}

    def test_move_missing_target_usage(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.resolve_feature", lambda raw, app="": None)
        orchestrate("move Payment")
        assert "Usage: move <OldDomain/OldFeature> <NewDomain/NewFeature>" in capsys.readouterr().out


class TestScaffoldBareFeature:

    def test_bare_feature_lands_in_nodomain(self, tmp_path: Path, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.FEATURES_DIR", tmp_path / "features")
        result = scaffold_new_feature("", "Payments", "")
        assert result == tmp_path / "features" / "nodomain" / "Payments"
        assert (tmp_path / "features" / "nodomain" / "Payments" / "spec.md").exists()
        assert not (tmp_path / "features" / "Payments").exists()


class TestDomainOf:

    def test_domain_from_feature_dir(self, tmp_path: Path, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.FEATURES_DIR", tmp_path / "features")
        assert _domain_of(tmp_path / "features" / "shared" / "Payment") == "shared"

    def test_root_level_feature_assumes_nodomain(self, tmp_path: Path, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.FEATURES_DIR", tmp_path / "features")
        assert _domain_of(tmp_path / "features" / "Payment") == "nodomain"

    def test_none_returns_empty(self) -> None:
        assert _domain_of(None) == ""


class TestCheckBranchNaming:

    def _fake_git(self, monkeypatch: object) -> list[list[str]]:
        calls: list[list[str]] = []

        def fake_run(cmd: list[str], **kwargs: object) -> object:
            calls.append(cmd)
            return type("R", (), {"returncode": 0, "stdout": "", "stderr": ""})()

        monkeypatch.setattr("_orchestrator.git_ops.subprocess.run", fake_run)
        return calls

    def test_branch_uses_domain_slash_feature(self, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.git_ops.current_branch", lambda: "main")
        monkeypatch.setattr("_orchestrator.git_ops.unmerged_branches", lambda: [])
        monkeypatch.setattr("_orchestrator.git_ops.branch_exists", lambda name: False)
        calls = self._fake_git(monkeypatch)
        check_branch("Payment", "shared")
        assert ["git", "checkout", "-b", "shared/Payment"] in calls

    def test_branch_without_domain_is_bare_feature(self, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.git_ops.current_branch", lambda: "main")
        monkeypatch.setattr("_orchestrator.git_ops.unmerged_branches", lambda: [])
        monkeypatch.setattr("_orchestrator.git_ops.branch_exists", lambda name: False)
        calls = self._fake_git(monkeypatch)
        check_branch("Payments", "")
        assert ["git", "checkout", "-b", "Payments"] in calls

    def test_branch_for_bare_feature_uses_nodomain(self, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.git_ops.current_branch", lambda: "main")
        monkeypatch.setattr("_orchestrator.git_ops.unmerged_branches", lambda: [])
        monkeypatch.setattr("_orchestrator.git_ops.branch_exists", lambda name: False)
        calls = self._fake_git(monkeypatch)
        check_branch("Payments", "nodomain")
        assert ["git", "checkout", "-b", "nodomain/Payments"] in calls

    def test_no_operation_prefix_in_branch_name(self, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.git_ops.current_branch", lambda: "main")
        monkeypatch.setattr("_orchestrator.git_ops.unmerged_branches", lambda: [])
        monkeypatch.setattr("_orchestrator.git_ops.branch_exists", lambda name: False)
        calls = self._fake_git(monkeypatch)
        check_branch("Payment", "shared")
        created = [c for c in calls if c[:3] == ["git", "checkout", "-b"]]
        assert created
        for c in created:
            for name in c[3:]:
                assert not name.startswith(("feature/", "modify/"))

    def test_already_on_any_branch_blocks(self, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.git_ops.current_branch", lambda: "shared/Payment")
        with pytest.raises(SystemExit):
            check_branch("Other", "vps")


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


class TestUndoHandler:

    def test_undo_on_main_aborts(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "main")
        orchestrate("undo")
        assert "Checkout a feature branch before running undo" in capsys.readouterr().out

    def test_undo_detached_head_aborts(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "")
        orchestrate("undo")
        assert "Detached HEAD" in capsys.readouterr().out

    def test_undo_with_target_rejected(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "shared/Payment")
        orchestrate("undo shared/Payment")
        assert "undo takes no target" in capsys.readouterr().out

    def test_undo_resets_branch_to_main(self, capsys: object, monkeypatch: object) -> None:
        monkeypatch.setattr("_orchestrator.commands.current_branch", lambda: "shared/Payment")
        calls: list[list[str]] = []

        def fake_run(cmd: list[str], **kwargs: object) -> object:
            calls.append(cmd)
            return type("R", (), {"returncode": 0, "stdout": "", "stderr": ""})()

        monkeypatch.setattr("_orchestrator.commands.subprocess.run", fake_run)
        orchestrate("undo")
        out = capsys.readouterr().out
        assert ["git", "fetch", "origin"] in calls
        assert ["git", "checkout", "main"] in calls
        assert ["git", "reset", "--hard", "origin/main"] in calls
        assert ["git", "clean", "-fd"] in calls
        assert ["git", "branch", "-D", "shared/Payment"] in calls
        assert ["git", "push", "origin", "--delete", "shared/Payment"] in calls
        assert "matches main exactly" in out


class TestKnownPrefixes:

    def test_includes_all_commands(self) -> None:
        expected = {"new", "feature", "do", "modify", "delete", "move", "merge", "undo", "deploy", "scaffold", "scan"}
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
