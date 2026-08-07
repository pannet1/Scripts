# Frontend Compliance — Principles

*Technology-agnostic UI layer rules.*

## Separation of Concerns
- State/logic lives in composables/hooks — not in components or templates.
- Components are presentational: receive state, emit events.
- Pages act as controllers: load the composable/hook, wire to template.

## Feature-First Structure
- Every feature self-contained in its own directory:
  - Page / view component
  - Sub-components
  - State composable / hook
  - Tests
- Shared components directory holds only generic UI primitives — zero business logic.

## State Management
- Framework reactivity first (composable-local state).
- Global store only for state shared across unrelated features.
- No business logic in stores — stores hold state + API-calling actions.

## Testing
- Test state logic (composables/hooks/stores) in isolation.
- Use the project's designated test framework.

## Styling
- Use the project's configured approach (utility classes, CSS modules, etc.).
- No inline styles in production code.
