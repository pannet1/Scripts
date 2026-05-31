#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

from _orchestrator.commands import orchestrate
from _orchestrator.config import MODEL_CONFIG


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Orchestrator Agent -- decompose and dispatch feature work.",
        usage="%(prog)s feature/X [--prompt <file>]",
    )
    parser.add_argument(
        "command",
        nargs="*",
        help="e.g. feature/YourFeature / do/YourFeature / modify/YourFeature",
    )
    parser.add_argument(
        "--prompt", "-p",
        help="Path to a prompt file with multi-sentence feature logic (relative to repo root)",
    )
    parser.add_argument(
        "--model", "-m",
        help="Override Zen API model for this run (e.g. --model claude-sonnet-4-5)",
    )
    parser.add_argument(
        "--no-controller", action="store_true",
        help="Skip Controller.py generation (for background workers)",
    )
    args = parser.parse_args()
    if args.model:
        MODEL_CONFIG.write_text(json.dumps({"model": args.model}) + "\n")
        print(f"[Orchestrator] Model set to: {args.model}\n")
    if not args.command:
        parser.print_help()
        print()
        print("Commands:")
        print("  ./.agents/orchestrator.py YourFeature                (auto-resolves to modify/)")
        print("  ./.agents/orchestrator.py new/YourFeature            (scaffold new feature)")
        print("  ./.agents/orchestrator.py do/YourFeature             (run backend agent)")
        print("  ./.agents/orchestrator.py modify/YourFeature         (amend existing spec)")
        print("  ./.agents/orchestrator.py bugfix/YourFeature         (document defect)")
        print("  ./.agents/orchestrator.py delete/YourFeature         (remove feature)")
        print("  ./.agents/orchestrator.py scaffold                   (init project)")
        print("  ./.agents/orchestrator.py scan                       (discover existing features)")
        sys.exit(1)
    return args


if __name__ == "__main__":
    args = parse_args()
    request = " ".join(args.command)
    prompt_content = ""
    if args.prompt:
        path = Path(args.prompt)
        if path.suffix == ".md" and path.exists():
            prompt_content = path.read_text().strip()
        else:
            prompt_content = args.prompt.strip()
    orchestrate(request, prompt_content, no_controller=args.no_controller)
