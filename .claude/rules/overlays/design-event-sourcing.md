# Overlay — Design (Event Sourcing)

Add when the stored state of an aggregate is the sequence of domain
events its root has recorded, instead of its current state. Compose with
`archetype/application.md`, `design-domain-model.md`, and
`design-cqrs.md`: an area that follows this overlay follows those two
as well. Under `architecture-areas.md` this overlay is area-scoped.

Importing this overlay is the decision to store domain events: the
event store, the projections, the projectors, and the `IProjector`
interface it requires are not justified again per change. Core's YAGNI
rule governs the rest: a root is replayed from its whole stream, and a
snapshot of its state is added on the maintainer's instruction alone.

Terms
- A **domain event**, a **root**, an **aggregate**, an **entity**, and
  a **value object** are those of `design-domain-model.md`. A
  **command** and a **query** are those of `design-cqrs.md`.
- A **stream** is the domain events one root has recorded, in the order
  it recorded them. A domain event's **version** is its place in its
  stream, counted from 1. A root's version is that of the last domain
  event applied to it, and 0 before any.
- The **event store** is the table that holds every stream of an area,
  one row for each domain event, in the database the area's commands
  write to.
- To **replay** a stream is to apply its domain events, in order, to a
  root that has had none applied.
- A **projection** is a table that queries read, whose rows are derived
  from domain events. A **projector** is the type that derives the rows
  of one projection.
- An area **follows** an overlay when the overlay is imported and, where
  `architecture-areas.md` is imported too, the area's row names it.

Aggregates
- Every aggregate of an area that follows this overlay is
  event-sourced: its stored state is its stream, held in the event
  store. No other table holds the state of an aggregate for code to
  load it from.
- A root's id is a `Guid`, or a value object whose one member is a
  `Guid`, so that it names the root's stream among those of every
  aggregate in the event store. This narrows the rule of
  `design-domain-model.md` that lets an id be of any base-library
  type.

Roots
- A root changes its state in one method only: `Apply`, a `private`
  method that takes an `IDomainEvent`. `Apply` is one `switch` over the
  domain event's type, with an arm for each type the root records and a
  default arm that throws `InvalidOperationException`, followed by one
  statement that adds 1 to the root's version. An arm assigns the
  root's state and constructs or changes the aggregate's value objects
  and other entities; it holds no check of its own.
- The root exposes its version as `int Version`, with a `private`
  setter.
- A constructor or method that changes the root's state enforces the
  root's invariants first. It then passes each domain event that states
  the change to `Apply` and adds it to `DomainEvents`, and assigns no
  state itself. The constructor that creates a root records the domain
  event that states its creation. For a root this is a stated exception
  to the rule of `design-domain-model.md` that an invariant is enforced
  in the constructor or method that sets the state it constrains: the
  member that records the domain event enforces it, and `Apply` sets
  the state.
- A root declares one `private` constructor, which takes the root's id
  and assigns it. That constructor assigns `null!` to each non-nullable
  reference property the compiler would otherwise report (`CS8618`),
  with the comment core requires saying that `Apply` sets it. The
  constructor that creates a root chains to it. It is exempt from the
  rule of `design-domain-model.md` that an entity's constructor takes
  what a valid new entity needs and enforces its invariants.
- A root declares `Replay`: a `public static` method that takes the
  root's id and the domain events of its stream in order. It creates
  the root through the `private` constructor, passes each domain event
  to `Apply`, and returns the root. It adds nothing to `DomainEvents`.
- Roots share no base class for `Apply`, `Version`, or `Replay`.
- Replay runs every constructor and method that `Apply` reaches on
  value objects and on the aggregate's other entities, so a stored
  domain event that breaks an invariant tightened after it was stored
  makes replay throw. Where the `Apply` arm for a domain event type
  already on the default branch constructs or changes a value object or
  an entity that is not a root — itself, or at any depth of the
  constructors and methods it calls — a change that adds an invariant
  to that type, or tightens one, first asks the maintainer how the
  stored domain events that break it are handled.
- The `switch` in `Apply` and the one in a projector are stated
  exceptions to core's rule against `switch` chains on type: each
  ranges over the domain event types its own class handles, and a
  stored domain event has only its type to be told apart by.

Domain events
- A root records a domain event for every change to its state, whether
  or not an integration event states the same fact. A domain event type
  is added in the change that adds the state change it states.
- Every member's type is built only from .NET base-library types and
  from records and enums declared in the domain event's own file. A
  record declared there is part of the domain event, not a value
  object. For the area this replaces the rule of
  `design-domain-model.md` that a domain event's members are
  base-library types and value objects: a value object's members can
  then change without changing what a stored payload is read into.
- The record declares its stored name as a `public const string` named
  `EventName`: `<Fact>` in lower case with a hyphen between words, e.g.
  `order-placed`. No two domain event types of an area have the same
  `EventName`. A stored domain event carries this name, never the CLR
  type name.
- A domain event type is a contract with every stream that holds one.
  Once it is on the default branch it is never deleted, its `EventName`
  never changes, no member of it is renamed or removed, and it only
  gains members, each of a nullable type: a payload stored before the
  member existed is read with that member null. A change that needs
  more is a new domain event type with a new `<Fact>`, and so a new
  `EventName`, and `Apply` keeps its arm for the old one. An
  integration event built from the new type keeps its own `<Fact>` — a
  stated exception to the rule of `design-domain-model.md` that a
  domain event has the `<Fact>` of the integration event built from it.

The event store
- An area has one event store. A row holds its position — a number the
  database generates, and the table's key — the root's id as a `Guid`,
  the domain event's version, its `EventName`, and its payload. The
  table has a unique constraint over the root's id and the version.
- The payload is the domain event serialized by `System.Text.Json` with
  `JsonSerializerDefaults.Web` as its own type, never as
  `IDomainEvent`: handed the interface, the serializer writes an empty
  object. A row is read by deserializing its payload as the type
  registered for its `EventName`. Every domain event type is registered
  with its `EventName` explicitly, never by scanning an assembly.
- A root is loaded by reading the rows of its stream in version order
  and passing their domain events to `Replay`. No other code builds a
  root from stored data. A stream with no rows has no root: the code
  that loads returns `null` for it, and no code calls `Replay` without
  a domain event.
- A root is saved by appending one row for each domain event in its
  `DomainEvents`, in order, with consecutive versions of which the last
  is the root's `Version`.
- The unique constraint is the area's concurrency check: of two
  commands that loaded a stream at one version, the second to save
  fails on it. The code that saves reads no version from the event
  store first, and no code catches that failure to save again.
- No code updates or deletes a row of the event store. An aggregate
  that ends records a domain event saying so, and its stream stays.
  This narrows `design-domain-model.md`, which lets an aggregate be
  deleted whole and exempts a data step of a schema migration: here
  such a step changes the event store only on the maintainer's
  instruction.

Projections
- A query reads projections and never the event store. Projections are
  therefore required here — a stated exception to the rule of
  `design-cqrs.md` that a table kept only for queries to read is added
  on the maintainer's instruction alone. A projection is added in the
  change that adds the first query that reads it.
- A projection is named by a plural noun for what its rows describe,
  e.g. `OrderSummaries`. Exactly one projector writes it: a
  `sealed class` named `<Projection>Projector` that implements
  `IProjector`. No other code writes it, except the code that rebuilds
  it, which empties it first.
- `IProjector` has one method, `ProjectAsync`, which returns a `Task`.
  Its parameters are the root's id as a `Guid`, the domain event as an
  `IDomainEvent`, and a `CancellationToken`, after any parameter a
  persistence rule under Placement adds. `ProjectAsync` is one `switch`
  over the domain event's type, with an arm for each type that changes
  the projection and no default arm.
- A projector derives its rows from the domain events alone: it reads
  no root, no clock, and no table but its own projection.
- The code that saves a root passes each domain event it appends, in
  order, to every projector before it commits. The event store rows
  and the projection rows commit in one transaction. Every projector is
  registered explicitly, never by scanning an assembly.
- A projection is rebuilt by code that empties it and then passes its
  projector the domain event of every row of the event store, in
  position order. A change that gives a projector an arm for a domain
  event type already on the default branch, or changes what an existing
  arm derives, first asks the maintainer whether the projection is
  rebuilt and how that run is started.

Placement
- In an area that follows `architecture-clean.md`: a command loads and
  saves a root through a write interface of `<Area>.Application`, as
  `design-cqrs.md` names it. The class that implements it, the event
  store row type, `IProjector`, the projectors, and the projection row
  types live in `<Area>.Infrastructure`, whose registration method
  registers the domain event types and the projectors.
- In an area that follows `architecture-vertical-slice.md`: the code
  that loads a root and the code that saves one live in `Shared/`, in
  types that implement no interface, and every command's handler calls
  them — a stated exception to that overlay's rule that a handler does
  its own data access with nothing between it and the database. The
  event store row type, `IProjector`, the projectors, and the
  projection row types live in `Shared/` too, and `Add<Name>` registers
  the domain event types and the projectors. The code that loads and
  saves and the projectors are tested under `.IntegrationTests` — a
  stated exception to that overlay's unit-testing of the types in
  `Shared/`.
- With `persistence-efcore.md`: no entity or value object of the area
  is an EF-mapped entity type or part of one, so the mapping rules
  `design-domain-model.md` states for that overlay bind nothing here.
  The event store row and the row of each projection are EF-mapped
  entity types of one `DbContext`, and `ProjectAsync` takes that
  `DbContext` as its first parameter. The code that saves a root adds
  the event store rows to one `DbContext` instance and passes that
  instance to the projectors, which add and change projection rows
  through it. One `SaveChangesAsync` call then saves them all, which
  EF Core applies in one transaction on a provider that supports them.
  A projector calls no `SaveChangesAsync`. It gets a row it changes
  with `FindAsync`, which returns a row that an earlier domain event of
  the same save added, as a query does not. It never calls
  `ExecuteUpdateAsync` or `ExecuteDeleteAsync`, which run at once,
  outside that `SaveChangesAsync`.
- Where `persistence-dapper.md` is imported and `persistence-efcore.md`
  is not: the rule `design-domain-model.md` has an agent ask the
  maintainer for there, on how a root is rebuilt from the rows read,
  is `Replay`, and is not asked for. The SQL that reads a stream lives
  in the type that loads a root, and reads into the event store row
  type kept beside it. These are stated exceptions to that overlay's
  rules that the record a read materializes into belongs to the
  Application layer and, in an area that follows
  `architecture-vertical-slice.md`, that the slice's handler holds and
  runs the slice's SQL and reads into a record of the slice. This
  overlay has no rule for how the event store rows and the projection
  rows are written in one transaction. Ask the maintainer for one
  before the first aggregate is persisted.
- In an area that also follows `design-event-driven.md`: the outbox
  rows commit in the transaction that appends the domain events. The
  publisher builds no integration event from a domain event whose fact
  no integration event states. A consumer's inbox row commits in the
  transaction that saves the root it changed.

Testing
- Each root has a test that passes the domain events a root recorded to
  `Replay` and asserts that the replayed root's `Version` and state
  equal the first root's and that its `DomainEvents` is empty.
- Each domain event type has a unit test, in the project that
  unit-tests the root that records it, that deserializes a payload kept
  in the test as a string literal and asserts each member. The test
  calls `JsonSerializer.Deserialize` itself, for the domain event's
  type and with `JsonSerializerDefaults.Web`, and calls no code that
  reads the event store. A literal on the default branch is never
  edited: when the type gains a member, a new test reads a literal that
  has it.
- The code that loads and saves a root is tested under
  `.IntegrationTests` against the real engine. A root saved and loaded
  again has the `Version` and the state it was saved with. Of two saves
  of a root loaded twice at one version, the second fails and leaves
  neither an event store row nor a projection change.
- A projector is tested under `.IntegrationTests`: the test saves roots
  through the code that saves them and asserts the projection's rows.
