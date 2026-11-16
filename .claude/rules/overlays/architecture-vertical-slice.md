# Overlay — Architecture (Vertical Slice)

Add when each use case of the application is built as one slice — its
handler, its request and response, and its data access together — instead
of being spread over layers. Compose with `archetype/application.md`.

This overlay and `architecture-clean.md` are alternatives for one area:
an area follows at most one of them. A repo that imports both also imports
`architecture-areas.md`, whose table says which area follows which.

Importing this overlay is the decision to build by slice. An area that
follows it has no Application and Infrastructure layers, so core's
dependency rule has no boundary to separate inside it: this is a stated
exception to that rule, and core's single-implementation rule governs
instead — a handler reaches its data access directly, with no interface
between.

Terms
- Under this overlay an **area** is one project, `<Area>`, with its test
  projects. A repo holds one area or several. An area **follows** this
  overlay when the overlay is imported and, where `architecture-areas.md`
  is imported too, the area's row names it.
- A **slice** is one use case: a folder holding its handler and every
  type only that use case needs.
- In this overlay **handler** means a slice's handler: the slice's one
  type that carries out the use case. The page handlers of
  `frontend-mvc.md` and the type handlers of `persistence-dapper.md` are
  other things and keep their qualifiers.
- A **host** is an executable project the deployment runs as the
  application. The migrator of `persistence-dapper.md` is an executable
  but not a host.

Structure (adds to `core/architecture.md`)
- The area is the project `src/<Area>/`, a class library on
  `Microsoft.NET.Sdk`. When its slices declare endpoints it takes ASP.NET
  Core through `<FrameworkReference Include="Microsoft.AspNetCore.App" />`,
  never through the Web SDK. A host is a project of its own under `src/`
  and belongs to no area.
- `<Area>` references no other project under `src/`. A host references
  the project of each area it runs, and among the projects under `src/`
  only a host and the migrator — for the scripts it applies — reference
  an area's project.
- A slice is the folder `Features/<Feature>/<UseCase>/`, and its types
  are in the namespace `<Area>.Features.<Feature>.<UseCase>`. `<Feature>`
  is a plural noun naming what its use cases act on; `<UseCase>` is a
  verb phrase naming the one operation, e.g.
  `Features/Orders/PlaceOrder/`.
- Each type in a slice is named `<UseCase>` followed by its role. Four
  roles have fixed names: `<UseCase>Handler`, `<UseCase>Request`,
  `<UseCase>Response`, and `<UseCase>Endpoint`.
- Entities and the values they hold live in `Domain/`. Of the other
  types, one that a single slice uses lives in that slice's folder, and
  every other lives in `Shared/` unless a rule below places it.

Conventions
- A slice has exactly one handler: a `sealed class` with one public
  method, `HandleAsync`, which takes the slice's request and a
  `CancellationToken` and returns a `Task` carrying the slice's response.
  A use case with no input has no request type, and one with no output
  has no response type. Handlers share no base class, and share an
  interface only when a decorator applies to every handler of the area,
  with the benefit stated as core requires of a pattern.
- No slice uses a type declared in another slice's folder, and no handler
  calls another handler.
- A handler does its own data access. No repository, service, or other
  interface stands between the handler and the database it reads or
  writes.
- The area exposes one `public static` class, at the project root, with
  two extension methods: `Add<Name>` on `IServiceCollection`, registering
  every service the area provides, and — when its slices declare
  endpoints — `Map<Name>Endpoints` on `IEndpointRouteBuilder`; `<Name>`
  is the last segment of `<Area>`. A host calls them and registers or
  maps nothing of the area itself.
- A type in the area is `public` only when a host uses it; every other
  type is `internal`. A `public` handler whose constructor takes an
  `internal` type, such as the `DbContext`, declares that constructor
  `internal`, as the compiler requires, and `Add<Name>` registers the
  handler with a factory delegate: the built-in service container
  activates a type only through a public constructor. Generated code —
  the files in a folder `.editorconfig` marks `generated_code = true` —
  is exempt. The project grants `InternalsVisibleTo` to its own test
  projects and to no other assembly.
- A use case served over a minimal-API route declares its endpoint in the
  slice: `<UseCase>Endpoint` is a `static` class whose one method, `Map`,
  takes an `IEndpointRouteBuilder` and maps the route to the handler, and
  `Map<Name>Endpoints` calls each slice's `Map` explicitly, never by
  scanning the assembly. A use case served any other way keeps the type
  that serves it — a Razor page, controller, or component — in the host,
  where it makes one call to the handler and translates the result into
  the response. The handler is the application service `frontend-mvc.md`
  has a page handler or controller call.
- With `persistence-efcore.md`: the `DbContext` and its mapping live in
  `Data/`, its migrations in `Data/Migrations/`, and a handler uses the
  `DbContext` directly; where `frontend-blazor.md` is imported too, the
  handler takes it from `IDbContextFactory<T>` as that overlay requires.
  The `DbContext` is `internal`, which the EF Core tools support.
  `dotnet ef` runs with `--project` set to `<Area>` and
  `--startup-project` set to a host, and that host references
  `Microsoft.EntityFrameworkCore.Design` with `PrivateAssets="all"`. Two
  kinds of host are never the startup project. The first is a .NET MAUI,
  WinUI, or Azure Functions application, or a host whose project sets
  the `RuntimeIdentifier` property: the tools' documentation advises
  against each, and it stays excluded on a machine where `dotnet ef`
  happens to run it. The second is any other host `dotnet ef` cannot
  execute because of the platform it targets; a host that fails for a
  defect in its own code is fixed, not excluded. When every host is
  excluded, `<Area>` is both target and startup project, and holds the
  `Design` reference and an `internal sealed`
  `IDesignTimeDbContextFactory<TContext>`.
- With `persistence-dapper.md`: its type handlers live in `Data/` and are
  registered inside `Add<Name>`, which runs in the host's startup code as
  that overlay requires. That overlay states how its repository rules
  read in an area that follows this one.
- With `frontend-blazor.md`: a project whose components run in the
  browser on WebAssembly is not a host and belongs to no area. The
  abstraction that overlay requires for such a component is declared in
  that project together with its HTTP-client implementation; its server
  implementation is host code that makes the one call to a handler.

Testing
- Test projects follow the archetype's naming: `test/<Area>.UnitTests/`
  and `test/<Area>.IntegrationTests/`. Each mirrors the area's folders, so
  a slice's tests live under `Features/<Feature>/<UseCase>/`.
- A handler that reaches a database is tested in
  `<Area>.IntegrationTests` against the real engine, and the failing test
  that motivates it is written there: the handler has no seam for a test
  double, and the persistence overlays keep provider behavior out of unit
  tests.
- Every other handler, and the types in `Domain/` and `Shared/`, are
  unit-tested in `<Area>.UnitTests`.
- Host code that calls a handler — a page handler, controller, or
  component — is tested with the real handler, and no interface is added
  to a handler to give its caller a test double. The tests live in the
  host's unit-test project, or in its `.IntegrationTests` project when
  the handler reaches a database; for that caller this replaces the
  unit-test placement `frontend-mvc.md` and `frontend-blazor.md` give.
- A slice's endpoint is tested through a host, in that host's
  `.IntegrationTests` project.
