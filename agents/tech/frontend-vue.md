# Tech: Vue 3

- **Framework**: Vue 3 with Composition API.
- **Language**: TypeScript for all new code.
- **Styling**: Tailwind CSS (if configured).
- **State**: Pinia for global state. Prefer composable-local state first.
- **Testing**: Vitest.
- **Pattern**: Composable pattern — `use*()` composables hold all state/logic. Components are presentational.
- **Structure**: Feature-first — `features/<domain>/<ActionName>/` with Page, Components, Composable, Tests.
- **Shared**: `shared/components/` for generic UI primitives only — zero business logic.
