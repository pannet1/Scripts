# Tech: PostgreSQL

- **Driver**: `asyncpg` (preferred) or `psycopg` (async variant).
- **Pool**: connection pool managed at app startup, injected into handlers.
- **Access**: repository pattern via `db/repository.py`. Handlers receive a repository instance.
- **Migrations**: Alembic (or project's designated tool).
- **Banned**: raw connection handling in business logic, synchronous drivers.
- **Schema**: SQL via migrations. Pydantic for data shapes.
