import json
import subprocess
from dataclasses import dataclass

from .config import (
    DOMAIN_KEYWORDS,
    FEATURES_CONFIG,
    FEATURES_DIR,
    KNOWN_FEATURES,
    REPO_ROOT,
    app_features_dir,
    load_features_config,
)
from .features import (
    find_feature_dir,
    register_feature_in_json,
    resolve_feature,
    unregister_feature_from_json,
)
from .git_ops import branch_exists, check_branch, current_branch, unmerged_branches
from .helpers import (
    _KNOWN_PREFIXES,
    _derive_feature_name_from_path,
    _domain_of,
    _feature_from_branch,
    _find_feature_or_resolve,
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


def _cmd_feature(domain: str, action: str, rest: str, prompt_content: str, no_controller: bool, app: str) -> CommandResult:
    description = resolve_change_prompt(rest, prompt_content, action, "feature")
    if not domain:
        domain = KNOWN_FEATURES.get(action, "")
        if not domain:
            for _key, (_dom, _act) in DOMAIN_KEYWORDS.items():
                if _key in action.lower() or _act.lower() == action.lower():
                    domain = _dom
                    break
    feature_dir = scaffold_new_feature(domain, action, description, no_controller=no_controller, app=app)
    if feature_dir and feature_dir.is_dir():
        check_branch(action, domain or "nodomain")
        register_feature_in_json(action, domain or "nodomain", app=app)
        suffix = f"do {domain}/{action}" if domain else f"do {action}"
        return CommandResult(next_action=f"./.agents/orchestrator.py {suffix}")
    print(f"[Orchestrator] Failed to scaffold feature '{action}'.")
    return CommandResult(success=False)


def _cmd_do(action: str, rest: str, app: str) -> CommandResult:
    user_feature_name = action or rest
    if not user_feature_name:
        user_feature_name = _feature_from_branch(current_branch())
    if not user_feature_name:
        print("[Orchestrator] No feature name given and cannot infer from current branch.")
        return CommandResult(next_action='checkout or create a feature branch first — new <domain/Feature> "prompt"')
    feature_dir = _find_feature_or_resolve(user_feature_name, app=app)
    if not feature_dir:
        print(f"[Orchestrator] Feature not found: {user_feature_name}.")
        return CommandResult(next_action=f'./.agents/orchestrator.py new {user_feature_name}')
    if not (feature_dir / "spec.md").exists():
        print(f"[Orchestrator] No spec.md found.")
        return CommandResult(next_action=f'./.agents/orchestrator.py new {user_feature_name}')

    display = feature_dir.name

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
        dom = _domain_of(feature_dir)
        target = f"{dom}/{display}" if dom else display
        print(f"[Orchestrator] On main with clean slate. Auto-creating branch: {target}")
        subprocess.run(["git", "checkout", "-b", target], cwd=str(REPO_ROOT))
        branch = target

    spec_text = (feature_dir / "spec.md").read_text() if (feature_dir / "spec.md").exists() else ""
    if "## Modification" in spec_text:
        task = f"Modify {display} per the amended spec.md"
    else:
        task = f"Implement {display} per its spec.md"
    commit_type = "feat"

    print(f"[Orchestrator] Generating code for {display}...")
    ok = run_runner("backend", feature_dir, task)
    if ok:
        domain = _domain_of(feature_dir)
        register_feature_in_json(feature_dir.name, domain)
        print(f"\n{'='*60}\nALL TESTS PASSED.\n")
        print(f"[Orchestrator] Staging {feature_dir}...")
        r1 = subprocess.run(["git", "add", str(feature_dir)], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r1.returncode != 0:
            print(f"[Orchestrator] git add failed: {r1.stderr.strip()}")
            print("You may need to commit and merge manually.")
            return CommandResult(success=False, next_action="resolve the git error above, then commit and merge manually")
        msg_body = f"{commit_type}: {feature_dir.name}"
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
        print(f"[Orchestrator] Done. {feature_dir.name} merged to main.")
        return CommandResult(next_action='scan to list features, or new <domain/Feature> "prompt" to start the next one')
    print(f"\n{'='*60}")
    print("IMPLEMENTATION FAILED. The auto-QA loop exhausted its attempts.")
    print("Copy the error output above and tell the AI:")
    print(f'  "The auto-QA loop failed for {feature_dir.name}. Here is the output: ..."')
    print("=" * 60)
    return CommandResult(success=False, next_action="fix the failing tests above, then run do again — or undo to discard this branch")


def _cmd_modify(action: str, rest: str, prompt_content: str, app: str) -> CommandResult:
    if not action:
        current_file = _resolve_current_file()
        if rest:
            derived = _derive_feature_name_from_path(rest)
            change_prompt = _resolve_prompt_for_implicit(rest, prompt_content)
            if not change_prompt:
                print("[Orchestrator] No prompt provided.")
                return CommandResult(next_action='provide an inline prompt, a prompt file, or nvim context')
            heading = "Modification Request"
            real_feature = find_feature_dir(derived)
            if real_feature:
                check_branch(derived, _domain_of(real_feature))
                _rewrite_spec_with_ai(real_feature, change_prompt, heading)
                amend_spec(real_feature, heading="CONTRACT AMENDMENT", branch_prefix="modify", feature_name=derived)
                return CommandResult(next_action=f'./.agents/orchestrator.py do {derived} to implement the amended spec')
            fuzzy = resolve_feature(derived)
            if fuzzy:
                check_branch(derived, _domain_of(fuzzy))
                _rewrite_spec_with_ai(fuzzy, change_prompt, heading)
                amend_spec(fuzzy, heading="CONTRACT AMENDMENT", branch_prefix="modify", feature_name=derived)
                return CommandResult(next_action=f'./.agents/orchestrator.py do {derived} to implement the amended spec')
            scaffold_new_feature("", derived, "", no_controller=True)
            feature_dir = FEATURES_DIR / "nodomain" / derived
            if feature_dir.is_dir():
                check_branch(derived, "nodomain")
                register_feature_in_json(derived, "nodomain")
                _rewrite_spec_with_ai(feature_dir, change_prompt, heading)
                amend_spec(feature_dir, heading="CONTRACT AMENDMENT", branch_prefix="modify", feature_name=derived)
                return CommandResult(next_action=f'./.agents/orchestrator.py do {derived} to implement the amended spec')
            print(f"[Orchestrator] Could not create feature '{derived}'.")
            return CommandResult(success=False)
        if current_file:
            derived = _derive_feature_name_from_path(current_file)
            change_prompt = _resolve_prompt_for_implicit(rest, prompt_content)
            if not change_prompt:
                print("[Orchestrator] No prompt provided.")
                return CommandResult(next_action='provide an inline prompt, a prompt file, or nvim context')
            heading = "Modification Request"
            real_feature = find_feature_dir(derived)
            if real_feature:
                check_branch(derived, _domain_of(real_feature))
                scaffold_new_feature("", derived, f"Modify {current_file}", no_controller=True)
                feature_dir = FEATURES_DIR / "nodomain" / derived
                if feature_dir.is_dir():
                    register_feature_in_json(derived, "nodomain")
                    _rewrite_spec_with_ai(feature_dir, change_prompt, heading)
                    amend_spec(feature_dir, heading="CONTRACT AMENDMENT", branch_prefix="modify", feature_name=derived)
                    return CommandResult(next_action=f'./.agents/orchestrator.py do {derived} to implement the amended spec')
            fuzzy = resolve_feature(derived)
            if fuzzy:
                check_branch(derived, _domain_of(fuzzy))
                scaffold_new_feature("", derived, f"Modify {current_file}", no_controller=True)
                feature_dir = FEATURES_DIR / "nodomain" / derived
                if feature_dir.is_dir():
                    register_feature_in_json(derived, "nodomain")
                    _rewrite_spec_with_ai(fuzzy, change_prompt, heading)
                    amend_spec(fuzzy, heading="CONTRACT AMENDMENT", branch_prefix="modify", feature_name=derived)
                    return CommandResult(next_action=f'./.agents/orchestrator.py do {derived} to implement the amended spec')
            print(f"[Orchestrator] Feature '{derived}' not found.")
            return CommandResult(success=False)
        print("[Orchestrator] No feature name given (modify expects a domain/Feature target, inline prompt, prompt file, or nvim context).")
        return CommandResult(next_action='pass a domain/Feature target with an inline prompt')
    feature_dir = _find_feature_or_resolve(action, app=app)
    if not feature_dir:
        resolved_path = REPO_ROOT / action
        if resolved_path.exists() and resolved_path.is_file():
            derived = _derive_feature_name_from_path(action)
            change_prompt = resolve_change_prompt(rest, prompt_content, derived, "modify")
            real_feature = find_feature_dir(derived)
            if real_feature:
                check_branch(derived, _domain_of(real_feature))
                heading = "Modification Request"
                scaffold_new_feature("", derived, f"Modify {action}", no_controller=True)
                feature_dir = FEATURES_DIR / "nodomain" / derived
                if feature_dir.is_dir():
                    register_feature_in_json(derived, "nodomain")
                    _rewrite_spec_with_ai(feature_dir, change_prompt, heading)
                    amend_spec(feature_dir, heading="CONTRACT AMENDMENT", branch_prefix="modify", feature_name=derived)
                    return CommandResult(next_action=f'./.agents/orchestrator.py do {derived} to implement the amended spec')
            else:
                print(f"[Orchestrator] Feature '{derived}' not found.")
                return CommandResult(success=False, next_action=f'./.agents/orchestrator.py new {derived}')
        print(f"[Orchestrator] Feature '{action}' not found.")
        return CommandResult(success=False, next_action=f'./.agents/orchestrator.py new {action}')
    resolved_name = feature_dir.name
    change_prompt = resolve_change_prompt(rest, prompt_content, resolved_name, "modify")
    heading = "Modification Request"
    _rewrite_spec_with_ai(feature_dir, change_prompt, heading)
    check_branch(resolved_name, _domain_of(feature_dir))
    amend_spec(
        feature_dir,
        heading="CONTRACT AMENDMENT",
        branch_prefix="modify",
        feature_name=resolved_name,
    )
    return CommandResult(next_action=f'./.agents/orchestrator.py do {resolved_name} to implement the amended spec')


def _cmd_delete(action: str, rest: str, app: str) -> CommandResult:
    feature_name = action or rest
    if not feature_name:
        feature_name = _feature_from_branch(current_branch())
    if not feature_name:
        print("[Orchestrator] No feature name given and cannot infer from current branch.")
        return CommandResult(next_action='checkout a feature branch first, or pass a feature name')
    feature_dir = resolve_feature(feature_name, app=app)
    dom = _domain_of(feature_dir)
    target_branches = [f"{dom}/{feature_name}"] if dom else [feature_name]
    branch = current_branch()
    on_target = branch in target_branches
    found_any = False

    if feature_dir and feature_dir.exists():
        import shutil
        shutil.rmtree(feature_dir)
        print(f"[Orchestrator] Deleted feature directory: {feature_dir}")
        found_any = True

    unregister_feature_from_json(feature_name, feature_dir)

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
        print(f"[Orchestrator] Nothing to delete: feature '{feature_name}' not found.")
    return CommandResult(next_action='scan to list remaining features, or new <domain/Feature> "prompt" to start one')


def _cmd_merge(action: str, rest: str) -> CommandResult:
    branch = current_branch()
    if branch == "main" or branch.startswith("main"):
        print("[Orchestrator] You are on main. Checkout a feature branch before running merge.")
        return CommandResult(next_action='checkout a feature branch, then run merge')
    if not branch or branch == "(unknown)":
        print("[Orchestrator] Detached HEAD — checkout a feature branch before running merge.")
        return CommandResult(next_action='checkout a feature branch, then run merge')
    if action or rest:
        print("[Orchestrator] merge takes no target — it merges the current branch to main.")
        return CommandResult()
    feature_name = branch.split("/", 1)[1] if "/" in branch else branch
    feature_dir = find_feature_dir(feature_name)
    if feature_dir and feature_dir.exists():
        commit_type = "feat"
        print(f"[Orchestrator] Staging {feature_dir}...")
        r1 = subprocess.run(["git", "add", str(feature_dir)], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r1.returncode != 0:
            print(f"[Orchestrator] git add failed: {r1.stderr.strip()}")
            return CommandResult(success=False, next_action="resolve the git error above, then merge manually")
        msg_body = f"{commit_type}: {feature_name}"
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
        print(f"[Orchestrator] No feature dir for '{feature_name}' — merging branch as-is.")
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
    print(f"[Orchestrator] Done. {feature_name} merged to main.")
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


def _cmd_move(action: str, rest: str, app: str) -> CommandResult:
    old_name = action
    new_target = rest.strip().strip('"').strip("'")
    if not old_name or not new_target:
        print("[Orchestrator] Usage: move <OldDomain/OldFeature> <NewDomain/NewFeature>")
        return CommandResult()
    new_domain = ""
    if "/" in new_target:
        new_domain, new_name = new_target.split("/", 1)
        new_name = new_name.strip()
    else:
        new_name = new_target
    feature_dir = resolve_feature(old_name, app=app)
    if not feature_dir or not feature_dir.exists():
        print(f"[Orchestrator] Feature not found: {old_name}")
        return CommandResult(success=False)
    parent = feature_dir.parent
    if new_domain:
        base = app_features_dir(app) if app else FEATURES_DIR
        new_dir = base / new_domain / new_name
    else:
        new_dir = parent / new_name
    if new_dir.exists():
        print(f"[Orchestrator] Target '{new_name}' already exists at {new_dir}")
        return CommandResult(success=False)
    old_name_disk = feature_dir.name
    print(f"[Orchestrator] Moving {old_name_disk} -> {new_name}...")
    new_dir.parent.mkdir(parents=True, exist_ok=True)
    feature_dir.rename(new_dir)
    features = load_features_config()
    known = features.get("known_features", {})
    if old_name_disk in known:
        old_domain = known.pop(old_name_disk)
        known[new_name] = new_domain or old_domain
        features["known_features"] = known
        keywords = features.get("domain_keywords", {})
        stale = [k for k, v in keywords.items() if len(v) >= 2 and v[1] == old_name_disk]
        for k in stale:
            del keywords[k]
        with open(FEATURES_CONFIG, "w") as f:
            json.dump(features, f, indent=2)
        print(f"[Orchestrator] Updated features.json: {old_name_disk} -> {new_name}")
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
    old_dom = _domain_of(feature_dir)
    new_dom = new_domain or old_dom
    old_branch = f"{old_dom}/{old_name_disk}" if old_dom else old_name_disk
    new_branch = f"{new_dom}/{new_name}" if new_dom else new_name
    if old_branch == current:
        print(f"[Orchestrator] Renaming branch {old_branch} -> {new_branch}...")
        subprocess.run(["git", "branch", "-m", new_branch], cwd=str(REPO_ROOT))
        subprocess.run(["git", "add", str(new_dir)], cwd=str(REPO_ROOT))
        subprocess.run(["git", "commit", "-m", f"move: {old_name_disk} -> {new_name}"], capture_output=True, cwd=str(REPO_ROOT))
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
        print(f"[Orchestrator] Moved {old_name_disk} -> {new_name}. git add + commit manually if needed.")
        return CommandResult(success=test_ok, next_action=f'git add + commit the move, then merge {new_branch} to main')
    label = f"{new_dom}/{new_name}" if new_dom else new_name
    return CommandResult(next_action=f'scan to see {label} on main')


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

    if domain and not app:
        _cfg = load_features_config()
        for _app_name, _app_cfg in _cfg.get("apps", {}).items():
            if domain in _app_cfg.get("domains", []):
                app = _app_name
                break

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
        return _cmd_feature(domain, action, rest, prompt_content, no_controller, app)

    if prefix == "do":
        return _cmd_do(action, rest, app)

    if prefix == "modify":
        return _cmd_modify(action, rest, prompt_content, app)

    if prefix == "delete":
        return _cmd_delete(action, rest, app)

    if prefix == "merge":
        return _cmd_merge(action, rest)

    if prefix == "undo":
        return _cmd_undo(action, rest)

    if prefix == "move":
        return _cmd_move(action, rest, app)

    print("[Orchestrator] Unknown request.")
    print()
    print(_HELP_TEXT)
    return CommandResult(success=False)
