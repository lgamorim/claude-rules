# Overlay — Persistence (EF Core)

Add when the project maps entities with Entity Framework Core.

- ORM exception to the records rule: EF-mapped entities that require mutable,
  parameterless-constructible state may remain classes with settable
  properties. This is the *only* sanctioned exception to core's "prefer records
  / `readonly`" guidance.
- Keep mapping in the `DbContext` (`OnModelCreating`) or
  `IEntityTypeConfiguration<T>` types — not scattered as data annotations on
  domain types.
- Schema changes go through EF migrations checked into the repo; never
  hand-edit the database.
- Anything asserting **provider behavior** — SQL translation, migrations,
  constraints, transactions, concurrency tokens — belongs under
  `.IntegrationTests` against a real engine (Testcontainers/Npgsql). An
  in-memory shim silently diverges from the real provider and gives false
  confidence exactly where it matters.
- The in-memory provider is acceptable only for **mapping/configuration smoke
  tests**: checks on the model's shape (an entity round-trips, a key or index is
  configured) whose result would be identical on any provider. Keep those in the
  unit-test project and don't let them grow into provider assertions.
