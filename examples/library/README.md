# Library example

A small RFC 4180 CSV reader, `Contoso.Csv`, kept intentionally small, used
only to show the rules in this repo applied to a reusable package. It is the
reference deployment of the **`library-team`** profile.

## What to look at

- **`CLAUDE.md`** — imports the single `profiles/library-team.md` profile
  from `../../.claude/rules/` and adds project-specific notes. The profile
  brings `archetype/library.md`, `overlays/workflow-team.md`, and
  `overlays/benchmarks.md` on top of the five core modules.
- **`src/Contoso.Csv/`** — follows `archetype/library.md`: the public API is
  two types, each member documented, since the docs ship in the package.
  `Contoso.Csv.csproj` turns a missing doc comment into a build error and
  carries the package's semantic `Version`.
- **`Directory.Build.props`** — follows `core/architecture.md` by
  centralizing shared MSBuild settings, and `archetype/library.md` by
  targeting every supported .NET release (`net10.0;net11.0`).
- **`test/Contoso.Csv.UnitTests/`** — follows `core/testing-philosophy.md`:
  `Should_ExpectedOutcome_When_Scenario` names and edge cases for empty
  input, each line break, quoting, malformed text, null and invalid
  arguments, and cancellation. Per `archetype/library.md`, the tests drive
  only the public surface; `OneCharacterReader` reaches the internal buffer
  boundaries from outside. There is no `.IntegrationTests` project, because
  the reader reaches no real dependency.
- **`bench/Contoso.Csv.Benchmarks/`** — follows `overlays/benchmarks.md`: a
  BenchmarkDotNet project in the solution, so CI builds it, but CI never
  runs it.
- **`docs/benchmarks.md`** — the baseline measured locally, which the same
  overlay requires instead of CI numbers.
- **`../../.github/workflows/example-library.yml`** — follows
  `archetype/library.md`: CI runs the tests on every operating system the
  package claims (Linux, Windows, macOS) and on both target frameworks,
  and runs `dotnet pack` from day one.

## Try it

Ask Claude Code to let `ReadAsync` skip a header row. With the rules in
place, it should:
- write the failing tests first in `CsvReaderTests.cs`, covering an empty
  input and a header-only input as well as the usual case
- add an overload rather than a parameter on the existing method, since a
  new optional parameter changes the method's signature and breaks callers
  compiled against `1.0.0`
- document the overload with an XML comment and bump `Version` in
  `Contoso.Csv.csproj` from `1.0.0` to `1.1.0`, a minor bump for an added
  public member
- leave the benchmarks to be run locally, updating `docs/benchmarks.md` only
  with numbers measured on a real machine

Without the rules, it's more likely to change the existing signature, leave
the new parameter undocumented, or forget the version: none of which is
wrong in an application, but each of which breaks a package's consumers.
