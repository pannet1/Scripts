# SPEC.md — Technical Architecture Blueprint

## Stack
- **Runtime**: Python >=3.13, <3.14, uv monorepo
- **Framework**: Fastapi
- **DB**: Sqlite (raw SQL)

## Directory Layout
```
repo-root/
├── features/          # Vertical-slice feature directories
│   └── <ActionName>/
│       ├── Schema.py     # Pydantic/v2 input validation
│       ├── Handler.py    # Pure business logic
│       ├── Controller.py # Thin HTTP shell (omit for background workers)
│       ├── Tests.py      # Unit tests
│       └── spec.md       # Feature specification
├── data/             # Runtime config & data (gitignored)
├── shared/           # Cross-feature utilities (logger, errors)
├── agents/           # AI harness (symlinked)
├── .features.json    # Feature registry
├── SPEC.md           # THIS FILE
└── pyproject.toml    # uv workspace root
```

## Vertical Slice Architecture
Every feature lives at `features/<ActionName>/` with:
 - **Schema.py** — Pydantic v2 input validation. No logic.
 - **Handler.py** — Pure business logic. No I/O, no framework imports.
 - **Controller.py** — Thin shell: parse, call Handler, format response.
 - **Tests.py** — Unit tests (happy path + empty state + error edges).
 - **spec.md** — Business terms and acceptance criteria.

## Agentic Workflow
Prompt file: `prompt.md` at repo root describes the task.
Orchestrator generates SPEC.md (this file) as the architectural blueprint.
All agents ingest SPEC.md + compliance/ + tech/ rules.

## Database (Sqlite)
- **Driver**: aiosqlite (raw SQL, no ORM)
- **Access**: `db/manager.py` — `get_db()` returns context manager for `sqlite3.Connection`
- **Rule**: Files outside `db/` MUST NOT use `conn.execute()` directly
- **Banned**: SQLAlchemy, Flask-SQLAlchemy, Django ORM, Alembic

## Web Framework (Fastapi)
- **Validation**: Pydantic v2 BaseModel — no dataclasses, no TypedDict
- **Routes**: `APIRouter(prefix=..., tags=[...])` per feature
- **Discovery**: auto-scan features/ at startup
- **Error handling**: ValidationError → 422, business exceptions → typed → boundary catch
- **Auth**: `HTTPBearer` + `jose` JWT
