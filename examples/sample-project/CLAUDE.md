# Contoso.Orders API

Minimal API + EF Core (Npgsql) sample used to demonstrate the shared .NET rules
from this repo in a real, if tiny, codebase.

## Build & test
- `dotnet build`
- `dotnet test`
- `dotnet run --project src/Contoso.Orders.Api`

## Shared conventions
@../../.claude/rules/coding-standards.md
@../../.claude/rules/architecture.md
@../../.claude/rules/design-principles.md
@../../.claude/rules/testing.md
@../../.claude/rules/workflow.md

## Project-specific notes
- Layout follows `architecture.md`'s repo/solution convention: source
  under `src/Contoso.Orders.Api/`, tests under
  `test/Contoso.Orders.Api.Tests/`, and a single `ContosoOrders.slnx` at this
  project's root referencing both. Each project is named for its root
  namespace (`Contoso.Orders.Api`), so the assembly name matches the namespace.
- `Directory.Build.props` at this project's root centralizes `TargetFramework`,
  `Nullable`, `ImplicitUsings`, `TreatWarningsAsErrors`, and `IsPackable` so
  both `Contoso.Orders.Api.csproj` and `Contoso.Orders.Api.Tests.csproj`
  inherit them instead of repeating them — `Contoso.Orders.Api.csproj` only
  adds what's specific to it (`InvariantGlobalization`,
  `GenerateDocumentationFile`).
- `.editorconfig` at this project's root encodes `coding-standards.md`'s naming
  and style rules (`_camelCase` private fields, `I`-prefixed interfaces,
  file-scoped namespaces, unused-using removal) so `dotnet format` and the
  build enforce them, not just prose. `EnforceCodeStyleInBuild` (in
  `Directory.Build.props`) makes style violations fail the build; naming
  violations are caught by `dotnet format`. `IDE0005` is scoped down for the
  test project, which omits `GenerateDocumentationFile` that build-time
  `IDE0005` requires.
- Entry point: `src/Contoso.Orders.Api/Program.cs`.
- All data access goes through
  `src/Contoso.Orders.Api/Data/OrdersDbContext.cs` — no raw SQL
  and no second `DbContext`. Entity configuration stays in `OnModelCreating`,
  keeping persistence concerns encapsulated per `design-principles.md`.
- `Order` is the only aggregate root currently modeled. Endpoints in
  `src/Contoso.Orders.Api/Endpoints/OrdersEndpoints.cs` talk to
  `OrdersDbContext` directly —
  don't introduce a repository/service layer for it. A single-implementation
  interface here would be a speculative abstraction with no current benefit,
  which `design-principles.md`'s YAGNI rule explicitly disallows.
- `Order` is a plain mutable class, not a record: it's an EF Core-tracked
  aggregate that needs mutable, parameterless-constructible state, which
  `coding-standards.md`'s ORM-entity exception to "prefer records" allows.
- Every endpoint handler accepts and threads a `CancellationToken` through to
  the EF Core calls (`ToListAsync`, `FirstOrDefaultAsync`, `SaveChangesAsync`),
  and async methods end in `Async`, per `coding-standards.md`. Minimal API
  grouping (`MapGroup`) and `Results.*` helpers are used instead of
  hand-rolled status codes to keep endpoint code idiomatic.
- `Program.cs` pairs `AddProblemDetails()` with `app.UseExceptionHandler()` —
  ASP.NET Core's built-in exception-handling middleware, which turns unhandled
  exceptions into RFC 9457 problem-details responses, rather than a bespoke
  error-handling layer, consistent with `design-principles.md`'s
  no-overengineering guidance.
- `test/Contoso.Orders.Api.Tests/OrdersDbContextTests.cs` uses EF Core's in-memory provider
  instead of a real Postgres instance, per `testing.md`'s requirement that
  unit tests be fast and deterministic with no real I/O.
- `Contoso.Orders.Api.Tests.csproj` doesn't set `GenerateDocumentationFile`: per
  `coding-standards.md`'s test-project exemption, its `public` test classes
  exist only for xUnit discovery, not as a consumed API surface.
- This sample ships a single happy-path test rather than the full edge-case
  set `testing.md` normally requires — an explicitly scoped exception per
  that file's own precedence rule, called out here rather than left silent.
