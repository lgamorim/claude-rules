# claude-rules

Opinionated [Claude Code](https://claude.com/claude-code) rules for .NET and C#
with conventions, architecture guidance, and guardrails for idiomatic,
production-ready code.

## What this is

This repository is **not an application** — it is a shared, reusable set of
project rules that tell Claude Code how to write and review C# the way you'd
want it written: Microsoft conventions, a sane project layout, SOLID without
overengineering, and test-driven development.

The rules are **small composable modules** rather than one monolithic ruleset,
because projects of different scope need different subsets. A **profile** bundles
the modules for a project archetype, so adopting the rules is a one-line import.

```
.claude/rules/
  core/         every profile imports all five, or four when its archetype replaces architecture.md
  archetype/    pick exactly one: library, application, unity-package, unity-game
  overlays/     orthogonal toggles: workflow, persistence, frontend,
                architecture, design, Unity engine, benchmarks
  profiles/     thin manifests composing the above (start here)
  templates/    skeletons consuming repos copy: path-scoped rules, reviewer subagent
examples/       buildable samples, each demonstrating a profile
tools/sync.ps1  copy a profile into a repo, or audit it for drift
tools/check.ps1 check this repo's own maintenance rules
```

## Profiles

A profile is a starting point: add to it every opt-in overlay your project
needs. [Overlays](#overlays) below says when each one applies.

| Profile | core | archetype | workflow | other overlays |
|---|---|---|---|---|
| [`library-team`](.claude/rules/profiles/library-team.md) | all 5 | library | team | benchmarks |
| [`application-solo`](.claude/rules/profiles/application-solo.md) | all 5 | application | solo | — |
| [`unity-package`](.claude/rules/profiles/unity-package.md) | all 5 | library + unity-package | team | unity-engine, benchmarks |
| [`unity-game`](.claude/rules/profiles/unity-game.md) | all but architecture | unity-game | solo | unity-engine |

The workflow posture in each profile is a **default, not a fixed pairing** —
there is deliberately no `library-solo` or `application-team`, because posture is
one orthogonal line. See
[`profiles/README.md`](.claude/rules/profiles/README.md) for how to swap it.

## The modules

The modules fall into three themes. A profile takes all of [core](#core)
except a module its archetype replaces, the [archetype](#archetypes) for its
kind of project, and one workflow posture from the [overlays](#overlays);
every other overlay is an opt-in.

### Core

Every profile imports all five, except that a profile omits `architecture.md`
when its archetype states the physical layout in its place.

| Module | What it covers |
|--------|----------------|
| [`coding-standards.md`][coding-standards] | Microsoft C# conventions and .NET naming: PascalCase/camelCase/`_camelCase`, `I`-prefixed interfaces, `Async` suffixes, one type per file, file-scoped namespaces, nullable enabled, XML docs on public APIs, zero-warning builds. Codified in an `.editorconfig` so `dotnet format` and the build enforce them. |
| [`design-principles.md`][design-principles] | OOP/SOLID guidance: composition over inheritance, dependencies pointing inward, patterns only when they earn their keep, and an explicit YAGNI constraint. |
| [`architecture.md`][architecture] | The default physical skeleton: source under `src/<ProjectName>/`, tests under `test/`, one solution file at the root, shared MSBuild properties in `Directory.Build.props`. A profile whose archetype states its own layout omits it. |
| [`testing-philosophy.md`][testing-philosophy] | Mandatory red/green/refactor TDD, `Should_ExpectedOutcome_When_Scenario` naming, Arrange-Act-Assert, deterministic tests (no real I/O or clock — abstract time via `TimeProvider`). |
| [`workflow-core.md`][workflow-core] | Minimal focused changes, imperative *why*-focused commits, feature branches merged by squash, no direct commits to the default branch. |

### Archetypes

Pick one per project. `unity-package.md` is the one that composes with
another: it adds to `library.md`, which governs the package's engine-agnostic
projects.

| Module | What it covers |
|--------|----------------|
| [`library.md`][library] | Shipped packages: `dotnet pack` in CI from day one, multi-TFM matrix, public API as a semver contract, `.UnitTests`/`.IntegrationTests` split. |
| [`application.md`][application] | Single deployables: `.UnitTests`, no packing, config from `appsettings`/environment, relaxed docs at the app boundary. |
| [`unity-package.md`][unity-package] | Unity 6 packages: UPM layout, engine-agnostic core, a managed oracle for any Burst backend, golden-corpus pipeline tests. |
| [`unity-game.md`][unity-game] | Games shipped as a Unity player: replaces `core/architecture.md` with the `Assets/` layout and assembly names, humble components over plain-C# game rules, ScriptableObject data never written at runtime, no `Find`/singleton lookups, a player build per shipped platform in CI. |

### Overlays

Orthogonal toggles, grouped by what they govern. Every project carries exactly
one workflow posture; every other overlay is an opt-in — a profile includes
some, and you add the rest to your `CLAUDE.md` or with `tools/sync.ps1 -Add`.

#### Workflow

Every project carries one posture: `workflow-solo.md` or `workflow-team.md`.
Add an agent-review overlay when a separate implement agent and review agent
work over each change, picking the variant that matches the posture.

| Module | What it covers |
|--------|----------------|
| [`workflow-solo.md`][workflow-solo] / [`workflow-team.md`][workflow-team] | The PR posture: solo waives the PR mechanism but not the review — the maintainer approves the finished branch before the squash-merge (feature branch + squash still stand); team requires a reviewed PR with branch protection. |
| [`workflow-agent-review-solo.md`][agent-review-solo] / [`workflow-agent-review-team.md`][agent-review-team] | An implement/review contract between two agents that never share a context: solo has the reviewer read the `feature/` branch diff before the squash-merge, team has it read the PR. Policy only — the reviewer runs from a definition in the consuming repo's `.claude/agents/`, for which [`templates/reviewer-subagent.md`](.claude/rules/templates/reviewer-subagent.md) is the skeleton, or as a fresh in-session subagent. |

#### Persistence

Add the overlay for each data-access library the project uses; a project using
both carries both.

| Module | What it covers |
|--------|----------------|
| [`persistence-efcore.md`][efcore] | The ORM exception to "prefer records", mapping in `OnModelCreating`, migrations, real-engine integration tests. |
| [`persistence-dapper.md`][dapper] | Positional records bound through the constructor, explicit column lists, parameters only, `CommandDefinition` cancellation, a unit of work as one repository method under one `DbTransaction`, DbUp migrations, integration tests against the production engine. |

#### Frontend

Add `frontend-mvc.md` to a project serving server-rendered Razor UI (MVC
and/or Razor Pages), and `frontend-blazor.md` to one rendering UI with Blazor;
a hybrid app carries both.

| Module | What it covers |
|--------|----------------|
| [`frontend-mvc.md`][mvc] | Server-rendered Razor UI: Razor Pages by default, thin controllers/handlers, view models never domain entities, tag helpers, Post/Redirect/Get, global antiforgery, markup tested at the boundary via `WebApplicationFactory`. |
| [`frontend-blazor.md`][blazor] | Blazor Web App across all render modes: static SSR by default, per-mode DI-lifetime and state rules, prerender double-execution, JS interop timing, disposal, bUnit-first testing. |

#### Architecture

Add `architecture-clean.md` to an application that separates its Domain,
Application, and Infrastructure layers into projects, or
`architecture-vertical-slice.md` to one built as one slice per use case — the
two are alternatives for one area. Add `architecture-modular-monolith.md` on
top of either when the application is made of business modules that each own
their tables, and `architecture-areas.md` when an architecture or design
overlay applies to only part of a repo. Add `architecture-microservices.md`
when the application is one deployable among several, each in a repository
of its own; it binds the whole repo.

| Module | What it covers |
|--------|----------------|
| [`architecture-clean.md`][clean] | Clean, Onion, or Hexagonal layering, and what a layered application becomes under core's dependency rule: `Domain`/`Application`/`Infrastructure` projects per area with references pointing inward, I/O behind interfaces the Application layer declares, an all-`internal` Infrastructure behind one registration method, hosts that make one call into the Application layer per request. |
| [`architecture-vertical-slice.md`][vertical-slice] | Vertical Slice architecture: one class-library project per area, one folder per use case holding its handler, request, response, and endpoint, handlers that do their own data access with no interface between, area types `internal` unless a host uses them, one registration method and one endpoint-mapping method for the host to call, database-reaching handlers tested against the real engine. |
| [`architecture-modular-monolith.md`][modular-monolith] | A modular monolith: business modules that each follow the Clean or the Vertical Slice overlay, own their tables and schema, and reach each other only through an `<Area>.Contracts` project whose contract interfaces only read and through events; one adapter type for each other business module called, a `DbContext` and migrations history per business module, and a first dependency between two business modules asked of the maintainer. |
| [`architecture-microservices.md`][microservices] | One deployable among several, each in a repository of its own: no code or data store shared with another, one `<Remote>Client` for each remote system that declares its own wire records and returns only the application's types, a remote system's state changed only through an event, published through the outbox or received, with its `EventId` as idempotency key, served routes that change additively only, and no transaction beyond the application's database. Binds the whole repo, so no area row names it. |
| [`architecture-areas.md`][areas] | Different architecture and design overlays on different parts of one repo: an `Area`/`Paths`/`Overlays` table in the root `CLAUDE.md` that says which area follows which overlay, edited only on the maintainer's instruction. |

#### Design

Add `design-domain-model.md` to an application whose business rules live in
entities, value objects, and aggregates; `design-cqrs.md` to one that
separates the use cases that change state from those that read it;
`design-event-sourcing.md`, on top of both, to one that stores an aggregate as
the domain events its root recorded; and `design-event-driven.md` to one whose
parts react to each other through events.

| Module | What it covers |
|--------|----------------|
| [`design-domain-model.md`][domain-model] | A domain model in the tactical patterns of Domain-Driven Design: `sealed record` value objects that enforce their invariants in one constructor, entity classes changed only through their methods, aggregates loaded and saved whole through their root, one `sealed` exception type per invariant, translated only by the code that produces the response, `<Fact>DomainEvent` records a root hands to the outbox publisher, and how EF Core maps these types. |
| [`design-cqrs.md`][cqrs] | Command Query Responsibility Segregation in code, over one database: every use case a command or a query, commands that return at most the id of what they created, queries that return one `<UseCase>Response` record and change nothing, one `sealed` handler per use case called directly with no mediator, and, where both persistence overlays are carried, EF Core for every command and Dapper for every query. |
| [`design-event-sourcing.md`][event-sourcing] | Event sourcing in one database, for every aggregate of an area that also follows the domain-model and CQRS overlays: a root that changes state only in `Apply` and is rebuilt by `Replay`, `<Fact>DomainEvent` records as a permanent contract with a stored `EventName`, an append-only event store whose per-stream version is the concurrency check, projections written by one `IProjector` each in the transaction that appends, and how EF Core stores them. |
| [`design-event-driven.md`][event-driven] | Events between parts of an application: `<Fact>IntegrationEvent` records with a stable wire name, published only through an outbox in the publisher's transaction, delivered at least once after commit by a background dispatcher, consumers idempotent through an inbox, additive-only event contracts. |

#### Unity engine

The Unity profiles include `unity-engine.md`; add it to any other project with
C# the Unity Editor compiles.

| Module | What it covers |
|--------|----------------|
| [`unity-engine.md`][unity-engine] | C# the Unity Editor compiles: IL2CPP and stripping, assembly definitions, `csc.rsp` compiler settings, Unity-safe null checks, serialized fields, lifecycle and `Awaitable`, allocation-free per-frame code, EditMode/PlayMode tests through the Unity CLI, `.meta` and YAML asset hygiene. |

#### Benchmarks

`library-team` and `unity-package` include `benchmarks.md`; add it to any
other project that tracks performance.

| Module | What it covers |
|--------|----------------|
| [`benchmarks.md`][benchmarks] | BenchmarkDotNet under `bench/`, built by CI but never run there, baselines produced locally. |

[coding-standards]: .claude/rules/core/coding-standards.md
[design-principles]: .claude/rules/core/design-principles.md
[architecture]: .claude/rules/core/architecture.md
[testing-philosophy]: .claude/rules/core/testing-philosophy.md
[workflow-core]: .claude/rules/core/workflow-core.md
[library]: .claude/rules/archetype/library.md
[application]: .claude/rules/archetype/application.md
[unity-package]: .claude/rules/archetype/unity-package.md
[unity-game]: .claude/rules/archetype/unity-game.md
[workflow-solo]: .claude/rules/overlays/workflow-solo.md
[workflow-team]: .claude/rules/overlays/workflow-team.md
[agent-review-solo]: .claude/rules/overlays/workflow-agent-review-solo.md
[agent-review-team]: .claude/rules/overlays/workflow-agent-review-team.md
[efcore]: .claude/rules/overlays/persistence-efcore.md
[dapper]: .claude/rules/overlays/persistence-dapper.md
[mvc]: .claude/rules/overlays/frontend-mvc.md
[blazor]: .claude/rules/overlays/frontend-blazor.md
[clean]: .claude/rules/overlays/architecture-clean.md
[vertical-slice]: .claude/rules/overlays/architecture-vertical-slice.md
[modular-monolith]: .claude/rules/overlays/architecture-modular-monolith.md
[microservices]: .claude/rules/overlays/architecture-microservices.md
[areas]: .claude/rules/overlays/architecture-areas.md
[domain-model]: .claude/rules/overlays/design-domain-model.md
[cqrs]: .claude/rules/overlays/design-cqrs.md
[event-sourcing]: .claude/rules/overlays/design-event-sourcing.md
[event-driven]: .claude/rules/overlays/design-event-driven.md
[unity-engine]: .claude/rules/overlays/unity-engine.md
[benchmarks]: .claude/rules/overlays/benchmarks.md

## Using the rules in your repo

Claude Code loads a repository's root `CLAUDE.md` into context; the rules become
active when that `CLAUDE.md` imports a profile.

**Option A — submodule** (single source of truth, zero drift). Add this repo
under `.claude/rules-src/`, then in your root `CLAUDE.md`:

```markdown
## Conventions
@.claude/rules-src/.claude/rules/profiles/application-solo.md
```

**Option B — copy** (self-contained). Copy the profile and every module it
imports into your repo, then import the profile from your `CLAUDE.md`:

```powershell
./tools/sync.ps1 -Target C:\path\to\your-repo -Profile application-solo
```

Each sync stamps the source commit and the set's composition — profile, posture,
added overlays — into `.claude/rules/.sync-source`; commit it with the copied
files. Re-run with `-Check` to audit a repo for drift instead of overwriting it
— it reads the set from the stamp, flags as `EXTRA` any module the set no longer
contains, and lists the commits since the stamped one that touched a file the
repo carries or should carry:

```powershell
./tools/sync.ps1 -Target C:\path\to\your-repo -Check
```

Need a different posture or an extra overlay? Recompose while copying — `-Workflow
solo|team` swaps the posture, `-Add <overlay>` appends an opt-in one. A recomposed
set matches no profile, so the modules are copied without a profile manifest and
the `@import` lines to paste are printed for you:

```powershell
./tools/sync.ps1 -Target C:\path\to\your-repo -Profile application-solo -Workflow team
```

The stamp records the recomposition too, so `-Check` still needs only
`-Target`; flags passed with it must describe the stamped set, or it reports the
mismatch and stops. A repo whose stamp holds only a commit, or that has no
stamp, records no composition: audit it with the `-Profile`, `-Workflow`, and
`-Add` it was synced with.

Either way, for SDK-style projects also copy
[`examples/application/.editorconfig`](examples/application/.editorconfig) to
your solution root and set
`<EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>` so the coding
standards are enforced by tooling, not just prose. Code the Unity Editor
compiles is gated by `csc.rsp` and analyzers instead — see
[`overlays/unity-engine.md`](.claude/rules/overlays/unity-engine.md).

### Project-specific rules

Narrow invariants that apply to one area of one repo (a parser's AST contract, a
geometry kernel's epsilon) don't belong in the shared set. Author them in your
own repo from
[`templates/path-scoped-rule.md`](.claude/rules/templates/path-scoped-rule.md),
which uses YAML `paths:` frontmatter so the rule activates only when a matching
file is touched.

## Examples

[`examples/application/`](examples/application/) is a tiny ASP.NET Core minimal
API + EF Core (Npgsql) service, `Contoso.Orders`, demonstrating the
`application-solo` profile and the EF Core overlay. Its
[`README.md`](examples/application/README.md) is a guided tour of which file
demonstrates which rule.

```sh
cd examples/application
dotnet build
dotnet test
```

It needs SDK 11 (which carries the .NET and ASP.NET Core 11 runtimes) and the
.NET and ASP.NET Core 10 runtimes, and `dotnet test` needs a running Docker
engine: the example's integration tests start Postgres with Testcontainers.

[`examples/library/`](examples/library/) is a small RFC 4180 CSV reader,
`Contoso.Csv`, demonstrating the `library-team` profile: a documented public
API, the full target-framework matrix, `dotnet pack`, and benchmarks. Its
[`README.md`](examples/library/README.md) is the guided tour.

```sh
cd examples/library
dotnet build
dotnet test
```

It needs SDK 11 and the .NET 10 and 11 runtimes, one per target framework,
but no Docker.

There is no `src/` or `test/` at the repository root — this repo ships rules
only; example code lives under `examples/`.

## License

[MIT](LICENSE)
