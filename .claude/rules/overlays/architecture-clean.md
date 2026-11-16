# Overlay — Architecture (Clean)

Add when the application separates its Domain, Application, and
Infrastructure layers into projects — the structure also called Onion or
Hexagonal (ports and adapters) architecture. A layered (N-tier)
application takes this overlay too: core's dependency rule already forbids
a business layer that references its data-access layer, and with that
reference inverted the layers are these three. Compose with
`archetype/application.md`.

Importing this overlay is the decision to layer: the projects and
interfaces it requires are not justified again per change, and its
interfaces are the layer isolation that core's single-implementation rule
exempts. Core's YAGNI rule governs everything this overlay does not
require.

Terms
- Under this overlay an **area** is the three layer projects
  `<Area>.Domain`, `<Area>.Application`, and `<Area>.Infrastructure`, with
  their test projects. A repo holds one area or several.
- The **layers** are the ones core's dependency rule names. **Domain**
  holds the types that model the business: entities, the values they
  hold, and the rules over them. **Application** holds the use cases —
  the operations a host offers — with the interfaces they need for I/O
  and the records they accept and return. **Infrastructure** holds the
  implementations of those interfaces and all other code of the area that
  reaches a database, the file system, the network, or a message broker.
- A **host** is an executable project the deployment runs as the
  application. The migrator of `persistence-dapper.md` is an executable
  but not a host.

Structure (adds to `core/architecture.md`)
- Each layer is one project: `src/<Area>.Domain/`,
  `src/<Area>.Application/`, and `src/<Area>.Infrastructure/`. A host is a
  project of its own under `src/` and belongs to no area.
- A layer project's project references are exactly these:
  `<Area>.Domain` references no project; `<Area>.Application` references
  `<Area>.Domain`; `<Area>.Infrastructure` references `<Area>.Application`
  and reaches Domain types through it, since project references flow
  transitively.
- A host references the Application and Infrastructure projects of each
  area it runs. Among the projects under `src/`, only a host and the
  migrator — for the scripts it applies — reference an Infrastructure
  project.
- `<Area>.Domain` has no package reference except analyzers marked
  `PrivateAssets="all"`. `<Area>.Application` references no package whose
  purpose is to reach a database, the file system, the network, or a
  message broker; with a persistence overlay imported, that excludes
  every `Microsoft.EntityFrameworkCore*` package, Dapper, and ADO.NET
  providers.

Conventions
- Each I/O need of a use case is an interface declared in
  `<Area>.Application`, named for the role it plays there, and
  implemented by an `internal sealed` class in `<Area>.Infrastructure`.
  Time is the exception: a use case takes `TimeProvider` itself.
- Domain code performs no I/O and reads no clock. It declares no `async`
  method and no member returning `Task` or `ValueTask`, generic forms
  included, and the current time reaches it as a `DateTimeOffset`
  argument that a use case read from `TimeProvider`.
- Every hand-written type in `<Area>.Infrastructure` is `internal`, except
  the one `public static` class holding its registration method.
  Generated code — the files in a folder `.editorconfig` marks
  `generated_code = true` — is exempt. The project grants
  `InternalsVisibleTo` to its own test projects and to no other assembly.
- `<Area>.Application` and `<Area>.Infrastructure` each expose one
  extension method on `IServiceCollection` — `Add<Name>Application` and
  `Add<Name>Infrastructure`, `<Name>` being the last segment of `<Area>` —
  that registers every service the project provides. A host calls both
  and registers no type of the area itself; beyond that call, host code
  uses no Infrastructure type.
- Host code that handles a request or a UI event makes one call into
  `<Area>.Application` and translates the result into the response. The
  call goes to a use case, or straight to an interface declared there
  when the operation is that single call: a use-case type that only
  forwards one call is not written. Code that sequences several calls is
  a use case. The type called is the application service
  `frontend-mvc.md` has a handler call.
- With `persistence-efcore.md`: the `DbContext` is `internal` like every
  other Infrastructure type, which the EF Core tools support. `dotnet ef`
  runs with `--project` set to `<Area>.Infrastructure` and
  `--startup-project` set to a host, and that host references
  `Microsoft.EntityFrameworkCore.Design` with `PrivateAssets="all"`. Two
  kinds of host are never the startup project. The first is a .NET MAUI,
  WinUI, or Azure Functions application, or a host whose project sets
  the `RuntimeIdentifier` property: the tools' documentation advises
  against each, and it stays excluded on a machine where `dotnet ef`
  happens to run it. The second is any other host `dotnet ef` cannot
  execute because of the platform it targets; a host that fails for a
  defect in its own code is fixed, not excluded. When every host is
  excluded, `<Area>.Infrastructure` is both target and startup project,
  and holds the `Design` reference and an `internal sealed`
  `IDesignTimeDbContextFactory<TContext>`.
- With `persistence-dapper.md`: its type handlers are registered inside
  the Infrastructure registration method, which runs in the host's
  startup code as that overlay requires.
- With `frontend-blazor.md`: a project whose components run in the
  browser on WebAssembly is not a host and belongs to no area. The
  abstraction that overlay requires for such a component is declared in
  that project together with its HTTP-client implementation; its server
  implementation is host code that makes the one call into
  `<Area>.Application`.

Testing
- Each layer project gets its test projects by the archetype's naming,
  e.g. `test/<Area>.Domain.UnitTests/` and
  `test/<Area>.Infrastructure.IntegrationTests/`.
- The failing test that motivates a use case is written in
  `<Area>.Application.UnitTests`, with a test double for each interface
  the use case depends on. That project never references
  `<Area>.Infrastructure`.
