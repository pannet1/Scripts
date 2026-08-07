# Logging Compliance — Principles

*Technology-agnostic observability rules.*

## Mandatory
- All output uses the project's structured logging system.
- Never `print()` — use `logger.info()`, `logger.warning()`, `logger.error()`, `logger.debug()`.
- Never `import logging` or `logging.getLogger()` directly — use the project's abstraction.

## Logger per Module
- Every file gets its own logger instance, named after the module.
- Defined at module level, right after imports.

## Levels

| Situation | Level |
|-----------|-------|
| Normal operation | `info` |
| Expected edge case | `warning` |
| Failure requiring attention | `error` |
| Debugging detail | `debug` |

## Context
- Include correlation IDs for request tracing where applicable.
- Log enough context to debug without leaking secrets.
