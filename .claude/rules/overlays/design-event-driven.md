# Overlay — Design (Event-Driven)

Add when parts of the application react to each other's state changes
through events instead of calling each other. Compose with
`archetype/application.md`. Under `architecture-areas.md` this overlay is
area-scoped.

Importing this overlay is the decision to publish every event through an
outbox: the tables, the dispatcher, and the two interfaces it requires
are not justified again per change. Core's YAGNI rule governs
the rest: an event type is added in the change that adds its first
consumer, or on the maintainer's instruction when its consumers are
outside the repo.

Terms
- In this overlay **event** means an integration event: a record stating
  a state change its publisher has committed. The UI events of
  `frontend-blazor.md` and C# `event` members are other things and keep
  their qualifiers.
- The **publisher** of an event is the code that commits the state
  change it states. A **consumer** is a type that reacts to one event
  type.
- The **outbox** is a table, in the database the publisher's transaction
  writes to, holding the events published there. The **dispatcher** is
  the background service that delivers an outbox's events to their
  consumers. The **inbox** is the table in which consumers record the
  events they have handled. It is in the consumers' own database — the
  one their transactions write to — which in an application that
  receives an event is not the publisher's.
- An area **follows** an overlay when the overlay is imported and, where
  `architecture-areas.md` is imported too, the area's row names it.

Events
- An event type is a `sealed record` named `<Fact>IntegrationEvent`,
  `<Fact>` naming what happened in the past tense, e.g.
  `OrderPlacedIntegrationEvent`.
- Every event type implements `IIntegrationEvent`, an interface whose
  only members are the properties `Guid EventId` and
  `DateTimeOffset OccurredAt`, so that code handling any event reads
  both. Event types share no base record and no other interface.
- An event type's first two positional parameters are `Guid EventId` and
  `DateTimeOffset OccurredAt`, which implement the interface. The
  publisher sets `EventId` to a new `Guid` and `OccurredAt` to the time
  it read from `TimeProvider`.
- Every other member's type is built only from .NET base-library types
  and from records and enums declared in the event's own file — never an
  entity or any other type declared outside that file.
- The record declares its wire name as `public const string EventName`:
  `<Fact>` in lower case with a hyphen between words, e.g.
  `order-placed`. A stored or transmitted event carries this name, never
  the CLR type name.
- An event type is a contract. Once it is on the default branch its
  `EventName` never changes and it only gains members, each of a
  nullable type; a change that needs more is a new event type with a new
  `EventName`.

Publishing
- A publisher publishes an event in one way: it adds the event to the
  outbox in the transaction that commits the state change. For an event
  the application publishes, no code but the dispatcher calls a consumer
  or hands the event to a message broker.
- An outbox row holds the event's `EventId`, `EventName`, and
  `OccurredAt`, its payload, and the time it was delivered, null until
  then. The payload is the event serialized by `System.Text.Json` with
  `JsonSerializerDefaults.Web` as its own event type, never as
  `IIntegrationEvent`: handed the interface, the serializer writes the
  interface's two members alone.

Delivering
- One dispatcher serves each outbox: a `BackgroundService` that on each
  pass reads the undelivered rows oldest first and, for each row, calls
  every consumer of its event type. It sets the row's delivery time when
  every one of them has returned. The interval between passes comes from
  configuration.
- Delivery is at-least-once. Whatever fails in delivering a row — a
  consumer that throws, a payload that does not deserialize, an
  `EventName` no event type is registered for, or anything else — the
  dispatcher logs the failure and leaves the row undelivered. It then
  goes on: to the row's remaining consumers when the failure is in one
  consumer's call — creating its scope, resolving the consumer, or its
  `HandleAsync` — and otherwise to the next row. A later pass calls
  every consumer of the row again. Cancellation by the host's stopping
  token is not a failure: it ends the pass.
- The dispatcher resolves each consumer from a DI scope it creates for
  that one call. Consumers are registered scoped, no scope is created
  for a hosted service by default, and a scope shared by a row's
  consumers would let one of them save the unsaved changes of another
  that threw.
- Every event type and every consumer is registered explicitly, never by
  scanning an assembly.
- An application that publishes to a message broker sends every event to
  it from the dispatcher, which treats the send as one more consumer of
  the row. The message carries the event's `EventName` and its payload.
- Code that receives an event from a message broker delivers it in the
  dispatcher's place and under the dispatcher's rules on failure and on
  the DI scope, the received message standing for the row. It calls
  every consumer of the event's type and acknowledges the message only
  when every one of them has returned. The receiving application
  declares its own event type for it, with the publisher's `EventName`
  and only the members its consumers read.

Consuming
- A consumer is a `sealed class` that implements
  `IIntegrationEventConsumer<TEvent>` for exactly one event type. That
  interface constrains `TEvent` to `IIntegrationEvent` and has one
  method, `HandleAsync`, which takes the event and a `CancellationToken`
  and returns a `Task`.
- A consumer is idempotent by `EventId`. Before it acts it looks for its
  inbox row — the `Type.FullName` of its own type and the `EventId` —
  and returns when the row is there; when it has acted it inserts the
  row. A consumer that writes to the database inserts the row in the
  transaction that commits its write.
- A consumer relies neither on the order in which events arrive nor on
  another consumer of the same event having run.

Placement
- In an area that follows `architecture-clean.md`: event types, the two
  interfaces, and consumers — which are use cases — live in
  `<Area>.Application`. The outbox and inbox row types, the dispatcher,
  and code that reaches a message broker live in
  `<Area>.Infrastructure`, whose registration method registers the
  dispatcher. A use case passes the event it publishes, and a consumer
  the `EventId` it handles, as an argument to the method of its
  Application interface that commits the state change; the
  implementation writes the outbox or inbox row in that method's
  transaction.
- In an area that follows `architecture-vertical-slice.md`: a consumer
  is the handler of a slice of its own, `<UseCase>` naming its reaction.
  The event is that slice's request, so the slice declares no
  `<UseCase>Request`, and the handler implements the consumer
  interface — a stated exception to that overlay's rule on the
  interfaces handlers share. That overlay's folder rule places an event
  type: in its publisher's slice folder while no other slice uses it, in
  `Shared/` once a consumer's slice does. In
  either place it keeps the name `<Fact>IntegrationEvent` — a stated
  exception to that overlay's naming of the types in a slice. The
  two interfaces, the dispatcher, and the outbox and inbox row
  types — which model nothing of the business, so they are not that
  overlay's entities — live in `Shared/`, and `Add<Name>` registers the
  dispatcher. The dispatcher is tested under `.IntegrationTests` all the
  same — a stated exception to that overlay's unit-testing of the types
  in `Shared/`.
- With `persistence-efcore.md`: the outbox row is an EF-mapped entity
  type of the `DbContext` that maps the publisher's state, and the inbox
  row of the one that maps the consumer's. The publisher adds the outbox
  row to the `DbContext` instance tracking the state change, and one
  `SaveChangesAsync` call saves both, which EF Core applies in one
  transaction on a provider that supports them. A consumer saves its
  inbox row with its write the same way.
- With `persistence-dapper.md`: the insert into the outbox or inbox is
  one call of the unit of work that writes the state change, under its
  `DbTransaction`. Where `persistence-efcore.md` is imported too, the
  dispatcher reads and updates the outbox through the `DbContext`.
  Otherwise its SQL lives in a repository type of its own, which
  implements no interface and reads into the outbox row type kept beside
  it, since only the dispatcher calls it. These are stated exceptions to
  that overlay's rules that a repository type implements an
  Application-layer interface and that the record a read materializes
  into belongs to the Application layer.

Testing
- A publisher's tests assert the event it publishes, by type and by
  member. The test that the state change and the outbox row commit
  together and roll back together runs under `.IntegrationTests`.
- Each consumer has a test that handles one event twice and asserts the
  state is that of handling it once.
- The dispatcher is tested under `.IntegrationTests`: a pass delivers an
  undelivered row and sets its delivery time, and a consumer that throws
  leaves its row undelivered without keeping the row's other consumers
  from being called.
