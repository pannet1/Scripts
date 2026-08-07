# Tech: Shared Logger Pattern

Every `.py` file:

```python
from shared.logger import logging_func
logger = logging_func(__name__)
```

## Rules
- `from shared.logger import logging_func` — never `import logging`.
- `logger = logging_func(__name__)` — never `logging.getLogger(__name__)`.
- All output via logger — never `print()`.
- Handler classes: module-level `logger = ...` right after imports.

## Fallback
If `shared/logger.py` doesn't exist, create it as a thin wrapper exporting `logging_func = ...` backed by the project's async logging utility.
