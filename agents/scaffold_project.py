#!/usr/bin/env python3
"""
Project Scaffolder — bootstrap an agentic-workflow project from a tech-stack prompt.

Usage:
    python3 agents/scaffold_project.py "Python 3.13, FastAPI, PostgreSQL, Vue 3"
    python3 agents/scaffold_project.py --prompt prompt.md
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional

REPO_ROOT = Path.cwd()
AGENTS_DIR = Path(__file__).resolve().parent
COMPLIANCE_DIR = AGENTS_DIR / "compliance"
TECH_DIR = AGENTS_DIR / "tech"


# ── Tech-stack parser ──────────────────────────────────────────────

STACK_HINTS: dict[str, dict[str, str]] = {
    # python
    "python":                         {"category": "python", "key": "present", "value": ""},
    # web framework
    "fastapi":                        {"category": "web", "key": "framework", "value": "fastapi"},
    "flask":                          {"category": "web", "key": "framework", "value": "flask"},
    "django":                         {"category": "web", "key": "framework", "value": "django"},
    # database
    "sqlite":                         {"category": "db", "key": "engine", "value": "sqlite"},
    "sqlite3":                        {"category": "db", "key": "engine", "value": "sqlite"},
    "postgres":                        {"category": "db", "key": "engine", "value": "postgres"},
    "postgresql":                     {"category": "db", "key": "engine", "value": "postgres"},
    "postgres":                       {"category": "db", "key": "engine", "value": "postgres"},
    "cockroach":                      {"category": "db", "key": "engine", "value": "postgres"},
    "mysql":                          {"category": "db", "key": "engine", "value": "mysql"},
    "mariadb":                        {"category": "db", "key": "engine", "value": "mysql"},
    "mongodb":                        {"category": "db", "key": "engine", "value": "mongodb"},
    "redis":                          {"category": "db", "key": "engine", "value": "redis"},
    "dynamodb":                       {"category": "db", "key": "engine", "value": "dynamodb"},
    # orm
    "sqlalchemy":                     {"category": "db", "key": "orm", "value": "sqlalchemy"},
    "prisma":                         {"category": "db", "key": "orm", "value": "prisma"},
    "django orm":                     {"category": "db", "key": "orm", "value": "django"},
    # frontend
    "vue":                            {"category": "frontend", "key": "framework", "value": "vue"},
    "vue 3":                          {"category": "frontend", "key": "framework", "value": "vue"},
    "react":                          {"category": "frontend", "key": "framework", "value": "react"},
    "svelte":                         {"category": "frontend", "key": "framework", "value": "svelte"},
    "angular":                        {"category": "frontend", "key": "framework", "value": "angular"},
    "solid":                          {"category": "frontend", "key": "framework", "value": "solid"},
    "qwik":                           {"category": "frontend", "key": "framework", "value": "qwik"},
    # time
    "pendulum":                       {"category": "time", "key": "library", "value": "pendulum"},
    "arrow":                          {"category": "time", "key": "library", "value": "arrow"},
    # logging
    "structlog":                      {"category": "logging", "key": "library", "value": "structlog"},
    "loguru":                         {"category": "logging", "key": "library", "value": "loguru"},
    "shared.logger":                  {"category": "logging", "key": "library", "value": "shared"},
    "shared logger":                  {"category": "logging", "key": "library", "value": "shared"},
    # async
    "asyncio":                        {"category": "async", "key": "runtime", "value": "asyncio"},
    "trio":                           {"category": "async", "key": "runtime", "value": "trio"},
    "anyio":                          {"category": "async", "key": "runtime", "value": "anyio"},
    # testing
    "pytest":                         {"category": "testing", "key": "framework", "value": "pytest"},
    "vitest":                         {"category": "testing", "key": "framework", "value": "vitest"},
    "jest":                           {"category": "testing", "key": "framework", "value": "jest"},
}

# Reverse lookup: category -> { tech_file_key: suffix }
TECH_FILE_MAP: dict[str, dict[str, str]] = {
    "db": {
        "sqlite": "db-sqlite.md",
        "postgres": "db-postgres.md",
    },
    "web": {
        "fastapi": "web-fastapi.md",
    },
    "frontend": {
        "vue":  "frontend-vue.md",
    },
    "time": {
        "pendulum": "time-pendulum.md",
    },
    "logging": {
        "shared": "logging-shared.md",
    },
}


def parse_tech_stack(prompt: str) -> dict[str, dict[str, str]]:
    """Parse a free-form prompt into structured tech-stack choices."""
    lower = prompt.lower()
    stack: dict[str, dict[str, str]] = {}

    # Collect all matches sorted by length descending (longest match wins)
    matches: list[tuple[int, str, dict]] = []
    for hint, info in STACK_HINTS.items():
        if hint in lower:
            cat = info["category"]
            key = info["key"]
            val = info.get("value", hint)
            value_index = lower.index(hint)
            matches.append((value_index, hint, {"category": cat, "key": key, "value": val}))

    # Sort by position in text, then by length (longer match = more specific)
    matches.sort(key=lambda x: (x[0], -len(x[1])))

    for _, _, info in matches:
        cat = info["category"]
        key = info["key"]
        val = info["value"]
        if cat not in stack:
            stack[cat] = {}
        # Don't overwrite a more specific match with a shorter one
        if key not in stack[cat]:
            stack[cat][key] = val

    return stack


# ── Compliance reader ──────────────────────────────────────────────

def _read_python_version() -> tuple[str, str]:
    """Read Python version from compliance/python.md.

    Returns (constraint, short_version) e.g. ('>=3.13, <3.14', '3.13').
    Falls back to ('>=3.13, <3.14', '3.13') if file unreadable.
    """
    comp_file = COMPLIANCE_DIR / "python.md"
    if comp_file.exists():
        text = comp_file.read_text()
        import re
        m = re.search(r'Version.*?`(>=(\d+\.\d+),\s*<\d+\.\d+)`', text)
        if m:
            constraint = m.group(1)
            short = m.group(2)
            return constraint, short
    return ">=3.13, <3.14", "3.13"



# ── Directory & file creators ──────────────────────────────────────




def create_python_version(ver: str) -> str:
    """Content for .python-version (uv expects just major.minor)."""
    parts = ver.split(".")
    return f"{parts[0]}.{parts[1]}\n" if len(parts) >= 2 else f"{ver}\n"


def create_features_json(stack: dict) -> dict[str, Any]:
    """Build .features.json from parsed stack."""
    cfg: dict[str, Any] = {
        "features_dir": "features",
        "known_features": {},
        "domain_keywords": {},
    }

    # Add apps config for frontend if present
    fe = stack.get("frontend", {})
    if fe.get("framework"):
        apps: dict[str, Any] = {
            "frontend": {
                "features_dir": "apps/frontend/src/features",
                "domains": [],
            }
        }
        cfg["apps"] = apps

    # Set stack metadata for agent discovery
    cfg["stack"] = {}
    for cat, choices in stack.items():
        cfg["stack"][cat] = choices

    return cfg


def create_gitignore(stack: dict) -> str:
    lines = [
        "# Runtime data (gitignored, may contain secrets)",
        "data/",
        "",
        "# Python",
        "__pycache__/",
        "*.pyc",
        ".venv/",
        ".python-version",
        "",
    ]
    db = stack.get("db", {})
    if db.get("engine") in ("postgres", "mysql", "mongodb"):
        lines.append("# Local DB files")
        lines.append("*.db")
        lines.append("*.sqlite")
        lines.append("")
    return "\n".join(lines)
def create_spec_md(stack: dict) -> str:
    lines = [
        "# SPEC.md — Technical Architecture Blueprint",
        "",
        "## Stack",
    ]

    constraint, _ = _read_python_version()
    lines.append(f"- **Runtime**: Python {constraint}, uv monorepo")

    web = stack.get("web", {})
    fw = web.get("framework", "").title()
    if fw:
        lines.append(f"- **Framework**: {fw}")

    db = stack.get("db", {})
    eng = db.get("engine", "")
    orm_ = db.get("orm", "")
    if eng:
        if orm_:
            lines.append(f"- **DB**: {eng.title()} via {orm_}")
        else:
            lines.append(f"- **DB**: {eng.title()} (raw SQL)")
    if orm_ and not eng:
        lines.append(f"- **ORM**: {orm_.title()}")

    tl = stack.get("time", {})
    lib = tl.get("library", "")
    if lib:
        lines.append(f"- **Time**: {lib}")

    lo = stack.get("logging", {})
    lib = lo.get("library", "")
    if lib:
        lines.append(f"- **Logging**: {lib}")

    testing = stack.get("testing", {})
    tf = testing.get("framework", "")
    if tf:
        lines.append(f"- **Testing**: {tf}")

    fe = stack.get("frontend", {})
    ff = fe.get("framework", "")
    if ff:
        lines.append(f"- **Frontend**: {ff.title()} (TypeScript)")

    if stack.get("async", {}).get("runtime"):
        lines.append(f"- **Async**: {stack['async']['runtime']}")

    lines += [
        "",
        "## Directory Layout",
        "```",
        "repo-root/",
        "├── main.py            # Application entry point",
        "├── features/          # Vertical-slice feature directories",
        "│   └── <ActionName>/",
        "│       ├── Schema.py     # Pydantic/v2 input validation",
        "│       ├── Handler.py    # Pure business logic",
        "│       ├── Controller.py # Thin HTTP shell (omit for background workers)",
        "│       ├── Tests.py      # Unit tests",
        "│       └── spec.md       # Feature specification",
        "├── data/             # Runtime config & data (gitignored)",
        "├── shared/           # Cross-feature utilities (logger, errors)",
        "├── agents/           # AI harness (symlinked)",
        "├── .features.json    # Feature registry",
        "├── SPEC.md           # THIS FILE",
        "└── pyproject.toml    # uv workspace root",
        "```",
        "",
        "## Vertical Slice Architecture",
        "Every feature lives at `features/<ActionName>/` with:",
        " - **Schema.py** — Pydantic v2 input validation. No logic.",
        " - **Handler.py** — Pure business logic. No I/O, no framework imports.",
        " - **Controller.py** — Thin shell: parse, call Handler, format response.",
        " - **Tests.py** — Unit tests (happy path + empty state + error edges).",
        " - **spec.md** — Business terms and acceptance criteria.",
        "",
        "## Agentic Workflow",
        "Prompt file: `prompt.md` at repo root describes the task.",
        "Orchestrator generates SPEC.md (this file) as the architectural blueprint.",
        "All agents ingest SPEC.md + compliance/ + tech/ rules.",
        "",
    ]

    # Add tech-specific sections
    if eng:
        lines.append(f"## Database ({eng.title()})")
        if eng == "sqlite":
            lines += [
                "- **Driver**: aiosqlite (raw SQL, no ORM)",
                "- **Access**: `db/manager.py` — `get_db()` returns context manager for `sqlite3.Connection`",
                "- **Rule**: Files outside `db/` MUST NOT use `conn.execute()` directly",
                "- **Banned**: SQLAlchemy, Flask-SQLAlchemy, Django ORM, Alembic",
            ]
        elif eng == "postgres":
            lines += [
                "- **Driver**: asyncpg (preferred) or psycopg async",
                "- **Pool**: connection pool at app startup, injected into handlers",
                "- **Migrations**: Alembic",
                "- **Banned**: raw connection handling in business logic, synchronous drivers",
            ]
        lines.append("")

    if fw:
        lines.append(f"## Web Framework ({fw.title()})")
        if fw.lower() == "fastapi":
            lines += [
                "- **Validation**: Pydantic v2 BaseModel — no dataclasses, no TypedDict",
                "- **Routes**: `APIRouter(prefix=..., tags=[...])` per feature",
                "- **Discovery**: auto-scan features/ at startup",
                "- **Error handling**: ValidationError → 422, business exceptions → typed → boundary catch",
                "- **Auth**: `HTTPBearer` + `jose` JWT",
            ]
        lines.append("")

    if ff:
        lines.append(f"## Frontend ({ff.title()})")
        if ff.lower() == "vue":
            lines += [
                "- **Framework**: Vue 3 + Composition API + TypeScript",
                "- **State**: Pinia (prefer composable-local first)",
                "- **Testing**: Vitest",
                "- **Styling**: Tailwind CSS (if configured)",
                "- **Pattern**: Composable `use*()` — components are presentational",
            ]
        lines.append("")

    return "\n".join(lines)


def create_shared_logger(stack: dict) -> str:
    lo = stack.get("logging", {})
    lib = lo.get("library", "")
    if lib == "shared":
        return '''"""Shared logger — thin wrapper around the project's logging utility."""
import logging


def logging_func(name: str) -> logging.Logger:
    """Return a logger for the given module name."""
    return logging.getLogger(name)
'''
    if lib == "structlog":
        return '''"""Shared logger — structlog wrapper."""
import structlog


def logging_func(name: str) -> structlog.stdlib.BoundLogger:
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.dev.ConsoleRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    return structlog.get_logger(name)
'''
    # Default: stdlib logging with basicConfig
    return '''"""Shared logger — standard library logging wrapper."""
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")


def logging_func(name: str) -> logging.Logger:
    """Return a logger for the given module name."""
    return logging.getLogger(name)
'''



def create_pyproject_toml(stack: dict) -> str:
    """Generate pyproject.toml from parsed tech stack."""
    _, short_ver = _read_python_version()
    major, minor = short_ver.split(".")
    next_minor = int(minor) + 1
    deps = []

    web = stack.get("web", {}).get("framework", "")
    if web == "fastapi":
        deps.append("fastapi>=0.115")
        deps.append("uvicorn[standard]")
    elif web == "flask":
        deps.append("flask>=3")

    db = stack.get("db", {}).get("engine", "")
    if db == "sqlite":
        deps.append("aiosqlite")

    tl = stack.get("time", {}).get("library", "")
    if tl == "pendulum":
        deps.append("pendulum>=3")

    lo = stack.get("logging", {}).get("library", "")
    if lo == "structlog":
        deps.append("structlog>=24")

    deps.append("watchdog")

    lines = [
        "[project]",
        f'name = "{REPO_ROOT.name}"',
        'version = "0.1.0"',
        f'requires-python = ">={short_ver}, <{major}.{next_minor}"',
        'description = "Agentic-workflow project"',
    ]
    if deps:
        lines.append("dependencies = [")
        for d in sorted(set(deps)):
            lines.append(f'    "{d}",')
        lines.append("]")

    lines += [
        "",
        "[build-system]",
        'requires = ["hatchling"]',
        'build-backend = "hatchling.build"',
        "",
        "[tool.hatch.build.targets.wheel]",
        'packages = ["."]',
        "",
    ]
    return "\n".join(lines)


def create_main_py(stack: dict) -> str:
    """Generate main.py entry point."""
    web = stack.get("web", {}).get("framework", "")
    lines = [
        '"""Application entry point."""',
        "import sys",
        "from pathlib import Path",
        "",
        "from shared.logger import logging_func",
        "",
        "logger = logging_func(__name__)",
        "",
        "",
        "def main() -> None:",
        '    """Run the application."""',
        '    logger.info("Starting %s", Path.cwd().name)',
    ]
    if web == "fastapi":
        lines += [
            "    # TODO: import and run FastAPI app",
            '    logger.info("FastAPI app ready")',
        ]
    else:
        lines += [
            "    # TODO: wire up feature entry points here",
            '    logger.info("No web framework configured — running headless")',
        ]
    lines += [
        "",
        "",
        'if __name__ == "__main__":',
        "    main()",
        "",
    ]
    return "\n".join(lines)

# ── Main scaffold logic ────────────────────────────────────────────

def ensure_agents_symlink() -> None:
    """Create agents/ symlink pointing to the shared agents directory."""
    agents_link = REPO_ROOT / "agents"
    if agents_link.is_symlink():
        return
    if agents_link.exists():
        print(f"  [WARN] agents/ exists but is not a symlink — skipping")
        return
    # Compute relative symlink from repo root to the Scripts agents dir
    try:
        rel = os.path.relpath(str(AGENTS_DIR), str(REPO_ROOT))
        agents_link.symlink_to(rel)
        print(f"  agents/ -> {rel}")
    except OSError as e:
        print(f"  [WARN] Could not create agents/ symlink: {e}")


def scaffold(stack: dict, force: bool = False) -> int:
    dot_features = REPO_ROOT / ".features.json"
    if dot_features.exists() and not force:
        print(f"[ERROR] {dot_features} already exists. Use --force to overwrite.")
        return 1

    print("Scaffolding project structure...")
    print()

    # 1. .features.json
    cfg = create_features_json(stack)
    dot_features.write_text(json.dumps(cfg, indent=2) + "\n")
    print(f"  {dot_features.name}")

    # 2. Directory structure
    dirs = [
        REPO_ROOT / "features",
        REPO_ROOT / "data",
        REPO_ROOT / "shared",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
        print(f"  {d.relative_to(REPO_ROOT)}/")

    # 3. pyproject.toml
    pyproject_path = REPO_ROOT / "pyproject.toml"
    if not pyproject_path.exists():
        pyproject_path.write_text(create_pyproject_toml(stack))
        print(f"  pyproject.toml")

    # 4. main.py
    main_py_path = REPO_ROOT / "main.py"
    if not main_py_path.exists():
        main_py_path.write_text(create_main_py(stack))
        print(f"  main.py")

    # 5. shared/__init__.py
    init_file = REPO_ROOT / "shared" / "__init__.py"
    init_file.touch(exist_ok=True)
    print(f"  shared/__init__.py")

    # 6. shared/logger.py
    logger_py = REPO_ROOT / "shared" / "logger.py"
    if not logger_py.exists():
        logger_py.write_text(create_shared_logger(stack))
        print(f"  shared/logger.py")

    # 7. SPEC.md
    spec_path = REPO_ROOT / "SPEC.md"
    spec_path.write_text(create_spec_md(stack))
    if not spec_path.exists():
        print(f"  {spec_path.name}")


    # 8. .gitignore
    gitignore_path = REPO_ROOT / ".gitignore"
    existing = gitignore_path.read_text().strip() if gitignore_path.exists() else ""
    new_entries = create_gitignore(stack)
    if existing:
        # Append only missing entries
        existing_lines = set(existing.splitlines())
        need = [l for l in new_entries.splitlines() if l.strip() and l not in existing_lines]
        if need:
            gitignore_path.write_text(existing + "\n" + "\n".join(need) + "\n")
            print(f"  .gitignore (updated)")
    else:
        gitignore_path.write_text(new_entries)
        print(f"  .gitignore")

    # 9. .python-version
    py_ver_path = REPO_ROOT / ".python-version"
    _, ver = _read_python_version()
    if not py_ver_path.exists():
        py_ver_path.write_text(create_python_version(ver))
        print(f"  .python-version ({ver})")

    # 10. agents/ symlink
    ensure_agents_symlink()

    # 11. Print compliance & tech file references
    print()
    used_categories = set()
    for cat, choices in stack.items():
        used_categories.add(cat)
        cat_map = TECH_FILE_MAP.get(cat, {})
        val = choices.get(list(choices.keys())[0]) if choices else ""
        tech_file = cat_map.get(val)
        if tech_file:
            print(f"  Load tech/{tech_file}  ({cat}: {val})")
        else:
            comp_file = COMPLIANCE_DIR / f"{cat}.md"
            if comp_file.exists():
                print(f"  Load compliance/{cat}.md  (principles)")

    for base in ("python", "logging", "async-time"):
        if base not in used_categories:
            p = COMPLIANCE_DIR / f"{base}.md"
            if p.exists():
                print(f"  Load compliance/{base}.md  (always)")

    print()
    print("Done. Project scaffolded.")
    print(f"  Next: write prompt.md, then run: python3 agents/orchestrator.py new/YourFeature --prompt prompt.md")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scaffold a new project for the agentic workflow.",
    )
    parser.add_argument(
        "prompt",
        nargs="*",
        help='Tech-stack description, e.g. "Python 3.13, FastAPI, SQLite, Vue 3"',
    )
    parser.add_argument(
        "--prompt", "-p",
        dest="prompt_file",
        help="Path to a prompt file with tech-stack description",
    )
    parser.add_argument(
        "--force", "-f",
        action="store_true",
        help="Overwrite existing .features.json",
    )
    args = parser.parse_args()

    prompt_text = ""
    if args.prompt_file:
        path = Path(args.prompt_file)
        if path.exists():
            prompt_text = path.read_text().strip()
        else:
            print(f"[ERROR] Prompt file not found: {path}")
            return 1
    elif args.prompt:
        prompt_text = " ".join(args.prompt)
    else:
        parser.print_help()
        print()
        print("Examples:")
        print('  python3 agents/scaffold_project.py "Python 3.13, FastAPI, PostgreSQL, Vue 3"')
        print('  python3 agents/scaffold_project.py -p prompt.md')
        return 1

    stack = parse_tech_stack(prompt_text)
    if not stack:
        print("[ERROR] Could not identify any technologies from the prompt.")
        print("  Try: 'Python 3.13, FastAPI, SQLite' or similar.")
        return 1

    print(f"Detected stack:")
    for cat, choices in stack.items():
        items = []
        for k, v in choices.items():
            if v:
                items.append(f"{k}={v}")
            else:
                items.append(k)
        print(f"  {cat}: {', '.join(items)}")
    print()

    return scaffold(stack, force=args.force)


if __name__ == "__main__":
    sys.exit(main())
