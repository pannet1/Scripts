# Web Layer Compliance — Principles

*Technology-agnostic HTTP/API layer rules.*

## Separation of Concerns

| Layer | Responsibility | Banned |
|-------|---------------|--------|
| **Controller** | Parse input, call handler, format response | Business logic |
| **Handler** (domain) | Pure business rules | Framework imports, I/O, DB calls |
| **Schema** (validation) | Input/output validation | Logic of any kind |

## Rules
- Controller is a thin shell — zero business logic.
- Handler never imports the web framework, never reads files, never calls external APIs.
- Schema does validation only.

## Input Validation
- Validate at the boundary.
- Return standard error responses for validation failures.

## Error Handling
- Validation errors → 4xx.
- Business logic errors → typed exceptions, caught at the boundary.
- Unexpected errors → 500.
- No try/except in controllers for business logic failures — let them propagate.

## Routing
- No manual route registration per feature — auto-discovery or convention.
- Routes grouped by domain/feature.

## WebSockets
- One connection per session, multiplexed to subscribers.
- Callbacks receive data only — no framework coupling in business logic.
