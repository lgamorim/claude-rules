# Contoso.Csv library

A small RFC 4180 CSV reader used to demonstrate the shared .NET rules from
this repo on a reusable package. It is the reference deployment of the
`library-team` profile.

## Build & test
- `dotnet build` and `dotnet test` (needs the .NET 10 and .NET 11 runtimes,
  one per target framework, and SDK 11 to build `net11.0`)
- `dotnet pack` writes the package to
  `src/Contoso.Csv/bin/Release/`
- From this folder, `dotnet run -c Release --project
  bench/Contoso.Csv.Benchmarks` runs the benchmarks; add `-- --job Dry` to
  smoke-test their plumbing only

## Shared conventions
@../../.claude/rules/profiles/library-team.md

## Project-specific notes
- The profile imports `overlays/workflow-team.md` to show what a library
  repo with several contributors gets. This example is not such a repo:
  it lives in the rule set's own repository, so a change to it follows the
  flow in the root `CLAUDE.md` (a reviewed `feature/` branch, squash-merged
  without a pull request), and `workflow-team.md`'s pull-request and
  branch-protection rules do not apply to it.
- Layout follows `core/architecture.md`: source under `src/Contoso.Csv/`,
  unit tests under `test/Contoso.Csv.UnitTests/` (`archetype/library.md`),
  benchmarks under `bench/Contoso.Csv.Benchmarks/`
  (`overlays/benchmarks.md`), and one `ContosoCsv.slnx` at this project's
  root referencing all three, so CI builds the benchmarks too.
- There is no `.IntegrationTests` project: the reader takes a `TextReader`
  and reaches no real dependency, and `archetype/library.md` adds that
  project only for one.
- `Directory.Build.props` sets `TargetFrameworks` to `net10.0;net11.0`, the
  .NET releases in support when this example was written, as
  `archetype/library.md`'s full TFM matrix requires; the test project
  inherits both, so every test runs on each. The benchmark project
  overrides it with `net10.0` alone: a baseline is measured on one runtime.
- `IsPackable` is false in `Directory.Build.props` and true only in
  `Contoso.Csv.csproj`, so `dotnet pack` on the solution produces the one
  package and never a test or benchmark package.
- The public API is the package's contract (`archetype/library.md`):
  `CsvReader.ReadAsync` and `CsvFormatException`, nothing else. Everything
  else is `private` or `internal`, including `CsvFormatException`'s
  constructor, so consumers cannot depend on it. `Version` in
  `Contoso.Csv.csproj` follows semantic versioning: an added public member
  is a minor bump, a removed or changed one a major bump with a note in the
  commit that makes it.
- `Contoso.Csv.csproj` sets `GenerateDocumentationFile`, so with
  `TreatWarningsAsErrors` a public member without an XML doc comment fails
  the build: the docs ship in the package and are kept complete.
- The benchmark project also sets `GenerateDocumentationFile`: BenchmarkDotNet
  needs its benchmark class `public`, and `core/coding-standards.md`
  exempts only test projects from documenting public types.
- `ReadAsync` checks its arguments before it returns, and only the
  enumeration is deferred: a project convention, so a bad argument fails at
  the call, not at the first `MoveNextAsync`.
- `OneCharacterReader` in the test project returns one character per read,
  so the tests reach every buffer boundary without depending on the
  reader's internal buffer size, which `archetype/library.md` keeps behind
  the public surface.
- Benchmarks are never run in CI (`overlays/benchmarks.md`), not even with
  `--job Dry`; CI only builds them. Baselines are measured locally and
  recorded in `docs/benchmarks.md`.
