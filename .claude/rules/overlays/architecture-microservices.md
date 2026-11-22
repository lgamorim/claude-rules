# Overlay — Architecture (Microservices)

Add when the application is one deployable among several that work
together, each built and released from a repository of its own. Compose
with `archetype/application.md`. Under `architecture-areas.md` this
overlay is not area-scoped: it binds every file of the repo, and no row
of the table names it.

Importing this overlay is the decision to keep the application apart
from every other deployable: the clients, the wire records that repeat
what a remote system declares, and the events that carry a state change
out of the application are not justified again per change. Core's YAGNI
rule governs the rest: a client is added in the change that adds its
first call.

Terms
- **The application** is the deployable this repo builds: the
  deliverable of `archetype/application.md`. **Another deployable** is
  an application built and released from another repository. This
  overlay calls neither a "service": elsewhere in the rule set that
  word means several things, most often a type registered for
  dependency injection.
- A **use case** is one operation the application carries out for a
  caller. `architecture-clean.md`, `architecture-vertical-slice.md`,
  and `design-cqrs.md` use the term the same way.
- A **remote system** is another deployable, or any other system
  outside the repo, that has an operation a use case calls. Three
  things the application reaches over the network are not remote
  systems: a data store of its own, a message broker, and a host of its
  own when a component that runs in the browser calls it.
- A data store — a database, cache, file share, or object store — is
  the application's **own** when no other deployable reads or writes
  what it holds.
- A **client** is the type through which the code of one project calls
  one remote system. The HTTP-client implementation of
  `frontend-blazor.md` is another thing and keeps its qualifier.
- A **wire record** is a record a client declares for what it sends to
  its remote system or reads from it.
- A **served contract** is a minimal-API route of the application, or
  an action of a controller none of whose actions returns a view,
  together with the types of the bodies it reads and writes.
- A **host** is an executable project the deployment runs as the
  application. The migrator of `persistence-dapper.md` is an executable
  but not a host.
- An **event**, its **publisher**, a **consumer**, the **outbox**, and
  the **dispatcher** are those of `design-event-driven.md`.

Structure
- No project of the repo references a project outside the repo, and
  the repo packs no project for another deployable to reference: the
  archetype's "No `dotnet pack`" stands.
- What the application and a remote system exchange is declared on each
  side. Here it is declared in wire records, in the types of served
  contracts, and in the event types `design-event-driven.md` has an
  application declare for the events it publishes and receives. The
  one exception is a library the maintainer has a client wrap, under
  the last rule of Reaching a remote system.

Data
- The application reads and writes no data store but its own. What it
  needs of the data a remote system holds, it reads through a client or
  receives in an event.
- A table that copies a remote system's data, kept current by a
  consumer, is added on the maintainer's instruction alone.
- No table, view, or file is created for another deployable to read:
  what another deployable needs of the application's data, it gets
  from a served contract or from an event.
- No transaction spans the application's database and anything else —
  a second database, a message broker, or a remote system. What ties a
  state change in the application to one outside it is an event
  delivered at least once: one the application adds to its outbox, or
  one a consumer received.

Reaching a remote system
- A project calls a remote system in one type only: its client for
  that system, an `internal sealed` class named `<Remote>Client`,
  `<Remote>` being a noun that names the remote system.
- No method of a client accepts or returns a wire record, or a type of
  a library that reaches the remote system: the client translates
  between those types and types of the application.
- Every method of a client that calls the remote system takes a
  `CancellationToken` and passes it to each call it makes.
- A timeout bounds each call a client makes to the remote system. The
  remote system's address and the timeout's length come from
  configuration, and no client relies on a default timeout of the
  transport it uses.
- A client reads and writes the remote system's wire format itself,
  through its wire records: `internal sealed record` types declared in
  the client's project and used by that client alone. A wire record
  holds only the members the client sends or reads, and each member's
  type is built only from .NET base-library types and from that
  client's other wire records and enums.
- A client never fails on a member that a payload holds and its wire
  record lacks, since a remote system can add members at any time.
  `System.Text.Json` skips such a member by default; no client sets
  `JsonUnmappedMemberHandling.Disallow`, on the serializer's options
  or on a wire record.
- A library published for calling the remote system is used only on
  the maintainer's instruction. The client then wraps it: the client is
  the one type of its project that uses the library, it declares no
  wire records, and the rules above on what its methods accept and
  return, on the `CancellationToken`, and on the timeout bind it
  unchanged.

Changing a remote system's state
- Each operation of a remote system either changes state there or only
  reads. The task or the remote system's documentation says which; a
  change for which neither does first asks the maintainer.
- Code other than a consumer calls a client only for an operation that
  only reads.
- The application changes a remote system's state through an event and
  in no other way. How depends on what the remote system offers, as
  the next two rules state. A change whose task does not say which of
  the two the remote system offers first asks the maintainer.
- Where the remote system consumes the application's events from a
  message broker: the use case that causes the change adds an event to
  the outbox, as `design-event-driven.md` requires of a publisher. The
  application's part ends when the dispatcher has sent the event, and
  no code of the application calls the remote system to make that
  change.
- Where the remote system offers an operation instead: a consumer
  calls that operation through the client. A consumer that causes the
  change makes the call itself and adds no event for it, whether the
  application published the event it handles or received it from a
  message broker. Any other use case that causes the change adds an
  event to the outbox, as a publisher does, and a consumer of that
  event makes the call.
- A use case adds that event even when it writes nothing else to the
  database: the event states what the use case accepted, and the
  outbox row is the state change it commits.
- A repo whose application publishes or consumes an event imports
  `design-event-driven.md`, and where `architecture-areas.md` is
  imported too, the row of the area that holds the publisher or the
  consumer names it. A change that needs the import, or that entry in
  the row, where it is missing first asks the maintainer for it and
  adds neither without that answer.
- A client method for an operation that changes state takes an
  idempotency key, a `Guid`. Only a consumer calls it, passing the
  `EventId` of the event it handles, and the client sends the key in
  the form the operation documents. Where the operation documents no
  idempotency key, the change asks the maintainer before the consumer
  is written, since the dispatcher can deliver one event more than
  once.
- Among the consumers of one event, at most one calls a given remote
  system to change its state, and it makes one such call: a second
  would carry the same idempotency key. A second change to that remote
  system is a second event. The use case that causes the changes, a
  consumer included, adds it to the outbox in the transaction it
  commits, and a consumer of that event makes the second call.
- An application with no database of its own has no outbox, and this
  overlay has no rule for how it changes a remote system's state. Ask
  the maintainer for one before the first such change.

Served contracts
- The body types of a served contract hold no entity — neither an
  EF-mapped entity type nor an entity of `design-domain-model.md`.
- A served contract is a contract with callers the repo cannot see.
  Once it is on the default branch its HTTP method and its route
  template never change, no member of a body type is renamed, removed,
  or given another type, and a body type only gains members. A member
  the request body's type gains is of a nullable type: a caller written
  before it sends none. This binds every served contract, whoever its
  callers are.
- A change that needs more adds a new served contract beside the old
  one, at a route the maintainer gives. The old one stays as it is
  until the maintainer says to remove it.

Placement
- In an area that follows `architecture-clean.md`: a call to a remote
  system is an I/O need of the use case that makes it. The need is an
  interface declared in `<Area>.Application`, as that overlay requires,
  and the client, in `<Area>.Infrastructure` with its wire records,
  implements every such interface its remote system serves.
  `Add<Name>Infrastructure` registers it.
- In an area that follows `architecture-vertical-slice.md`: the client
  and its wire records live in `Shared/`, the client implements no
  interface, and a handler that needs the remote system calls it. For
  a client that a single slice uses, this is a stated exception to
  that overlay's folder rule, which sends such a type to the slice's
  folder. `Add<Name>` registers the client.
- With `frontend-blazor.md`: the routes that overlay's HTTP-client
  implementation calls are served contracts like any other.

Testing
- No test reaches a remote system. A test that runs a client gives it
  a stand-in for the remote system that the test supplies in process,
  over no network.
- A client that declares wire records is tested in the unit-test
  project of the project that holds it. Each of its methods that reads
  a payload has a test in which the stand-in returns one kept in the
  test as a string literal, asserting what the method returns. Each
  that sends a body has a test asserting that body against a string
  literal, and each that takes an idempotency key has a test asserting
  the key the stand-in received.
- In an area that follows `architecture-vertical-slice.md`, a handler
  that calls a client is tested with the real client over such a
  stand-in, and no interface is added to the client to give the handler
  a test double.
- A consumer that calls a client has a test asserting that the call
  carries the `EventId` of the event handled as its idempotency key.
- Each served contract has a test through a host, in that host's
  `.IntegrationTests` project. It sends the request with any body kept
  in the test as a string literal, and it asserts each member of the
  response body by name, reading the body in its wire format and not
  through the contract's own types. A request literal on the default
  branch is never edited: when the request body's type gains a member,
  a new test sends it.
