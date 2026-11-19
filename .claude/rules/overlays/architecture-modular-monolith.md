# Overlay — Architecture (Modular Monolith)

Add when the application is one deployable made of business modules:
parts that each own their tables and reach each other only through a
contracts project and through events. Compose with
`archetype/application.md` and with `architecture-clean.md` or
`architecture-vertical-slice.md`: an area that follows this overlay
follows one of those two, which says what its projects are. Under
`architecture-areas.md` this overlay is area-scoped.

Importing this overlay is the decision to keep the business modules
apart: the contracts projects, the adapters, and the types two business
modules each declare for one concept are not justified again per
change. A contract interface has one implementation — a stated
exception to core's single-implementation rule, which exempts testing
and layer isolation alone. Core's YAGNI rule governs the rest: a
contracts project is added in the change that puts the first type in
it.

Terms
- A **business module** is an area that follows this overlay, together
  with its contracts project. It is always written with "business": an
  unqualified "module" stays a file of the rule set, as
  `architecture-areas.md` uses the word.
- An area **follows** an overlay when the overlay is imported and, where
  `architecture-areas.md` is imported too, the area's row names it.
- A business module's **contracts project** is `<Area>.Contracts`,
  `<Area>` being the area's name under the architecture overlay it
  follows. It is none of the projects that overlay gives the area, and
  that overlay's rules do not bind it, even where its files match the
  area's row.
- A **contract interface** is an interface a contracts project declares
  for other business modules to call. The two interfaces of
  `design-event-driven.md` are not contract interfaces, wherever they
  live.
- An **adapter** is the type through which a business module calls the
  contract interfaces of one other business module.
- A **host** is an executable project the deployment runs as the
  application. The migrator of `persistence-dapper.md` is an executable
  but not a host.
- An **event**, its **publisher**, a **consumer**, the **outbox**, the
  **dispatcher**, and the **inbox** are those of
  `design-event-driven.md`.

Structure (adds to the architecture overlay the business module follows)
- The contracts project is `src/<Area>.Contracts/`, a class library. It
  references no project.
- A project of one business module, a test project included, references
  a project of another business module only when that project is the
  other's contracts project.
- Among a business module's projects under `src/`, one holds its
  references to contracts projects: its own, and that of each other
  business module it calls or whose events it consumes. In a business
  module that follows `architecture-clean.md` that project is
  `<Area>.Application`: `<Area>.Infrastructure` reaches the contracts
  projects through it, since project references flow transitively, and
  `<Area>.Domain` references none. In one that follows
  `architecture-vertical-slice.md` it is `<Area>`. These are stated
  exceptions to the rule of `architecture-clean.md` that gives a layer
  project's project references exactly, and to the rule of
  `architecture-vertical-slice.md` that `<Area>` references no other
  project under `src/`.
- No project of a business module grants `InternalsVisibleTo` to an
  assembly of another business module.
- Where `architecture-areas.md` is imported, the `Paths` of a business
  module's row match its contracts project.
- A change that adds the first reference from one business module to
  another's contracts project first asks the maintainer whether the
  first may depend on the second.

Contracts
- A contracts project holds only `public` types, of three kinds:
  contract interfaces; the `sealed record` and `enum` types their
  methods accept and return; and what the first rule under Placement
  puts there — event types, with the records and enums their files
  declare, and the two interfaces.
- The type of every parameter, return value, and member in a contracts
  project is built only from .NET base-library types and from records
  and enums declared in that project — never a domain type or any other
  type of the business module.
- A type is added to a contracts project in the change that adds its
  first use by another business module.
- A contract interface is named for the role it plays for the business
  modules that call it. Each of its methods reads state and changes
  none: it writes nothing to the database and publishes no event. In a
  business module that follows `design-cqrs.md`, each such method is
  served by a query.
- Each contract interface is implemented by one `internal sealed` class
  of its business module. That class is to the business module what
  host code is under the architecture overlay it follows: each method
  makes the one call that overlay has host code make and translates
  the result into the contract's types. In a business module that
  follows `architecture-clean.md` the class lives in
  `<Area>.Application`, and `Add<Name>Application` registers it. In
  one that follows `architecture-vertical-slice.md` it lives in
  `Shared/`, and `Add<Name>` registers it.

Reaching another business module
- A business module calls the contract interfaces of another in one
  type only: its adapter for the other, an `internal sealed` class
  named `<Other>Adapter`, `<Other>` being the last segment of the other
  business module's `<Area>`. The adapter takes the other's contract
  interfaces in its constructor and translates what they return into
  types of its own business module: none of its methods accepts or
  returns a type of the other's contracts project.
- In a business module that follows `architecture-clean.md`: a call
  into another business module is an I/O need of the use case that
  makes it. The need is an interface declared in `<Area>.Application`,
  as that overlay requires, and the adapter, in
  `<Area>.Infrastructure`, implements every such interface the other
  business module serves.
- In a business module that follows `architecture-vertical-slice.md`:
  the adapter lives in `Shared/` and implements no interface, and a
  handler that needs the other business module calls it. For an
  adapter that a single slice uses, this is a stated exception to that
  overlay's folder rule, which sends such a type to the slice's folder.
- A business module changes the state of another in one way: it
  publishes an event that the other consumes. A business module that
  publishes an event another consumes, and the one that consumes it,
  both follow `design-event-driven.md`.
- A business module is one bounded context. Outside the contracts
  projects no type is shared: where two business modules need one
  concept, each declares its own type for it.

Data
- A business module's tables are its own: no code outside the business
  module reads or writes them, and only its migrations create or change
  them.
- No foreign key, view, or SQL statement of a business module names a
  table of another, and no transaction writes the tables of two.
- A business module reads another's data through its adapter. A table
  that copies another business module's data, kept current by a
  consumer, is added on the maintainer's instruction alone.
- On a database engine that has schemas inside one database, a business
  module's tables are in a schema of its own: `<Name>` in lower case,
  `<Name>` being the last segment of `<Area>`. On an engine that has
  none, this overlay has no rule for telling the business modules'
  tables apart. Ask the maintainer for one before the second business
  module's first table.

Placement
- In a business module that follows `design-event-driven.md`: the
  outbox, the dispatcher, the inbox, and the two interfaces are the
  business module's own. An event type that a consumer in another
  business module handles lives in the publisher's contracts project,
  moving there in the change that adds that consumer, and from the
  first such event type on the publisher's two interfaces live there
  too. These are stated exceptions to the placements that overlay
  gives event types and the two interfaces under
  `architecture-clean.md` and under `architecture-vertical-slice.md`.
- A consumer of another business module's event implements the
  consumer interface the publisher's contracts project declares. Its
  own business module's registration method registers it, and the
  publisher's dispatcher calls it as it calls a consumer of the
  publisher's own business module. Its inbox row is in its own
  business module's inbox. It handles the event type itself: in a
  business module's projects under `src/`, only an adapter, such a
  consumer, and a registration method name a type of another business
  module's contracts project.
- With `persistence-efcore.md`: no `DbContext` maps the tables of two
  business modules. Where the rule under Data gives a business module
  a schema, its `DbContext` sets that schema with `HasDefaultSchema`,
  and the code that registers the `DbContext` calls
  `MigrationsHistoryTable`, on the provider's options, with
  `HistoryRepository.DefaultTableName` and that schema, so that the
  table recording the business module's migrations is one of its own.
  Where the business module declares an
  `IDesignTimeDbContextFactory<TContext>`, the factory makes the same
  call: `dotnet ef` then takes the options from the factory, not from
  the registration.
  `dotnet ef` is always run with `--context` naming the business
  module's `DbContext`: a host that runs several business modules
  registers a `DbContext` for each, and without `--context` the tool
  finds more than one and stops.
- Where `persistence-dapper.md` is imported and `persistence-efcore.md`
  is not: a business module's scripts are embedded in its own project,
  as that overlay places them, and create or change only its own
  tables. The migrator applies the scripts of every business module.

Testing
- An adapter is unit-tested with a test double of the other business
  module's contract interface, in the unit-test project of the project
  that holds it.
- In a business module that follows `architecture-clean.md`, the class
  that implements a contract interface is unit-tested in
  `<Area>.Application.UnitTests`, to which `<Area>.Application` grants
  `InternalsVisibleTo`.
- In a business module that follows `architecture-vertical-slice.md`,
  the class that implements a contract interface is tested with the
  real handler, in `<Area>.IntegrationTests` when the handler reaches a
  database — a stated exception to that overlay's unit-testing of the
  types in `Shared/`. A handler that calls an adapter is tested with
  the real adapter over a test double of the contract interface.
- Behavior that spans two business modules — an event one publishes and
  another consumes, or a call through an adapter into the other's real
  implementation — is tested through a host, in that host's
  `.IntegrationTests` project.
