import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional

from .config import REPO_ROOT, AGENTS_DIR, FEATURES_DIR, FEATURES_CONFIG, KNOWN_FEATURES, DOMAIN_KEYWORDS, RUNNER, PERSONAS_DIR, load_features_config, _detect_features_dir
from .templates import SPEC_TEMPLATE, DEFAULT_OVERVIEW, CODE_TEMPLATES
from .zen_api import generate_spec_with_ai
from .git_ops import current_branch, unmerged_branches, branch_exists, check_branch, read_prompt_file
from .features import resolve_feature, find_feature_dir, register_feature_in_json, unregister_feature_from_json, _scan_existing_features


def read_file(path: Path) -> str:
    with open(path) as f:
        return f.read()


def format_spec_overview(overview: str) -> str:
    if overview:
        return overview
    return DEFAULT_OVERVIEW


def resolve_change_prompt(rest: str, prompt_content: str, feature_name: str, prefix: str) -> str:
    if prompt_content:
        return prompt_content
    if not rest:
        print("=" * 60)
        print(f"ERROR: `{prefix}/{feature_name}` requires a prompt.")
        print()
        print("Options:")
        print(f'  ./.agents/orchestrator.py {prefix}/{feature_name} --prompt path/to/prompt.md')
        print(f'  ./.agents/orchestrator.py {prefix}/{feature_name} "describe your change in words"')
        print(f'  ./.agents/orchestrator.py {prefix}/{feature_name} path/to/prompt.md')
        print("=" * 60)
        sys.exit(1)
    path = Path(rest)
    if path.suffix == ".md":
        resolved = REPO_ROOT / rest
        if not resolved.exists():
            print(f"[Orchestrator] Prompt file not found: {resolved}")
            sys.exit(1)
        return resolved.read_text().strip()
    return rest.strip()


def scaffold_new_feature(domain: str, action: str, overview: str = "", no_controller: bool = False) -> Path:
    if domain:
        base = FEATURES_DIR / domain
        slice_dir = base / action
    else:
        slice_dir = FEATURES_DIR / action
    slice_dir.mkdir(parents=True, exist_ok=True)

    if overview:
        ai_spec = generate_spec_with_ai(domain, action, overview)
        if ai_spec:
            (slice_dir / "spec.md").write_text(ai_spec)
        else:
            overview_text = format_spec_overview(overview)
            spec = SPEC_TEMPLATE.format(
                domain_title=domain.title() if domain else action,
                action=action,
                overview=overview_text,
            ).rstrip("\n")
            (slice_dir / "spec.md").write_text(spec)
            print("[Orchestrator] Zen API unavailable — using template spec.md", file=sys.stderr)
    else:
        spec = SPEC_TEMPLATE.format(
            domain_title=domain.title() if domain else action,
            action=action,
            overview=DEFAULT_OVERVIEW,
        ).rstrip("\n")
        (slice_dir / "spec.md").write_text(spec)

    for fname, template in CODE_TEMPLATES.items():
        if no_controller and fname == "Controller.py":
            continue
        content = template.format(action=action).lstrip("\n")
        (slice_dir / fname).write_text(content)

    (slice_dir / "__init__.py").touch()

    label = f"{domain}/{action}" if domain else action
    note = " (no controller)" if no_controller else ""
    print(f"\nScaffolded new feature: {label}{note}\n")
    return slice_dir


def amend_spec(feature_dir: Path, heading: str, branch_prefix: str, feature_name: str = "") -> None:
    display = feature_name or feature_dir.name
    print(f"\n{'='*60}\n{heading} for {display}")
    print(f"Spec amended. Run do when ready:\n")
    print(f"  ./.agents/orchestrator.py do/{display}")
    print("=" * 60)


def _rewrite_spec_with_ai(feature_dir: Path, change_prompt: str, section: str) -> bool:
    spec_path = feature_dir / "spec.md"
    existing = spec_path.read_text() if spec_path.exists() else ""
    heading = section.replace(" Request", "").replace(" Resolution", "")

    amendment = (
        f"\n## {heading}\n\n"
        f"{change_prompt}\n\n"
        "### Constraints\n"
        "* <!-- added by modification -->\n"
    )
    if existing:
        spec_path.write_text(existing + amendment)
    else:
        spec_path.write_text(amendment)
    print(f"[Orchestrator] spec.md amended with structured '{heading}' section")
    return True


def run_runner(persona_key: str, target: Path, task: str, error_path: Optional[Path] = None) -> bool:
    persona_path = PERSONAS_DIR / f"{persona_key}_agent.md"
    if not persona_path.exists():
        print(f"[Orchestrator] Persona not found: {persona_path}", file=sys.stderr)
        return False

    cmd = [
        sys.executable, str(RUNNER),
        "--persona", str(persona_path),
        "--target", str(target),
        "--task", task,
        "--api",
    ]
    if error_path:
        cmd += ["--error", str(error_path)]

    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    return result.returncode == 0


def do_scaffold() -> None:
    print("[Orchestrator] Scanning project structure...")
    found_dir = _detect_features_dir(REPO_ROOT)

    if found_dir.is_dir():
        print(f"[Orchestrator] Detected features directory: {found_dir.relative_to(REPO_ROOT)}")
    else:
        print(f"[Orchestrator] No features directory found. Will use: {found_dir.relative_to(REPO_ROOT)}")

    features = _scan_existing_features(found_dir)
    known: dict[str, str] = {}
    keywords: dict[str, list[str]] = {}
    for fname, domain in features.items():
        known[fname] = domain
        keyword = fname.lower().replace("feature", "").replace("handler", "").replace("controller", "")
        if keyword and keyword not in keywords:
            keywords[keyword] = [domain, fname]

    payload: dict[str, Any] = {
        "known_features": known,
        "domain_keywords": keywords,
    }
    FEATURES_CONFIG.write_text(json.dumps(payload, indent=2) + "\n")

    if features:
        print(f"[Orchestrator] Created {FEATURES_CONFIG.name} with {len(known)} features")
    else:
        print(f"[Orchestrator] No features found. Created empty {FEATURES_CONFIG.name}")

    print()
    print(f"[Orchestrator] Project ready. Files:")
    print(f"  .features.json         — feature registry ({len(known)} features)")
    print(f"  .agents/               — agentic toolkit (symlink to ~/.agents)")
    print()
    print("Next: run a feature command")
    print(f"  ./.agents/orchestrator.py feature/YourFeature")


_KNOWN_PREFIXES = frozenset({
    "new", "feature", "modify", "bugfix", "do", "delete", "merge", "deploy", "scaffold",
})


def _extract_feature_from_path(path_str: str) -> Optional[str]:
    candidates = [FEATURES_DIR]
    known_map = dict(KNOWN_FEATURES)
    for domain_key, (dom, act) in list(DOMAIN_KEYWORDS.items()):
        known_map[act] = dom

    resolved = REPO_ROOT / path_str
    if not resolved.exists():
        return None

    parts = resolved.resolve().parts
    features_parts = FEATURES_DIR.resolve().parts
    try:
        idx = next(i for i in range(len(parts) - len(features_parts) + 1)
                   if parts[i:i + len(features_parts)] == features_parts)
        remainder = parts[idx + len(features_parts):]
    except StopIteration:
        remainder = ()

    if len(remainder) >= 2:
        domain, feature_name = remainder[0], remainder[1]
        if (FEATURES_DIR / domain / feature_name).is_dir():
            return feature_name
    if remainder:
        last = remainder[-1]
        if known_map.get(last) or find_feature_dir(last):
            return last

    candidate = resolved.stem if resolved.suffix else resolved.name
    if find_feature_dir(candidate):
        return candidate
    return None


def _resolve_input_to_feature(raw_input: str) -> Optional[str]:
    cleaned = raw_input.strip().strip("/")
    feature_dir = find_feature_dir(cleaned)
    if feature_dir:
        return feature_dir.name

    parts = cleaned.split("/")
    for i in range(1, len(parts)):
        candidate = parts[-i]
        feature_dir = find_feature_dir(candidate)
        if feature_dir:
            return feature_dir.name

    path_feature = _extract_feature_from_path(cleaned)
    if path_feature:
        return path_feature

    for domain_dir in FEATURES_DIR.iterdir():
        if not domain_dir.is_dir() or domain_dir.name.startswith("_"):
            continue
        for entry in domain_dir.iterdir():
            if entry.is_dir() and not entry.name.startswith("_"):
                if entry.name.lower() == cleaned.lower():
                    return entry.name

    name = Path(cleaned).name if "/" in cleaned else cleaned
    return name


def _find_feature_or_resolve(raw: str) -> Optional[Path]:
    feature_dir = resolve_feature(raw)
    if feature_dir:
        return feature_dir
    name = _resolve_input_to_feature(raw)
    if name and name != raw:
        feature_dir = resolve_feature(name)
    return feature_dir


def orchestrate(request: str, prompt_content: str = "", no_controller: bool = False) -> None:
    cmd = request.strip().split(None, 1)
    verb = cmd[0] if cmd else ""
    rest = cmd[1] if len(cmd) > 1 else ""

    if "/" in verb:
        raw_prefix, action = verb.split("/", 1)
        prefix = raw_prefix.lower()
        action = action.strip()
    else:
        prefix = verb.lower()
        action = rest.strip()

    if prefix in ("new", "scaffold"):
        prefix = "feature"

    if prefix not in _KNOWN_PREFIXES:
        print("[Orchestrator] Unknown command.")
        print()
        print("Commands:")
        print('  ./.agents/orchestrator.py modify/path/to/file.py  (resolve + modify)')
        print('  ./.agents/orchestrator.py new/ManageCandle        (scaffold new feature)')
        print('  ./.agents/orchestrator.py do/ManageCandle         (run backend agent)')
        print('  ./.agents/orchestrator.py bugfix/ManageCandle     (document defect)')
        print('  ./.agents/orchestrator.py delete/ManageCandle     (remove feature)')
        sys.exit(1)

    if prefix == "scaffold" and not action:
        do_scaffold()
        return

    if prefix == "feature":
        description = resolve_change_prompt(rest, prompt_content, action, "feature")
        domain = KNOWN_FEATURES.get(action, "")
        if not domain:
            for _key, (_dom, _act) in DOMAIN_KEYWORDS.items():
                if _key in action.lower() or _act.lower() == action.lower():
                    domain = _dom
                    break
        check_branch(action, "feature")
        scaffold_new_feature(domain, action, description, no_controller=no_controller)
        if domain:
            register_feature_in_json(action, domain)
        print("=" * 60)
        print("THEN RUN:")
        print(f"  ./.agents/orchestrator.py do/{action}")
        print("=" * 60)
        return

    if prefix == "do":
        user_feature_name = action or rest
        feature_dir = _find_feature_or_resolve(user_feature_name)
        if not feature_dir:
            print(f"[Orchestrator] Feature not found: {user_feature_name}.")
            print(f"  First run: ./.agents/orchestrator.py new/{user_feature_name}")
            return
        if not (feature_dir / "spec.md").exists():
            print(f"[Orchestrator] No spec.md found.")
            print(f"  First run: ./.agents/orchestrator.py new/{user_feature_name}")
            return

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
                return
            target = f"feature/{display}"
            print(f"[Orchestrator] On main with clean slate. Auto-creating branch: {target}")
            subprocess.run(["git", "checkout", "-b", target], cwd=str(REPO_ROOT))
            branch = target

        if branch.startswith("bugfix/"):
            task = f"Fix bug in {display}: write a failing test that reproduces the defect, then patch Handler.py per the Defect Resolution section in spec.md"
            commit_type = "fix"
        elif branch.startswith("modify/"):
            task = f"Modify {display} per the amended spec.md"
            commit_type = "feat"
        else:
            task = f"Implement {display} per its spec.md"
            commit_type = "feat"

        print(f"[Orchestrator] Generating code for {display}...")
        ok = run_runner("backend", feature_dir, task)
        if ok:
            domain = feature_dir.parent.name if feature_dir.parent != FEATURES_DIR else ""
            register_feature_in_json(feature_dir.name, domain)
            print(f"\n{'='*60}\nALL TESTS PASSED.\n")
            print("Run these commands to commit and push:\n")
            print(f"  git add {feature_dir}")
            print(f'  git commit -m "{commit_type}: {feature_dir.name}"')
            print(f"  git push origin {branch}\n")
            print("Then open a Pull Request on GitHub:")
            print(f"  https://github.com/pannet1/fti-holdings/pull/new/{branch}")
            print("=" * 60)
        else:
            print(f"\n{'='*60}")
            print("IMPLEMENTATION FAILED. The auto-QA loop exhausted its attempts.")
            print("Copy the error output above and tell the AI:")
            print(f'  "The auto-QA loop failed for {feature_dir.name}. Here is the output: ..."')
            print("=" * 60)
        return

    if prefix == "modify":
        feature_name = action or rest
        feature_dir = _find_feature_or_resolve(feature_name)
        if not feature_dir:
            print(f"[Orchestrator] Feature not found: {feature_name}")
            return
        resolved_name = feature_dir.name
        change_prompt = resolve_change_prompt(rest, prompt_content, resolved_name, "modify")
        _rewrite_spec_with_ai(feature_dir, change_prompt, "Modification Request")
        check_branch(resolved_name, "modify")
        amend_spec(
            feature_dir,
            heading="CONTRACT AMENDMENT",
            branch_prefix="modify",
            feature_name=resolved_name,
        )
        return

    if prefix == "bugfix":
        feature_name = action or rest
        feature_dir = _find_feature_or_resolve(feature_name)
        if not feature_dir:
            print(f"[Orchestrator] Feature not found: {feature_name}")
            return
        resolved_name = feature_dir.name
        change_prompt = resolve_change_prompt(rest, prompt_content, resolved_name, "bugfix")
        _rewrite_spec_with_ai(feature_dir, change_prompt, "Defect Resolution")
        check_branch(resolved_name, "bugfix")
        amend_spec(
            feature_dir,
            heading="DEFECT DOCUMENTATION",
            branch_prefix="bugfix",
            feature_name=resolved_name,
        )
        return

    if prefix == "delete":
        feature_name = action or rest
        feature_dir = resolve_feature(feature_name)
        branch = current_branch()
        target_branches = [f"feature/{feature_name}", f"modify/{feature_name}", f"bugfix/{feature_name}"]
        on_target = branch in target_branches
        found_any = False

        if feature_dir and feature_dir.exists():
            import shutil
            shutil.rmtree(feature_dir)
            print(f"[Orchestrator] Deleted feature directory: {feature_dir}")
            found_any = True

        unregister_feature_from_json(feature_name, feature_dir)

        subprocess.run(["git", "stash"], cwd=str(REPO_ROOT), capture_output=True)
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
        return

    if prefix == "merge":
        feature_name = action or rest
        if not feature_name:
            branch = current_branch()
            for br_prefix in ("feature/", "modify/", "bugfix/"):
                if branch.startswith(br_prefix):
                    feature_name = branch[len(br_prefix):]
                    break
        if not feature_name:
            print("[Orchestrator] No feature name given and cannot infer from current branch.")
            return
        feature_dir = find_feature_dir(feature_name)
        if not feature_dir or not feature_dir.exists():
            print(f"[Orchestrator] Feature not found: {feature_name}")
            return
        branch = current_branch()
        if branch == "main":
            for br_prefix in ("feature/", "modify/", "bugfix/"):
                candidate = br_prefix + feature_name
                if branch_exists(candidate):
                    branch = candidate
                    print(f"[Orchestrator] Checking out {branch}...")
                    subprocess.run(["git", "checkout", branch],
                                   capture_output=True, cwd=str(REPO_ROOT))
                    break
            if branch == "main":
                print(f"[Orchestrator] No branch found for '{feature_name}'.")
                return
        if branch.startswith("bugfix/"):
            commit_type = "fix"
        else:
            commit_type = "feat"
        print(f"[Orchestrator] Staging {feature_dir}...")
        r1 = subprocess.run(["git", "add", str(feature_dir)], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r1.returncode != 0:
            print(f"[Orchestrator] git add failed: {r1.stderr.strip()}")
            return
        msg_body = f"{commit_type}: {feature_name}"
        print(f"[Orchestrator] Committing: {msg_body}")
        r2 = subprocess.run(["git", "commit", "-m", msg_body], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r2.returncode != 0:
            combined = r2.stdout + r2.stderr
            if "nothing to commit" in combined:
                print("[Orchestrator] Nothing to commit — already up to date.")
            else:
                print(f"[Orchestrator] git commit failed: {r2.stderr.strip()}")
                return
        print(r2.stdout.strip())
        print(f"[Orchestrator] Pushing {branch}...")
        r3 = subprocess.run(["git", "push", "origin", branch], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r3.returncode != 0:
            print(f"[Orchestrator] git push failed: {r3.stderr.strip()}")
            return
        print(r3.stdout.strip())
        print(f"[Orchestrator] Merging {branch} into main...")
        r4 = subprocess.run(["git", "checkout", "main"], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r4.returncode != 0:
            print(f"[Orchestrator] git checkout main failed: {r4.stderr.strip()}")
            return
        r5 = subprocess.run(["git", "merge", branch], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r5.returncode != 0:
            print(f"[Orchestrator] git merge failed: {r5.stderr.strip()}")
            return
        print(r5.stdout.strip())
        r6 = subprocess.run(["git", "push", "origin", "main"], capture_output=True, text=True, cwd=str(REPO_ROOT))
        if r6.returncode != 0:
            print(f"[Orchestrator] git push main failed: {r6.stderr.strip()}")
            return
        print(f"[Orchestrator] Deleting remote branch {branch}...")
        subprocess.run(["git", "push", "origin", "--delete", branch],
                       capture_output=True, cwd=str(REPO_ROOT))
        print(f"[Orchestrator] Deleting local branch {branch}...")
        subprocess.run(["git", "branch", "-D", branch],
                       capture_output=True, cwd=str(REPO_ROOT))
        print(f"[Orchestrator] Done. {feature_name} merged to main.")
        return

    if prefix == "deploy":
        print("=" * 60)
        print("Deploy mode: follow DEPLOYMENT.md manually.")
        print("=" * 60)
        return

    print("[Orchestrator] Unknown request.")
    print()
    print("Commands:")
    print('  ./.agents/orchestrator.py ManageCandle               (auto-resolves to modify/)')
    print('  ./.agents/orchestrator.py new/ManageCandle           (scaffold new feature)')
    print('  ./.agents/orchestrator.py do/ManageCandle            (run backend agent)')
    print('  ./.agents/orchestrator.py modify/ManageCandle        (amend existing spec)')
    print('  ./.agents/orchestrator.py bugfix/ManageCandle        (document defect)')
    print('  ./.agents/orchestrator.py delete/ManageCandle        (remove feature)')
    print('  ./.agents/orchestrator.py scaffold                   (init project)')
