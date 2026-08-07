# Tech: SQLite

- **Driver**: `aiosqlite` — raw SQL, no ORM.
- **Access**: all DB ops go through `db/manager.py`. `get_db()` returns a context manager for `sqlite3.Connection`.
- **Rule**: files outside `db/` MUST NOT use `conn.execute()` or `.execute(` directly.
- **Handlers**: receive `conn: sqlite3.Connection` as parameter.
- **Banned**: SQLAlchemy, Flask-SQLAlchemy, Django ORM, Alembic.
- **Schema**: raw SQL for definitions. Pydantic for data shapes, not ORM models.
