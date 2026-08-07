# Data Access Compliance — Principles

*Technology-agnostic data layer rules.*

## Separation
- Business logic MUST NOT contain raw database calls. Data access lives behind a dedicated layer (repository/manager/DAO).
- Handler receives a connection/session as a parameter — does not create or manage it.
- No SQL or query construction outside the data access layer.

## Connection Management
- Connections opened at the boundary (controller/middleware), passed down.
- Context managers for connection lifecycle.
- No raw connection handling in business logic.

## Transactions
- Managed at the application/service layer, not per-query.
- Rollback on error, commit on success — explicit, never implicit.

## Validation
- Input validation at the boundary before reaching data access.
- Data layer assumes validated input.

## Testing
- Data access layer testable with real or in-memory database.
- Business logic testable without a database (mock the data layer).
