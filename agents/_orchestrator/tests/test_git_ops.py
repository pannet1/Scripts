from pathlib import Path
from unittest.mock import patch

import pytest

from _orchestrator.git_ops import read_prompt_file, current_branch, branch_exists


class TestReadPromptFile:

    def test_reads_prompt_file(self, tmp_path: Path) -> None:
        prompt = tmp_path / "my_prompt.md"
        prompt.write_text("implement this feature")
        with patch("_orchestrator.git_ops.REPO_ROOT", tmp_path):
            result = read_prompt_file("my_prompt.md")
        assert result == "implement this feature"

    def test_reads_strips_whitespace(self, tmp_path: Path) -> None:
        prompt = tmp_path / "my_prompt.md"
        prompt.write_text("  implement this feature  \n")
        with patch("_orchestrator.git_ops.REPO_ROOT", tmp_path):
            result = read_prompt_file("my_prompt.md")
        assert result == "implement this feature"

    def test_exits_on_missing_file(self, tmp_path: Path) -> None:
        with patch("_orchestrator.git_ops.REPO_ROOT", tmp_path):
            with pytest.raises(SystemExit):
                read_prompt_file("nonexistent.md")


class TestCurrentBranch:

    def test_returns_branch_name(self) -> None:
        branch = current_branch()
        assert isinstance(branch, str)
        assert len(branch) > 0

    def test_returns_unknown_on_error(self) -> None:
        with patch("subprocess.run") as mock_run:
            mock_run.side_effect = Exception("git not found")
            result = current_branch()
        assert result == "(unknown)"


class TestBranchExists:

    def test_main_exists(self) -> None:
        assert branch_exists("main") is True

    def test_nonexistent_returns_false(self) -> None:
        assert branch_exists("nonexistent_branch_xyzzy_123") is False
