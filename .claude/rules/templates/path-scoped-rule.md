---
paths:
  - "src/<Area>/**"
  - "test/<Area>.UnitTests/**"
---
# <Area> rules

<!--
Copy this into a CONSUMING repo's own `.claude/rules/` — path-scoped rules are
project-specific and do NOT belong in the shared set. Claude Code activates the
file only when a touched path matches a `paths:` glob, so it's the right home
for narrow, binding domain invariants that would be noise everywhere else.
-->

- State the invariants that must hold in this area (constants defined once,
  units/winding, routing through a single classifier, etc.).
- Name the single source of truth for shared values so no local copies appear.
- Tie "add a fixture / parity test in the same PR" requirements to this area.
