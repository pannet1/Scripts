import subprocess
from dataclasses import dataclass
from typing import Optional

from .config import REPO_ROOT
from .feature import (
    FeatureTarget,
    ModifyResolution,
    ProjectFeatures,
    feature_from_branch,
    load_project,
    register_target,
    unregister_feature,
)
from .git_ops import branch_exists, check_branch, current_branch, unmerged_branches
from .helpers import (
    _KNOWN_PREFIXES,
    _parse_request,
    _resolve_current_file,
    _resolve_prompt_for_implicit,
    _rewrite_spec_with_ai,
    amend_spec,
    do_scaffold,
    resolve_change_prompt,
    run_runner,
    run_scaffolder,
    scaffold_new_feature,
)


@dataclass
class CommandResult:
    success: bool = True
    next_action: str = ""


def _cmd_scaffold() -> CommandResult:
    do_scaffold()
    return CommandResult(next_action='./.agents/orchestrator.py new YourFeature')


def _cmd_scan() -> CommandResult:
    ok = run_scaffolder(["scan"])
    return CommandResult(success=ok, next_action='new <domain/Feature> "prompt" or modify <domain/Feature> "prompt"')


def _cmd_feature(target: FeatureTarget, rest: str, prompt_content: str, no_controller: bool) -> CommandResult:
    description = resolve_change_prompt(rest, prompt_content, target.name, "feature")
    feature_dir = scaffold_new_feature(target, description, no_controller=no_controller)
    if feature_dir and feature_dir.is_dir():
        check_branch(target.name, target.domain)
        return CommandResult(next_action=f"./.agents/orchestrator.py do {target.domain}/{target.name}")
    print(f"[Orchestrator] Failed to scaffold feature '{target.name}'.")
    return CommandResult(success=False)


def _cmd_do(target: Optional[FeatureTarget], raw: str, app: str) -> CommandResult:
    if not raw:
        print("[Orchestrator] No feature name given and cannot infer from current branch.")
        return CommandResult(next_action='checkout or create a feature branch first — new <domain/Feature> "prompt"')
    if not target:
        print(f"[Orchestrator] Feature not found: {raw}.")
        return CommandResult(next_action=f'./.agents/orchestrator.py new {raw}')
    if not (target.dir / "spec.md").exists():
        print("[Orchestrator] No spec.md found.")
        return CommandResult(next_action=f'./.agents/orchestrator.py new {raw}')

    display = target.name
    feature_dir = target.dir

    branch = current_branch()
    if branch == "main" or branch.startswith("main"):
        pending = unmerged_branches()
        if pending:
            print("=" * 60)
            print("BLOCKED: Unmerged branches still exist. Merge them first:")
            for b in pending:
                print(f"  {b}")
            print("=" * 60)
            return CommandResult(next_action="merge the listed branches first")
        target_branch = f"{target.domain}/{display}"
        print(f"[Orchestrator] On main with clean slate. Auto-creating branch: {target_branch}")
        subprocess.run(["git", "checkout", "-b", target_branch], cwd=str(REPO_ROOT))
        branch = target_branch

    spec_text = (feature_dir / "spec.md").read_text() if (feature_dir / "spec.md").exists() else ""
    if "## Modification" in spec_text:
        task = f"Modify {display} per the amended spec.md"
    else:
        task = f"Implement {display} per its spec.md"
    commit_type = "feat"

    print(f"[Orchestrator] Generating code for {display}...")
    ok = run_runner("backend", feature_dir, task)
    if ok:
        register_target(target)
        print(f"\n{'='*60}\nALL TESTS PASSED.\n")
        print(f"[Orchestrator] Staging {feature_dir}...")
        r1 = subprocess.run(["git", "add", str(feature_dir)], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r1.returncode != 0:
            print(f"[Orchestrator] git add failed: {r1.stderr.strip()}")
            print("You may need to commit and merge manually.")
            return CommandResult(success=False, next_action="resolve the git error above, then commit and merge manually")
        msg_body = f"{commit_type}: {display}"
        print(f"[Orchestrator] Committing: {msg_body}")
        r2 = subprocess.run(["git", "commit", "-m", msg_body], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r2.returncode != 0:
            combined = r2.stdout + r2.stderr
            if "nothing to commit" in combined:
                print("[Orchestrator] Nothing to commit — already up to date.")
            else:
                print(f"[Orchestrator] git commit failed: {r2.stderr.strip()}")
                print("You may need to commit and merge manually.")
                return CommandResult(success=False, next_action="resolve the git error above, then commit and merge manually")
        print(r2.stdout.strip())
        print(f"[Orchestrator] Pushing {branch}...")
        r3 = subprocess.run(["git", "push", "origin", branch], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r3.returncode != 0:
            print(f"[Orchestrator] git push failed: {r3.stderr.strip()}")
            print("You may need to push and merge manually.")
            return CommandResult(success=False, next_action="resolve the git error above, then push and merge manually")
        print(r3.stdout.strip())
        print(f"[Orchestrator] Merging {branch} into main...")
        r4 = subprocess.run(["git", "checkout", "main"], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r4.returncode != 0:
            print(f"[Orchestrator] git checkout main failed: {r4.stderr.strip()}")
            print("You may need to merge manually.")
            return CommandResult(success=False, next_action="resolve the git error above, then merge manually")
        r5 = subprocess.run(["git", "merge", branch], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r5.returncode != 0:
            print(f"[Orchestrator] git merge failed: {r5.stderr.strip()}")
            print("You may need to resolve conflicts and merge manually.")
            return CommandResult(success=False, next_action="resolve the merge conflicts, then push main")
        print(r5.stdout.strip())
        r6 = subprocess.run(["git", "push", "origin", "main"], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r6.returncode != 0:
            print(f"[Orchestrator] git push main failed: {r6.stderr.strip()}")
            print("You may need to push manually.")
            return CommandResult(success=False, next_action="push main manually, then delete the remote branch")
        print(f"[Orchestrator] Deleting remote branch {branch}...")
        subprocess.run(["git", "push", "origin", "--delete", branch],
                       capture_output=True, cwd=str(REPO_ROOT))
        print(f"[Orchestrator] Deleting local branch {branch}...")
        subprocess.run(["git", "branch", "-D", branch],
                       capture_output=True, cwd=str(REPO_ROOT))
        print(f"[Orchestrator] Done. {display} merged to main.")
        return CommandResult(next_action='scan to list features, or new <domain/Feature> "prompt" to start the next one')
    print(f"\n{'='*60}")
    print("IMPLEMENTATION FAILED. The auto-QA loop exhausted its attempts.")
    print("Copy the error output above and tell the AI:")
    print(f'  "The auto-QA loop failed for {display}. Here is the output: ..."')
    print("=" * 60)
    return CommandResult(success=False, next_action="fix the failing tests above, then run do again — or undo to discard this branch")


def _cmd_modify(res: Optional[ModifyResolution], raw: str, rest: str, prompt_content: str, implicit: bool) -> CommandResult:
    if res is None:
        print("[Orchestrator] No feature name given (modify expects a domain/Feature target, inline prompt, prompt file, or nvim context).")
        return CommandResult(next_action='pass a domain/Feature target with an inline prompt')
    if res.amend is None:
        print(f"[Orchestrator] Feature '{res.name}' not found.")
        return CommandResult(success=False, next_action=f'./.agents/orchestrator.py new {res.name}')
    if implicit:
        change_prompt = _resolve_prompt_for_implicit(rest, prompt_content)
        if not change_prompt:
            print("[Orchestrator] No prompt provided.")
            return CommandResult(next_action='provide an inline prompt, a prompt file, or nvim context')
    else:
        change_prompt = resolve_change_prompt(rest, prompt_content, res.name, "modify")
    heading = "Modification Request"
    if not res.amend.dir.exists():
        scaffold_new_feature(res.amend, res.scaffold_overview, no_controller=True)
    _rewrite_spec_with_ai(res.amend.dir, change_prompt, heading)
    check_branch(res.name, res.branch_domain)
    amend_spec(
        res.amend.dir,
        heading="CONTRACT AMENDMENT",
        branch_prefix="modify",
        feature_name=res.name,
    )
    return CommandResult(next_action=f'./.agents/orchestrator.py do {res.name} to implement the amended spec')


def _cmd_delete(target: Optional[FeatureTarget], raw: str, app: str) -> CommandResult:
    if not raw:
        print("[Orchestrator] No feature name given and cannot infer from current branch.")
        return CommandResult(next_action='checkout a feature branch first, or pass a feature name')
    target_branches = [f"{target.domain}/{raw}"] if target else [raw]
    branch = current_branch()
    on_target = branch in target_branches
    found_any = False

    if target and target.dir.exists():
        import shutil
        shutil.rmtree(target.dir)
        print(f"[Orchestrator] Deleted feature directory: {target.dir}")
        found_any = True

    unregister_feature(raw, target.dir if target else None, target.config_path if target else None)

    if on_target:
        subprocess.run(["git", "checkout", "main"], cwd=str(REPO_ROOT))
        subprocess.run(["git", "branch", "-D", branch], cwd=str(REPO_ROOT))
        print(f"[Orchestrator] Deleted branch: {branch}")
        found_any = True
    else:
        for tb in target_branches:
            if branch_exists(tb):
                subprocess.run(["git", "branch", "-D", tb], cwd=str(REPO_ROOT))
                print(f"[Orchestrator] Deleted branch: {tb}")
                found_any = True

    if not found_any:
        print(f"[Orchestrator] Nothing to delete: feature '{raw}' not found.")
    return CommandResult(next_action='scan to list remaining features, or new <domain/Feature> "prompt" to start one')


def _cmd_merge(branch: str, name: str, target: Optional[FeatureTarget], action: str, rest: str) -> CommandResult:
    if branch == "main" or branch.startswith("main"):
        print("[Orchestrator] You are on main. Checkout a feature branch before running merge.")
        return CommandResult(next_action='checkout a feature branch, then run merge')
    if not branch or branch == "(unknown)":
        print("[Orchestrator] Detached HEAD — checkout a feature branch before running merge.")
        return CommandResult(next_action='checkout a feature branch, then run merge')
    if action or rest:
        print("[Orchestrator] merge takes no target — it merges the current branch to main.")
        return CommandResult()
    if target and target.dir.exists():
        commit_type = "feat"
        print(f"[Orchestrator] Staging {target.dir}...")
        r1 = subprocess.run(["git", "add", str(target.dir)], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r1.returncode != 0:
            print(f"[Orchestrator] git add failed: {r1.stderr.strip()}")
            return CommandResult(success=False, next_action="resolve the git error above, then merge manually")
        msg_body = f"{commit_type}: {name}"
        print(f"[Orchestrator] Committing: {msg_body}")
        r2 = subprocess.run(["git", "commit", "-m", msg_body], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r2.returncode != 0:
            combined = r2.stdout + r2.stderr
            if "nothing to commit" in combined:
                print("[Orchestrator] Nothing to commit — already up to date.")
            else:
                print(f"[Orchestrator] git commit failed: {r2.stderr.strip()}")
                return CommandResult(success=False, next_action="resolve the git error above, then merge manually")
        print(r2.stdout.strip())
    else:
        print(f"[Orchestrator] No feature dir for '{name}' — merging branch as-is.")
    print(f"[Orchestrator] Pushing {branch}...")
    r3 = subprocess.run(["git", "push", "origin", branch], capture_output=True, text=True, cwd=str(REPO_ROOT))
    if r3.returncode != 0:
        print(f"[Orchestrator] git push failed: {r3.stderr.strip()}")
        return CommandResult(success=False, next_action="resolve the git error above, then push and merge manually")
    print(r3.stdout.strip())
    print(f"[Orchestrator] Merging {branch} into main...")
    r4 = subprocess.run(["git", "checkout", "main"], capture_output=True, text=True, cwd=str(REPO_ROOT))
    if r4.returncode != 0:
        print(f"[Orchestrator] git checkout main failed: {r4.stderr.strip()}")
        return CommandResult(success=False, next_action="resolve the git error above, then merge manually")
    r5 = subprocess.run(["git", "merge", branch], capture_output=True, text=True, cwd=str(REPO_ROOT))
    if r5.returncode != 0:
        print(f"[Orchestrator] git merge failed: {r5.stderr.strip()}")
        return CommandResult(success=False, next_action="resolve the merge conflicts, then push main")
    print(r5.stdout.strip())
    r6 = subprocess.run(["git", "push", "origin", "main"], capture_output=True, text=True, cwd=str(REPO_ROOT))
    if r6.returncode != 0:
        print(f"[Orchestrator] git push main failed: {r6.stderr.strip()}")
        return CommandResult(success=False, next_action="push main manually, then delete the remote branch")
    print(f"[Orchestrator] Deleting remote branch {branch}...")
    subprocess.run(["git", "push", "origin", "--delete", branch],
                   capture_output=True, cwd=str(REPO_ROOT))
    print(f"[Orchestrator] Deleting local branch {branch}...")
    subprocess.run(["git", "branch", "-D", branch],
                   capture_output=True, cwd=str(REPO_ROOT))
    print(f"[Orchestrator] Done. {name} merged to main.")
    return CommandResult(next_action='scan to list features, or new <domain/Feature> "prompt" to start one')


def _cmd_undo(action: str, rest: str) -> CommandResult:
    branch = current_branch()
    if branch == "main" or branch.startswith("main"):
        print("[Orchestrator] You are on main. Checkout a feature branch before running undo.")
        return CommandResult(next_action='checkout a feature branch, then run undo to discard it')
    if not branch or branch == "(unknown)":
        print("[Orchestrator] Detached HEAD — checkout a feature branch before running undo.")
        return CommandResult(next_action='checkout a feature branch, then run undo to discard it')
    if action or rest:
        print("[Orchestrator] undo takes no target — it discards the current branch and resets to main.")
        return CommandResult()
    print(f"[Orchestrator] Undoing {branch}: discarding commits and resetting to main...")
    subprocess.run(["git", "fetch", "origin"], capture_output=True, text=True, cwd=str(REPO_ROOT))
    r1 = subprocess.run(["git", "checkout", "main"], capture_output=True, text=True, cwd=str(REPO_ROOT))
    if r1.returncode != 0:
        print(f"[Orchestrator] git checkout main failed: {r1.stderr.strip()}")
        return CommandResult(success=False)
    r2 = subprocess.run(["git", "reset", "--hard", "origin/main"], capture_output=True, text=True, cwd=str(REPO_ROOT))
    if r2.returncode != 0:
        print(f"[Orchestrator] git reset failed: {r2.stderr.strip()}")
        return CommandResult(success=False)
    subprocess.run(["git", "clean", "-fd"], capture_output=True, text=True, cwd=str(REPO_ROOT))
    subprocess.run(["git", "branch", "-D", branch], capture_output=True, text=True, cwd=str(REPO_ROOT))
    subprocess.run(["git", "push", "origin", "--delete", branch], capture_output=True, text=True, cwd=str(REPO_ROOT))
    print(f"[Orchestrator] Done. {branch} removed; working tree matches main exactly.")
    return CommandResult(next_action='new <domain/Feature> "prompt" to start fresh, or scan to list features')


def _cmd_move(old_target: Optional[FeatureTarget], new_target: Optional[FeatureTarget], rest: str, app: str) -> CommandResult:
    if not old_target or not new_target:
        print("[Orchestrator] Usage: move <OldDomain/OldFeature> <NewDomain/NewFeature>")
        return CommandResult()
    old_dir = old_target.dir
    new_dir = new_target.dir
    if new_dir.exists():
        print(f"[Orchestrator] Target '{new_target.name}' already exists at {new_dir}")
        return CommandResult(success=False)
    old_name_disk = old_target.name
    print(f"[Orchestrator] Moving {old_name_disk} -> {new_target.name}...")
    new_dir.parent.mkdir(parents=True, exist_ok=True)
    old_dir.rename(new_dir)
    unregister_feature(old_target.name, old_dir, old_target.config_path)
    register_target(new_target)
    print(f"[Orchestrator] Running tests...")
    result = subprocess.run(
        ["uv", "run", "pytest", "tests/", "--ignore=tests/test_session_lifecycle.py", "--ignore=tests/test_links.py", "-q"],
        capture_output=True, text=True, cwd=str(REPO_ROOT),
    )
    test_ok = result.returncode == 0
    if test_ok:
        last = [l for l in result.stdout.strip().split("\n") if l][-3:]
        print("\n".join(last))
        print("[Orchestrator] All tests pass.")
    else:
        print(result.stdout[-500:] if len(result.stdout) > 500 else result.stdout)
        print("[Orchestrator] Tests failed after rename. Check output above.")
    current = current_branch()
    merged = False
    old_branch = f"{old_target.domain}/{old_name_disk}"
    new_branch = f"{new_target.domain}/{new_target.name}"
    if old_branch == current:
        print(f"[Orchestrator] Renaming branch {old_branch} -> {new_branch}...")
        subprocess.run(["git", "branch", "-m", new_branch], cwd=str(REPO_ROOT))
        subprocess.run(["git", "add", str(new_dir)], cwd=str(REPO_ROOT))
        subprocess.run(["git", "commit", "-m", f"move: {old_name_disk} -> {new_target.name}"], capture_output=True, cwd=str(REPO_ROOT))
        if test_ok:
            print(f"[Orchestrator] Merging {new_branch} to main...")
            subprocess.run(["git", "push", "origin", new_branch], capture_output=True, cwd=str(REPO_ROOT))
            subprocess.run(["git", "checkout", "main"], capture_output=True, cwd=str(REPO_ROOT))
            subprocess.run(["git", "merge", new_branch], capture_output=True, cwd=str(REPO_ROOT))
            subprocess.run(["git", "push", "origin", "main"], capture_output=True, cwd=str(REPO_ROOT))
            subprocess.run(["git", "push", "origin", "--delete", new_branch], capture_output=True, cwd=str(REPO_ROOT))
            subprocess.run(["git", "branch", "-D", new_branch], capture_output=True, cwd=str(REPO_ROOT))
            print(f"[Orchestrator] Merged to main. Done.")
            merged = True
        else:
            print(f"[Orchestrator] Tests failed — branch moved to {new_branch}, not merged.")
    if not merged:
        print(f"[Orchestrator] Moved {old_name_disk} -> {new_target.name}. git add + commit manually if needed.")
        return CommandResult(success=test_ok, next_action=f'git add + commit the move, then merge {new_branch} to main')
    label = f"{new_target.domain}/{new_target.name}"
    return CommandResult(next_action=f'scan to see {label} on main')


def _split_move_target(target_str: str) -> tuple[str, str]:
    t = target_str.strip().strip('"').strip("'")
    if "/" in t:
        domain, name = t.split("/", 1)
        return domain.strip(), name.strip()
    return "", t.strip()


def _resolve_do(project: ProjectFeatures, action: str, rest: str, app: str) -> tuple[Optional[FeatureTarget], str]:
    raw = action or rest
    if not raw:
        raw = feature_from_branch(current_branch())
    if not raw:
        return None, ""
    return project.resolve(raw, app=app), raw


def _resolve_delete(project: ProjectFeatures, action: str, rest: str, app: str) -> tuple[Optional[FeatureTarget], str]:
    raw = action or rest
    if not raw:
        raw = feature_from_branch(current_branch())
    if not raw:
        return None, ""
    return project.resolve(raw, app=app), raw


_HELP_TEXT = """Usage:  ./.agents/orchestrator.py <action> <domain/Feature> [inline prompt]

Prompt commands (expect an inline prompt):
  new      <domain/Feature> "prompt"     scaffold new feature
  modify   <domain/Feature> "prompt"     amend existing spec

Branch commands (run from the feature branch):
  do                                     run backend agent
  delete                                 remove feature
  merge                                  merge current branch to main
  undo                                   discard branch, reset to main

Other:
  move     <OldDomain/OldFeature> <NewDomain/NewFeature>
  scaffold                               init project
  scan                                   discover existing features

Examples:
  ./.agents/orchestrator.py new Payments "auction payment wallet flow"
  ./.agents/orchestrator.py modify shared/Payment "share screenshot separately"
  ./.agents/orchestrator.py do Payment
"""


def dispatch(request: str, prompt_content: str = "", no_controller: bool = False, app: str = "") -> CommandResult:
    prefix, domain, action, rest = _parse_request(request)
    project = load_project(REPO_ROOT)

    if domain and not app:
        app = project.app_for_domain(domain)

    if prefix not in _KNOWN_PREFIXES:
        print("[Orchestrator] Unknown command.")
        print()
        print(_HELP_TEXT)
        return CommandResult(success=False)

    if prefix == "scaffold" and not action:
        return _cmd_scaffold()

    if prefix in ("new", "scaffold"):
        prefix = "feature"

    if prefix == "scan":
        return _cmd_scan()

    if prefix == "feature":
        target = project.target_for_new(action, domain, app)
        return _cmd_feature(target, rest, prompt_content, no_controller)

    if prefix == "do":
        target, raw = _resolve_do(project, action, rest, app)
        return _cmd_do(target, raw, app)

    if prefix == "modify":
        implicit = not action
        raw = action or rest
        if implicit:
            raw = _resolve_current_file() or ""
        res = project.resolve_modify(raw, app=app, implicit=implicit) if raw else None
        return _cmd_modify(res, raw, rest, prompt_content, implicit)

    if prefix == "delete":
        target, raw = _resolve_delete(project, action, rest, app)
        return _cmd_delete(target, raw, app)

    if prefix == "merge":
        branch = current_branch()
        name = feature_from_branch(branch)
        target = project.resolve(name) if name else None
        return _cmd_merge(branch, name, target, action, rest)

    if prefix == "undo":
        return _cmd_undo(action, rest)

    if prefix == "move":
        old_target = project.resolve(action, app=app) if action else None
        new_target = None
        if old_target and rest:
            new_domain, new_name = _split_move_target(rest)
            new_target = project.target_for_new(new_name, new_domain or old_target.domain, app)
        return _cmd_move(old_target, new_target, rest, app)

    print("[Orchestrator] Unknown request.")
    print()
    print(_HELP_TEXT)
    return CommandResult(success=False)
