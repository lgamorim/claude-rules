# Sample project

A minimal ASP.NET Core + EF Core (Npgsql) API, kept intentionally small, used only
to show the rules in this repo applied to a real — if tiny — codebase.

## What to look at

- **`CLAUDE.md`** — imports the shared rules from `../../.claude/rules/` via `@`
  syntax (`coding-standards.md`, `architecture.md`, `design-principles.md`,
  `testing.md`, `workflow.md`), plus a few project-specific notes (build
  commands, where data access is allowed to live).
- **`src/Contoso.Orders.Api/Data/OrdersDbContext.cs`** — follows `design-principles.md`'s
  encapsulation guidance: entity configuration stays in `OnModelCreating`, no
  raw SQL, no second `DbContext`.
- **`src/Contoso.Orders.Api/Endpoints/OrdersEndpoints.cs`** — follows `coding-standards.md`:
  minimal API grouping, a `CancellationToken` threaded through every handler,
  `Results.*` helpers instead of hand-rolled status codes.
- **`test/Contoso.Orders.Api.Tests/`** — follows `testing.md`: one behavior per test, EF
  Core's in-memory provider instead of a real Postgres instance for a fast
  unit test.
- **`Directory.Build.props`** — follows `architecture.md`'s convention of
  centralizing shared MSBuild settings (`TargetFramework`, `Nullable`,
  `TreatWarningsAsErrors`, `EnforceCodeStyleInBuild`, etc.) in one place, so
  `coding-standards.md`'s zero-warning/nullable rules are enforced there
  instead of copy-pasted into every `.csproj`.
- **`.editorconfig`** — turns `coding-standards.md`'s naming/style conventions
  into rules that `dotnet format` and the build enforce, rather than leaving
  them as prose. Paired with `EnforceCodeStyleInBuild`, an out-of-convention
  name or an unused `using` fails tooling instead of passing silently.

## Why this matters more than the rules themselves

A rule nobody can see in action is easy to skim past. This project exists so a
new contributor — or a fresh Claude Code session — can open one real file and
see the convention, rather than just read a bullet point about it.

## Try it

Ask Claude Code to add a `DELETE /orders/{id}` endpoint. With the rules in
place, it should:
- add the endpoint to `OrdersEndpoints.cs`, not a new file
- thread a `CancellationToken` through it
- return `Results.NoContent()` on success and `Results.NotFound()` if the
  order doesn't exist
- add a matching test in `Contoso.Orders.Api.Tests`

Without the rules, it's more likely to invent a repository interface, wrap
the result in a custom response type, or skip the test — none of which are
wrong in isolation, just inconsistent with everything else already here.
