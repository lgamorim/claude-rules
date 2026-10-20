# Contoso.Orders API

Minimal API + EF Core (Npgsql) sample used to demonstrate the shared .NET rules
from this repo in a real, if tiny, codebase. It is the reference deployment of
the `application-solo` profile plus the EF Core persistence overlay.

## Build & test
- `dotnet build`
- `dotnet test` (needs a running Docker engine: the integration tests start
  Postgres with Testcontainers)
- `dotnet user-secrets set ConnectionStrings:Orders "<connection string>"
  --project src/Contoso.Orders.Api` once, then
  `dotnet run --project src/Contoso.Orders.Api`
- `dotnet tool restore`, then
  `dotnet ef migrations add <Name> --project src/Contoso.Orders.Api` after
  a model change

## Shared conventions
@../../.claude/rules/profiles/application-solo.md
@../../.claude/rules/overlays/persistence-efcore.md

## Project-specific notes
- Layout follows `core/architecture.md`'s repo/solution convention: source
  under `src/Contoso.Orders.Api/`, unit tests under
  `test/Contoso.Orders.Api.UnitTests/`, integration tests under
  `test/Contoso.Orders.Api.IntegrationTests/` (both suffixes come from
  `archetype/application.md`), and a single `ContosoOrders.slnx` at this
  project's root referencing all three. Each project is named for its root
  namespace (`Contoso.Orders.Api`), so the assembly name matches the namespace.
- `Directory.Build.props` at this project's root centralizes `TargetFramework`,
  `Nullable`, `ImplicitUsings`, `TreatWarningsAsErrors`, and `IsPackable` so
  every project inherits them instead of repeating them —
  `Contoso.Orders.Api.csproj` only adds what's specific to it
  (`InvariantGlobalization`, `GenerateDocumentationFile`). `IsPackable` stays
  false per `archetype/application.md`: the deliverable is the running app,
  not a package.
- `.editorconfig` at this project's root encodes `core/coding-standards.md`'s
  naming and style rules (`_camelCase` private fields, `I`-prefixed interfaces,
  file-scoped namespaces, unused-using removal) so `dotnet format` and the
  build enforce them, not just prose. `EnforceCodeStyleInBuild` (in
  `Directory.Build.props`) makes style violations fail the build; naming
  violations are caught by `dotnet format`. `IDE0005` is scoped down for the
  test projects, which omit `GenerateDocumentationFile` that build-time
  `IDE0005` requires.
- Entry point: `src/Contoso.Orders.Api/Program.cs`.
- The `Orders` connection string carries the database password, so it never
  goes in `appsettings*.json` (`archetype/application.md`). Locally it comes
  from user-secrets, which .NET 10's `WebApplication.CreateBuilder` loads
  only in the Development environment that
  `src/Contoso.Orders.Api/Properties/launchSettings.json` sets for
  `dotnet run`; a deployed host sets the `ConnectionStrings__Orders`
  environment variable.
- All data access goes through
  `src/Contoso.Orders.Api/Data/OrdersDbContext.cs` — no raw SQL
  and no second `DbContext`, a convention of this project. Entity
  configuration stays in `OnModelCreating`, as
  `overlays/persistence-efcore.md` requires.
- Schema changes are EF migrations under
  `src/Contoso.Orders.Api/Data/Migrations/`, as
  `overlays/persistence-efcore.md` requires. `dotnet-ef` is pinned in
  `dotnet-tools.json` to the EF Core version the project references; with
  10.0.9, `migrations add` writes a new migration beside the existing model
  snapshot, so that folder needs no `--output-dir`. The same overlay exempts
  migrations from core's coding standards: `.editorconfig` marks the folder
  `generated_code = true`, so the style analyzers and `dotnet format` skip
  it, and a migration is edited only to change what it does.
- `Order` is the only aggregate root currently modeled. Endpoints in
  `src/Contoso.Orders.Api/Endpoints/OrdersEndpoints.cs` talk to
  `OrdersDbContext` directly —
  don't introduce a repository/service layer for it. A single-implementation
  interface here would be a speculative abstraction with no current benefit,
  which `core/design-principles.md`'s YAGNI rule explicitly disallows.
- `Order` is a plain mutable class, not a record: it's an EF Core-tracked
  aggregate that needs mutable, parameterless-constructible state, which the
  ORM exception in `overlays/persistence-efcore.md` allows. That exception is
  the *only* sanctioned departure from core's "prefer records" guidance.
- Endpoint conventions of this project, which no imported module states:
  every handler accepts a `CancellationToken` and threads it through to the
  EF Core calls (`ToListAsync`, `FirstOrDefaultAsync`, `SaveChangesAsync`);
  endpoints are grouped with `MapGroup`; and handlers return `Results.*`
  helpers instead of hand-rolled status codes.
- `Program.cs` pairs `AddProblemDetails()` with `app.UseExceptionHandler()` —
  ASP.NET Core's built-in exception-handling middleware, which turns unhandled
  exceptions into RFC 9457 problem-details responses, rather than a bespoke
  error-handling layer, consistent with `core/design-principles.md`'s
  no-overengineering guidance.
- The test projects don't set `GenerateDocumentationFile`: per
  `core/coding-standards.md`'s test-project exemption, their `public` test
  classes exist only for xUnit discovery, not as a consumed API surface.
- `test/Contoso.Orders.Api.UnitTests/OrdersDbContextTests.cs` uses EF Core's
  in-memory provider, which `overlays/persistence-efcore.md` permits for
  mapping/configuration smoke tests: it asserts that an `Order` round-trips
  through the model, a result identical on any provider. Keep it that way — the
  moment a test asserts provider behavior (SQL translation, constraints,
  transactions) it belongs in `test/Contoso.Orders.Api.IntegrationTests/`
  against real Postgres, per that overlay.
- Endpoint behavior is tested in `test/Contoso.Orders.Api.IntegrationTests/`,
  not in `.UnitTests`: handlers use `OrdersDbContext` directly, so what they
  return depends on the provider, and the in-memory provider is limited to
  mapping smoke tests. `OrdersApiFactory` hosts the app through
  `WebApplicationFactory<Program>` against a Testcontainers Postgres and
  applies the migrations before the first test, so the migrations run against
  the real engine too. .NET 10 generates `Program` as a public class, so the
  factory needs no `public partial class Program` declaration.
- This sample ships one test per test project, a mapping round-trip and a
  NotFound endpoint check, rather than the full edge-case set
  `core/testing-philosophy.md` normally requires — an explicitly scoped
  exception per that file's own precedence rule, called out here rather than
  left silent.
