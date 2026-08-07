# Python Compliance — Principles

*Technology-agnostic rules that apply regardless of framework or library choices.*

## Tooling

| Rule | Detail |
|------|--------|
| **Version** | `>=3.13, <3.14` — pinned via `.python-version` at repo root. `uv python pin 3.13` to set. |
| **Package manager** | `uv` only. Never `pip`, `poetry`, `conda`. |
| **Dependencies** | All deps in `pyproject.toml`. No `requirements.txt` (except `uv export` for deploy). |

## Code Standards

### Type Annotations (PEP 484)
- Every function/method signature MUST have type annotations on ALL parameters and return type.
- Module-level variables MUST be annotated.
- Use `from __future__ import annotations` as the first import (after any shebang/docstring).
- Use `Optional[X]` for nullable values.
- Use `list[X]`, `dict[K, V]`, `tuple[X, ...]` (Python 3.10+ syntax).
- Class `__init__` MUST have `-> None`.
- Pytest fixtures MUST have return type annotation.

### Zero Comments
- No `# comment` lines in source code (except shebang on executable scripts and `# noqa`).
- Docstrings (triple-quoted strings) ARE allowed.

### No Emojis
- No emoji characters in any text file.

### No `print()`
- All output goes through the project's logging system. Never `print()`.

### Imports
- Grouped: stdlib, third-party, local — with blank lines between groups.
- All imports at top of file.

### Secrets
- No secrets in git-tracked files.

## Testing
- Unit tests for every new feature.
- `pytest` only.
- Tests cover: happy path, empty state, error edges.
