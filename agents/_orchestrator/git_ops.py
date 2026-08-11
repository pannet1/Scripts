import subprocess
import sys

from .config import REPO_ROOT


def current_branch() -> str:
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True, text=True, cwd=str(REPO_ROOT),
        check=False)
        return result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return "(unknown)"


def open_branches() -> list[str]:
    """Local branches other than main (merged or not)."""
    try:
        result = subprocess.run(
            ["git", "for-each-ref", "--format=%(refname:short)", "refs/heads"],
            capture_output=True, text=True, cwd=str(REPO_ROOT),
            check=False)
        return [l.strip() for l in result.stdout.split("\n") if l.strip() and l.strip() != "main"]
    except (OSError, subprocess.SubprocessError):
        return []


def guard_open_branches() -> list[str]:
    """Return open (non-main) branches, printing a block banner if any exist."""
    pending = open_branches()
    if pending:
        print("=" * 60)
        print("BLOCKED: Other branches are open. Merge or delete them first:")
        for b in pending:
            print(f"  {b}")
        print("=" * 60)
    return pending


def branch_exists(name: str) -> bool:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", name],
        capture_output=True, text=True, cwd=str(REPO_ROOT),
    check=False)
    return result.returncode == 0


def merge_branch(branch: str) -> tuple[bool, str]:
    """Push branch, merge into main, push main, delete branch locally and remotely.

    Returns (ok, error_message); error_message is empty on success.
    """
    steps = (
        ("push", ["git", "push", "origin", branch]),
        ("checkout main", ["git", "checkout", "main"]),
        ("merge", ["git", "merge", branch]),
        ("push main", ["git", "push", "origin", "main"]),
    )
    for label, cmd in steps:
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO_ROOT), check=False)
        if result.returncode != 0:
            return False, f"git {label} failed: {result.stderr.strip()}"
        if result.stdout.strip():
            print(result.stdout.strip())
    subprocess.run(["git", "push", "origin", "--delete", branch],
                   capture_output=True, text=True, cwd=str(REPO_ROOT), check=False)
    subprocess.run(["git", "branch", "-D", branch],
                   capture_output=True, text=True, cwd=str(REPO_ROOT), check=False)
    return True, ""


def check_branch(action: str, domain: str = "") -> str:
    branch = current_branch()

    if branch and branch != "main" and not branch.startswith("main"):
        print("=" * 60)
        print(f"You are already on branch '{branch}'.")
        print("Complete and merge this branch first, then try again.")
        print("=" * 60)
        sys.exit(1)

    if branch == "main" or branch.startswith("main"):
        if guard_open_branches():
            sys.exit(1)
        target = f"{domain}/{action}" if domain else action
        if branch_exists(target):
            print(f"[Orchestrator] Branch '{target}' exists. Switching to it.")
            subprocess.run(["git", "checkout", target], cwd=str(REPO_ROOT), check=False)
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
