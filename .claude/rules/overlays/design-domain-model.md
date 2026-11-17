# Overlay — Design (Domain Model)

Add when the application's business rules live in a domain model —
entities, value objects, and aggregates that enforce their own rules, the
tactical patterns of Domain-Driven Design. Compose with
`archetype/application.md`. Under `architecture-areas.md` this overlay is
area-scoped.

Importing this overlay is the decision to model the domain: the value
objects, the exception types, and the `IDomainEvent` interface it
requires are not justified again per change. Core's YAGNI rule governs
the rest.

Terms
- A **domain type** is an entity, a value object, a domain service, a
  domain exception, or a domain event.
- An **entity** is a domain type with an identity: it is the same entity
  while its other state changes. The EF-mapped entity type of
  `persistence-efcore.md` is a wider thing — any class a `DbContext`
  maps, the outbox row of `design-event-driven.md` included — and keeps
  its qualifier.
- A **value object** is a domain type with no identity: two are equal
  when their members are. It is what `architecture-clean.md` and
  `architecture-vertical-slice.md` call a value an entity holds.
- An **aggregate** is an entity, its **root**, together with the other
  entities the rules under Aggregates place in it.
- An **invariant** is a rule over a domain type's state that holds
  whenever code outside the type can read that state. Core's "encapsulate
  invariants inside domain types" uses the word the same way.
- A **domain exception** is what a domain type throws when it is asked to
  break an invariant.
- An area **follows** an overlay when the overlay is imported and, where
  `architecture-areas.md` is imported too, the area's row names it.

Domain types
- An invariant is enforced by the domain type whose state it constrains,
  in the constructor or method that sets that state — never by the code
  that calls it.
- A rule that reads the state of more than one aggregate belongs to none
  of them. A **domain service** enforces it: a `static class` named for
  the operation, whose methods take those aggregates as arguments.
- A domain type performs no I/O and reads no clock: the current time
  reaches it as a `DateTimeOffset` argument. `architecture-clean.md`
  requires the same of its Domain layer.

Value objects
- A value object is a `sealed record` class — never a `record struct` or
  any other struct, whose default value exists without a constructor
  having run and so can break an invariant.
- It declares its members as get-only properties, assigned in the one
  constructor it declares, which enforces its invariants. It has no
  positional parameters and no `init` accessor: a `with` expression sets
  an `init` property without running the constructor.
- A value gets a value object when a rule constrains it alone — its
  range, its format — or when it is made of more than one member,
  such as an amount with its currency. Any other value keeps its
  base-library type.
- An entity's id is a single value and takes the same test: a
  base-library type when no rule constrains it, a one-member value
  object when one does.

Entities
- An entity is a `class`, never a record: a record equals another when
  their members are equal, and an entity is the same entity whatever its
  other members hold. Core's records preference covers immutable data,
  which an entity is not.
- An entity declares no equality members. Code that asks whether two
  references are the same entity compares their ids.
- An entity's constructor takes what a valid new entity needs and
  enforces its invariants. A property has a `private` setter or none, a
  collection is a private `List<T>` field exposed as
  `IReadOnlyCollection<T>`, and state changes only through the entity's
  methods.

Aggregates
- An entity belongs to another entity's aggregate when only that root's
  methods create and remove it, and no code loads it except as part of
  loading that root. Passing its id to a method of the root, or carrying
  that id in a read record, does not make it a root. Every other entity
  is the root of its own aggregate.
- A change that introduces an entity whose owner its task does not
  settle asks the maintainer which aggregate it belongs to before
  writing it, as core's workflow rule on two designs requires.
- Code outside an aggregate changes it only through its root. The root's
  methods create, change, and remove the aggregate's other entities,
  whose constructors and state-changing methods are `internal`.
- An aggregate refers to another aggregate by the id of its root, never
  by a reference to it.
- An aggregate is loaded, saved, and deleted whole, through its root: no
  code loads, saves, or deletes one of its other entities apart from it.
  A read that materializes records of its own, and no entity, is not
  bound by this.
- An aggregate's stored state changes only when code loads the
  aggregate, calls its root, and saves it, or deletes it whole. No bulk
  or in-place update writes its rows. A data step of a schema migration
  is exempt.

Domain exceptions
- An operation that would break an invariant throws a domain exception.
  It never reports the refusal through its return value.
- Each invariant has its own exception type: a `sealed class` named
  `<Rule>Exception`, `<Rule>` naming the invariant that was broken, e.g.
  `InsufficientStockException`. It derives directly from `Exception`, and
  domain exception types share no base class.
- Only code that produces a response — an endpoint, a page handler, a
  controller action, a component — translates a domain exception, in a
  `catch` clause naming that exception type around the call that can
  throw it. It never translates one in middleware, a filter, or a
  handler shared by several calls, and never by catching `Exception`.
  Code between it and the domain type never turns a domain exception
  into a return value — a result, a flag, or `null`.

Domain events
- In an area that also follows `design-event-driven.md`, a root records
  a **domain event** for each fact it causes that an integration event
  states. The domain event type is added in the change that adds that
  integration event. An area that does not follow that overlay has no
  domain event type.
- A domain event type is a `sealed record` named `<Fact>DomainEvent`,
  `<Fact>` being that of the integration event, e.g.
  `OrderPlacedDomainEvent`. It implements `IDomainEvent`, an interface
  with no members, and its members are base-library types and value
  objects — never an entity.
- The root adds each domain event to a private `List<IDomainEvent>`
  field, exposed as `IReadOnlyCollection<IDomainEvent> DomainEvents`.
  Roots share no base class for it.
- The publisher of `design-event-driven.md` reads the root's
  `DomainEvents` before it commits and builds from each the integration
  event it adds to the outbox. A domain event has no consumer, and
  nothing else reads it.
- This kind is always written "domain event"; an unqualified "event"
  stays the integration event of that overlay.

Placement
- In an area that follows `architecture-clean.md`, domain types and
  `IDomainEvent` live in `<Area>.Domain`. The use case reads the root's
  `DomainEvents` and builds the integration events, which it passes to
  the method that commits, as `design-event-driven.md` requires; the
  Infrastructure layer never reads a domain event.
- In an area that follows `architecture-vertical-slice.md`, they live in
  `Domain/` — domain services, domain exceptions, and domain events
  included, a stated exception to that overlay's folder rule, which
  sends a type that is neither an entity nor a value an entity holds to
  a slice's folder or to `Shared/`.
- With `persistence-efcore.md`, an entity keeps the shape this overlay
  gives it, which narrows that overlay's ORM exception permitting
  settable properties. Each mapped property declares a `private`
  setter: EF Core does not map a get-only property by convention.
- With `persistence-efcore.md`, EF Core can create an entity through a
  constructor whose every parameter matches a mapped property by name,
  as `customerName` matches `CustomerName`. A value object mapped by a
  value converter is such a property; one mapped as a complex type is
  not. An entity with such a constructor declares no other for EF Core,
  unless that constructor records a domain event: EF Core would run it
  for each entity it loads, and every loaded root would hold that event
  again. Such a root, and an entity with no constructor EF Core can
  bind, adds a `private` parameterless constructor, which EF Core then
  uses; it assigns `null!`
  to each non-nullable reference property the compiler would otherwise
  report (`CS8618`), with the comment core requires saying that EF Core
  sets it.
- With `persistence-efcore.md`, a value object held in one property is
  mapped by a value converter (`HasConversion`) when it has one member,
  and as a complex type (`ComplexProperty`) when it has several, with an
  explicit `Property` call for each member: without those calls EF Core
  finds no constructor it can bind. An id that is a value object is
  mapped by its value converter like any other, and is the key.
- Where `persistence-dapper.md` is imported and `persistence-efcore.md`
  is not, this overlay has no rule for how a repository type rebuilds a
  root from the rows it reads. Ask the maintainer for one before the
  first aggregate is persisted.

Testing
- Each invariant has unit tests on the domain type that enforces it,
  with no test double: one for state the invariant allows, and one
  asserting the domain exception by type for state it refuses.
- A test builds a domain type through the constructors and methods
  production code calls — never through reflection, and never through a
  constructor declared for EF Core.
- A root's test asserts each domain event it records, by type and by
  member.
- Each `catch` clause that translates a domain exception has a test
  asserting the response.
