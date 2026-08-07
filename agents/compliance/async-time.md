# Async & Time Compliance — Principles

*Technology-agnostic async and time handling rules.*

## Async I/O
- ALL I/O operations are async: file reads, network calls, database queries.
- Use the project's designated async runtime.
- Never use blocking calls in async code.

### Banned in Async Contexts

| Synchronous (banned) | Async replacement |
|---------------------|-------------------|
| `time.sleep(n)` | `asyncio.sleep(n)` |
| `requests.get/post` | Project's async HTTP client |
| `open()` / `.read()` / `.write()` | `aiofiles` or project's async file API |
| Synchronous DB drivers | Project's async DB driver |

## Time Handling

### Rules
- Use the project's designated time library — never mix libraries.
- All time operations (parsing, formatting, arithmetic, timezone) use the same library.
- No bare `import datetime`, `import time`, or `import calendar` if the project uses an alternative.

### Common Swap Patterns

| Stdlib | Project library equivalent |
|--------|---------------------------|
| `datetime.now()` | `project_lib.now()` |
| `datetime.strptime()` | `project_lib.from_format()` / `project_lib.parse()` |
| `datetime.timedelta` | `project_lib.duration()` / `project_lib.period()` |
| `time.sleep()` | `asyncio.sleep()` |
