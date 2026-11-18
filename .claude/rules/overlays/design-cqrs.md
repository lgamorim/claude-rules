# Overlay — Design (CQRS)

Add when the application separates the use cases that change state from
the ones that read it — Command Query Responsibility Segregation.
Compose with `archetype/application.md`. Under `architecture-areas.md`
this overlay is area-scoped.

Importing this overlay is the decision to make that separation: the
handler types and the command, query, and response records it requires
are not justified again per change. Core's YAGNI rule governs the rest.
The separation is in code, over one database: a table kept only for
queries to read is added on the maintainer's instruction alone.

Terms
- A **use case** is one operation the application carries out for a
  caller. `architecture-clean.md` and `architecture-vertical-slice.md`
  use the term the same way.
- A **command** is a use case that changes state — in the database,
  through an event, or in another system. A **query** is a use case that
  reads state and changes none.
- In this overlay **handler** means the type that carries out one
  command or one query. In an area that follows
  `architecture-vertical-slice.md` it is that overlay's slice handler.
  The page handlers of `frontend-mvc.md` and the type handlers of
  `persistence-dapper.md` are other things and keep their qualifiers.
- An area **follows** an overlay when the overlay is imported and, where
  `architecture-areas.md` is imported too, the area's row names it.

Commands and queries
- Every use case is a command or a query, never both. A use case that
  would change state and return data it read is written as two.
- A command returns no data, except the id of what it created, returned
  as that id's own type. An endpoint, page handler, or controller action
  that runs a command returns no more than the command did.
- A query writes nothing to the database and publishes no event. It
  returns one `sealed record` named `<UseCase>Response`, `<UseCase>`
  being a verb phrase naming the operation, e.g. `GetOrder`.
- A command's input is a `sealed record` named `<UseCase>Command`, and a
  query's a `sealed record` named `<UseCase>Query`. A use case with no
  input has neither.
- A command, query, or response record belongs to one use case: no other
  use case uses it. A response holds no entity — neither an EF-mapped
  entity type nor an entity of `design-domain-model.md`.

Handlers
- Each use case has one handler: a `sealed class` named
  `<UseCase>Handler` with one public method, `HandleAsync`, which takes
  the command or query, when there is one, and a `CancellationToken`,
  and returns a `Task`, carrying the id or the response when there is
  one. It is the shape `architecture-vertical-slice.md` gives a slice's
  handler. In an area that follows `architecture-clean.md`, that overlay
  decides which use cases have a type of their own, as stated below.
- Handlers share no base class, and share an interface only when a
  decorator applies to every handler of the area, with the benefit
  stated as core requires of a pattern.
- Code calls a handler directly: through that shared interface where
  the area's handlers have one, and otherwise as its concrete type.
  Nothing dispatches a command or query to its handler by type: no
  mediator and no bus.
- No handler calls another handler, and a command runs no query: it
  reads what it needs itself.

Placement
- In an area that follows `architecture-clean.md`: a handler is a
  use-case type in `<Area>.Application`. An interface declared there for
  I/O is a write interface, whose methods commands call, or a read
  interface, whose methods queries call — never both. A command or
  query that is one call to such an interface has no handler and no
  `<UseCase>Command` or `<UseCase>Query` record, by that overlay's rule
  on a use case that only forwards: host code calls the method, which
  takes the input's values as its parameters, and a query's method
  returns its `<UseCase>Response`.
- In an area that follows `architecture-vertical-slice.md`: a slice is
  one command or one query, and its request is named `<UseCase>Command`
  or `<UseCase>Query` instead of `<UseCase>Request` — a stated exception
  to that overlay's fixed names. A command that returns an id returns it
  bare, with no `<UseCase>Response` type.
- In an area that also follows `design-domain-model.md`: a command
  changes stored state only through roots, as that overlay requires. A
  query loads no entity and reads into records, which that overlay
  exempts from its rule on loading an aggregate whole.
- In an area that also follows `design-event-driven.md`: only a command
  publishes an event. A consumer is the handler of a command whose input
  is the event it handles, so that command has no `<UseCase>Command`.
  The consumer implements that overlay's consumer interface, and its
  dispatcher calls it through that interface — stated exceptions to
  this overlay's rules on the interfaces handlers share and on how code
  calls a handler.
- With `frontend-blazor.md`: a component that has run a command and
  shows state the command changed runs the query for that state right
  after the command — a stated exception to the one-call rule
  `architecture-clean.md` and `architecture-vertical-slice.md` set for
  host code.
- Where `persistence-efcore.md` is imported and `persistence-dapper.md`
  is not: a query reads through the `DbContext` and projects into its
  response inside the query, with `Select`. It never materializes an
  EF-mapped entity type.
- Where both are imported: a command reads and writes through EF Core
  alone, and a query reads through Dapper alone. Dapper runs no
  statement that writes. Of the two persistence rules of
  `design-event-driven.md`, the EF Core one then says how a command's
  outbox row is written.

Testing
- The code that reads a query's data from the database is tested under
  `.IntegrationTests` against the real engine, and the failing test that
  motivates it is written there.
- A command's test never runs a query to assert what the command did.
