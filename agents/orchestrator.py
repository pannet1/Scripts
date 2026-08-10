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
        usage="%(prog)s <action> <domain/Feature> [inline prompt] [--prompt <file>]",
    )
    parser.add_argument(
        "command",
        nargs="*",
        help="e.g. new Payments / modify shared/Payment / do Payment",
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
    parser.add_argument(
        "--app", "-a", default="",
        help="App context: 'private' for admin features (uses features/ dir instead of web/features/)",
    )
    args = parser.parse_args()
    if args.model:
        MODEL_CONFIG.write_text(json.dumps({"model": args.model}) + "\n")
        print(f"[Orchestrator] Model set to: {args.model}\n")
    if not args.command:
        parser.print_help()
        print()
        print("Usage:  ./.agents/orchestrator.py <action> <domain/Feature> [inline prompt]")
        print()
        print("Actions:")
        print("  new      <Feature> [description]     scaffold new feature")
        print("  modify   <domain/Feature> \"prompt\"   amend existing spec")
        print("  bugfix   <domain/Feature> \"prompt\"   document defect")
        print("  do       <domain/Feature>            run backend agent")
        print("  delete   <domain/Feature>            remove feature")
        print("  rename   <OldName> <NewName>         rename feature")
        print()
        print("Utilities:")
        print("  merge                                merge current branch to main")
        print("  scaffold                             init project")
        print("  scan                                 discover existing features")
        print()
        print("Examples:")
        print("  ./.agents/orchestrator.py new Payments \"auction payment wallet flow\"")
        print("  ./.agents/orchestrator.py modify shared/Payment \"share screenshot separately\"")
        print("  ./.agents/orchestrator.py do Payment")
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
    orchestrate(request, prompt_content, no_controller=args.no_controller, app=args.app)
