import subprocess
import sys
from pathlib import Path
from typing import Optional

from .config import REPO_ROOT


def current_branch() -> str:
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True, text=True, cwd=str(REPO_ROOT),
        )
        return result.stdout.strip()
    except Exception:
        return "(unknown)"


def unmerged_branches() -> list[str]:
    try:
        result = subprocess.run(
            ["git", "branch", "--no-merged", "main"],
            capture_output=True, text=True, cwd=str(REPO_ROOT),
        )
        lines = [l.strip() for l in result.stdout.split("\n") if l.strip() and not l.strip().startswith("*")]
        return [l for l in lines if l != "main"]
    except Exception:
        return []


def branch_exists(name: str) -> bool:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", name],
        capture_output=True, text=True, cwd=str(REPO_ROOT),
    )
    return result.returncode == 0


def check_branch(action: str, prefix: str = "feature") -> str:
    branch = current_branch()

    for p in ("feature/", "modify/", "bugfix/"):
        if branch.startswith(p):
            print("=" * 60)
            print(f"You are already on branch '{branch}'.")
            print("Complete and merge this branch first, then try again.")
            print("=" * 60)
            sys.exit(1)

    if branch == "main" or branch.startswith("main"):
        pending = unmerged_branches()
        if pending:
            print("=" * 60)
            print("BLOCKED: Unmerged branches still exist. Merge them first:")
            for b in pending:
                print(f"  {b}")
            print("=" * 60)
            sys.exit(1)
        target = f"{prefix}/{action}"
        if branch_exists(target):
            print(f"[Orchestrator] Branch '{target}' exists. Switching to it.")
            subprocess.run(["git", "checkout", target], cwd=str(REPO_ROOT))
        else:
            print(f"[Orchestrator] Creating branch: {target}")
            subprocess.run(["git", "checkout", "-b", target], cwd=str(REPO_ROOT), check=True)
        return target
    elif branch == "(unknown)":
        pass
    return branch


def read_prompt_file(prompt_path: str) -> str:
    path = REPO_ROOT / prompt_path
    if not path.exists():
        print(f"[Orchestrator] Prompt file not found: {path}", file=sys.stderr)
        sys.exit(1)
    return path.read_text().strip()
