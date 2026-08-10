"""Tests for scaffold_project.py — project scaffolding logic."""

import json
import sys
from pathlib import Path

import pytest

# Add agents/ dir to path so we can import scaffold_project
_AGENTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_AGENTS))

import scaffold_project as sp

# ── parse_tech_stack ───────────────────────────────────────────────

class TestParseTechStack:
    def test_detects_python(self) -> None:
        stack = sp.parse_tech_stack("python")
        assert "python" in stack
        assert stack["python"]["present"] == ""

    def test_detects_web_framework(self) -> None:
        stack = sp.parse_tech_stack("python, fastapi, sqlite")
        assert stack["web"]["framework"] == "fastapi"

    def test_detects_db(self) -> None:
        stack = sp.parse_tech_stack("python, fastapi, postgres")
        assert stack["db"]["engine"] == "postgres"

    def test_detects_frontend(self) -> None:
        stack = sp.parse_tech_stack("python, fastapi, sqlite, vue")
        assert stack["frontend"]["framework"] == "vue"

    def test_detects_multiple_techs(self) -> None:
        stack = sp.parse_tech_stack("python 3.13, fastapi, postgresql, vue, pendulum")
        assert stack["python"]["present"] == ""
        assert stack["web"]["framework"] == "fastapi"
        assert stack["db"]["engine"] == "postgres"
        assert stack["frontend"]["framework"] == "vue"
        assert stack["time"]["library"] == "pendulum"

    def test_unknown_tech_returns_empty(self) -> None:
        stack = sp.parse_tech_stack("some random text without matches")
        assert stack == {}


# ── _read_python_version ───────────────────────────────────────────

class TestReadPythonVersion:
    def test_reads_from_compliance_file(self) -> None:
        constraint, short = sp._read_python_version()
        # Must match what compliance/python.md says
        assert constraint.startswith(">=")
        assert "3.13" in constraint or "3.12" in constraint
        assert short.count(".") == 1  # major.minor format

    def test_returns_tuple(self) -> None:
        constraint, short = sp._read_python_version()
        assert isinstance(constraint, str)
        assert isinstance(short, str)
        assert len(constraint) > 0
        assert len(short) > 0


# ── create_python_version ──────────────────────────────────────────

class TestCreatePythonVersion:
    def test_three_thirteen(self) -> None:
        assert sp.create_python_version("3.13") == "3.13\n"

    def test_major_minor_patch(self) -> None:
        assert sp.create_python_version("3.13.2") == "3.13\n"

    def test_major_only(self) -> None:
        assert sp.create_python_version("3") == "3\n"

    def test_empty_string(self) -> None:
        assert sp.create_python_version("") == "\n"


# ── create_features_json ───────────────────────────────────────────

class TestCreateFeaturesJson:
    def test_minimal_stack(self) -> None:
        stack = {"python": {"present": ""}}
        cfg = sp.create_features_json(stack)
        assert cfg["features_dir"] == "features"
        assert cfg["known_features"] == {}
        assert cfg["stack"]["python"]["present"] == ""

    def test_with_frontend_adds_apps(self) -> None:
        stack = {"python": {"present": ""}, "frontend": {"framework": "vue"}}
        cfg = sp.create_features_json(stack)
        assert "apps" in cfg
        assert "frontend" in cfg["apps"]
        assert "features_dir" in cfg["apps"]["frontend"]

    def test_no_frontend_no_apps(self) -> None:
        stack = {"python": {"present": ""}, "web": {"framework": "fastapi"}}
        cfg = sp.create_features_json(stack)
        assert "apps" not in cfg


# ── create_gitignore ───────────────────────────────────────────────

class TestCreateGitignore:
    def test_contains_data(self) -> None:
        content = sp.create_gitignore({"python": {"present": ""}})
        assert "data/" in content

    def test_contains_python_entries(self) -> None:
        content = sp.create_gitignore({"python": {"present": ""}})
        assert "__pycache__/" in content
        assert "*.pyc" in content
        assert ".venv/" in content
        assert ".python-version" in content

    def test_db_entries_for_postgres(self) -> None:
        content = sp.create_gitignore({"python": {"present": ""}, "db": {"engine": "postgres"}})
        assert "*.db" in content
        assert "*.sqlite" in content

    def test_no_db_entries_for_sqlite(self) -> None:
        content = sp.create_gitignore({"python": {"present": ""}, "db": {"engine": "sqlite"}})
        assert "*.db" not in content


# ── create_spec_md ─────────────────────────────────────────────────

class TestCreateSpecMd:
    def test_contains_stack_section(self) -> None:
        content = sp.create_spec_md({"python": {"present": ""}})
        assert "## Stack" in content

    def test_contains_runtime_line(self) -> None:
        content = sp.create_spec_md({"python": {"present": ""}})
        assert "Runtime" in content
        assert "uv monorepo" in content

    def test_includes_web_framework_section(self) -> None:
        content = sp.create_spec_md({
            "python": {"present": ""},
            "web": {"framework": "fastapi"},
        })
        assert "Fastapi" in content

    def test_includes_db_section(self) -> None:
        content = sp.create_spec_md({
            "python": {"present": ""},
            "db": {"engine": "sqlite"},
        })
        assert "Database (Sqlite)" in content or "aiosqlite" in content

    def test_includes_frontend_section(self) -> None:
        content = sp.create_spec_md({
            "python": {"present": ""},
            "frontend": {"framework": "vue"},
        })
        assert "Vue" in content

    def test_directory_layout_present(self) -> None:
        content = sp.create_spec_md({"python": {"present": ""}})
        assert "features/" in content
        assert "data/" in content
        assert "agents/" in content
        assert "SPEC.md" in content


# ── create_shared_logger ───────────────────────────────────────────

class TestCreateSharedLogger:
    def test_default_stdlib_logger(self) -> None:
        content = sp.create_shared_logger({"python": {"present": ""}})
        assert "import logging" in content
        assert "logging.basicConfig" in content

    def test_shared_logger(self) -> None:
        content = sp.create_shared_logger({"logging": {"library": "shared"}})
        assert "logging.getLogger" in content

    def test_structlog_logger(self) -> None:
        content = sp.create_shared_logger({"logging": {"library": "structlog"}})
        assert "import structlog" in content

    def test_contains_logging_func(self) -> None:
        content = sp.create_shared_logger({"python": {"present": ""}})
        assert "logging_func" in content


# ── scaffold integration test ──────────────────────────────────────

class TestScaffoldIntegration:

    def test_scaffold_creates_expected_files(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Run the full scaffold() function in a temp git repo."""
        monkeypatch.chdir(tmp_path)
        import subprocess
        subprocess.run(["git", "init"], cwd=str(tmp_path), capture_output=True, check=False)

        stack = {
            "python": {"present": ""},
            "web": {"framework": "fastapi"},
            "db": {"engine": "sqlite"},
        }
        # Re-import after chdir so REPO_ROOT picks up tmp_path
        import importlib
        importlib.reload(sp)

        result = sp.scaffold(stack, force=False)

        assert result == 0
        assert (tmp_path / ".features.json").exists()
        assert (tmp_path / "features").is_dir()
        assert (tmp_path / "data").is_dir()
        assert (tmp_path / "shared").is_dir()
        assert (tmp_path / "shared" / "__init__.py").exists()
        assert (tmp_path / "shared" / "logger.py").exists()
        assert (tmp_path / "SPEC.md").exists()
        assert (tmp_path / ".python-version").exists()
        assert (tmp_path / ".gitignore").exists()

        # Verify .features.json content
        cfg = json.loads((tmp_path / ".features.json").read_text())
        assert cfg["features_dir"] == "features"
        assert "stack" in cfg

    def test_scaffold_refuses_existing(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.chdir(tmp_path)
        import subprocess
        subprocess.run(["git", "init"], cwd=str(tmp_path), capture_output=True, check=False)

        (tmp_path / ".features.json").write_text("{}")
        stack = {"python": {"present": ""}}

        import importlib
        importlib.reload(sp)

        result = sp.scaffold(stack, force=False)
        assert result == 1  # Refused
