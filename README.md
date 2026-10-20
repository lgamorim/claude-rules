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
  overlays/     orthogonal toggles: workflow posture, agent review, EF Core, Dapper, benchmarks, frontends, Unity engine
  profiles/     thin manifests composing the above (start here)
  templates/    skeletons consuming repos copy: path-scoped rules, reviewer subagent
examples/       buildable samples demonstrating a profile
tools/sync.ps1  copy a profile into a repo, or audit it for drift
tools/check.ps1 check this repo's own maintenance rules
```

## Profiles

| Profile | core | archetype | workflow | other overlays |
|---|---|---|---|---|
| [`library-team`](.claude/rules/profiles/library-team.md) | all 5 | library | team | benchmarks |
| [`application-solo`](.claude/rules/profiles/application-solo.md) | all 5 | application | solo | — |
| [`unity-package`](.claude/rules/profiles/unity-package.md) | all 5 | library + unity-package | team | unity-engine, benchmarks |
| [`unity-game`](.claude/rules/profiles/unity-game.md) | all but architecture | unity-game | solo | unity-engine |

Add [`overlays/persistence-efcore.md`](.claude/rules/overlays/persistence-efcore.md)
to any project that uses EF Core,
[`overlays/persistence-dapper.md`](.claude/rules/overlays/persistence-dapper.md)
to one that uses Dapper,
[`overlays/frontend-mvc.md`](.claude/rules/overlays/frontend-mvc.md) to one
serving server-rendered Razor UI (MVC and/or Razor Pages), and
[`overlays/frontend-blazor.md`](.claude/rules/overlays/frontend-blazor.md) to
one rendering UI with Blazor.

The workflow posture in each profile is a **default, not a fixed pairing** —
there is deliberately no `library-solo` or `application-team`, because posture is
one orthogonal line. See
[`profiles/README.md`](.claude/rules/profiles/README.md) for how to swap it.

## The modules

| Module | What it covers |
|--------|----------------|
| [`core/coding-standards.md`](.claude/rules/core/coding-standards.md) | Microsoft C# conventions and .NET naming: PascalCase/camelCase/`_camelCase`, `I`-prefixed interfaces, `Async` suffixes, one type per file, file-scoped namespaces, nullable enabled, XML docs on public APIs, zero-warning builds. Codified in an `.editorconfig` so `dotnet format` and the build enforce them. |
| [`core/design-principles.md`](.claude/rules/core/design-principles.md) | OOP/SOLID guidance: composition over inheritance, dependencies pointing inward, patterns only when they earn their keep, and an explicit YAGNI constraint. |
| [`core/architecture.md`](.claude/rules/core/architecture.md) | The default physical skeleton: source under `src/<ProjectName>/`, tests under `test/`, one solution file at the root, shared MSBuild properties in `Directory.Build.props`. A profile whose archetype states its own layout omits it. |
| [`core/testing-philosophy.md`](.claude/rules/core/testing-philosophy.md) | Mandatory red/green/refactor TDD, `Should_ExpectedOutcome_When_Scenario` naming, Arrange-Act-Assert, deterministic tests (no real I/O or clock — abstract time via `TimeProvider`). |
| [`core/workflow-core.md`](.claude/rules/core/workflow-core.md) | Minimal focused changes, imperative *why*-focused commits, feature branches merged by squash, no direct commits to the default branch. |
| [`archetype/library.md`](.claude/rules/archetype/library.md) | Shipped packages: `dotnet pack` in CI from day one, multi-TFM matrix, public API as a semver contract, `.UnitTests`/`.IntegrationTests` split. |
| [`archetype/application.md`](.claude/rules/archetype/application.md) | Single deployables: `.UnitTests`, no packing, config from `appsettings`/environment, relaxed docs at the app boundary. |
| [`archetype/unity-package.md`](.claude/rules/archetype/unity-package.md) | Unity 6 packages: UPM layout, engine-agnostic core, a managed oracle for any Burst backend, golden-corpus pipeline tests. |
| [`archetype/unity-game.md`](.claude/rules/archetype/unity-game.md) | Games shipped as a Unity player: replaces `core/architecture.md` with the `Assets/` layout and assembly names, humble components over plain-C# game rules, ScriptableObject data never written at runtime, no `Find`/singleton lookups, a player build per shipped platform in CI. |
| [`overlays/workflow-solo.md`](.claude/rules/overlays/workflow-solo.md) / [`workflow-team.md`](.claude/rules/overlays/workflow-team.md) | The PR posture: solo waives the PR mechanism but not the review — the maintainer approves the finished branch before the squash-merge (feature branch + squash still stand); team requires a reviewed PR with branch protection. |
| [`overlays/workflow-agent-review-solo.md`](.claude/rules/overlays/workflow-agent-review-solo.md) / [`workflow-agent-review-team.md`](.claude/rules/overlays/workflow-agent-review-team.md) | An implement/review contract between two agents that never share a context: solo has the reviewer read the `feature/` branch diff before the squash-merge, team has it read the PR. Policy only — the reviewer runs from a definition in the consuming repo's `.claude/agents/`, for which [`templates/reviewer-subagent.md`](.claude/rules/templates/reviewer-subagent.md) is the skeleton, or as a fresh in-session subagent. |
| [`overlays/persistence-efcore.md`](.claude/rules/overlays/persistence-efcore.md) | The ORM exception to "prefer records", mapping in `OnModelCreating`, migrations, real-engine integration tests. |
| [`overlays/unity-engine.md`](.claude/rules/overlays/unity-engine.md) | C# the Unity Editor compiles: IL2CPP and stripping, assembly definitions, `csc.rsp` compiler settings, Unity-safe null checks, serialized fields, lifecycle and `Awaitable`, allocation-free per-frame code, EditMode/PlayMode tests through the Unity CLI, `.meta` and YAML asset hygiene. |
| [`overlays/persistence-dapper.md`](.claude/rules/overlays/persistence-dapper.md) | Positional records bound through the constructor, explicit column lists, parameters only, `CommandDefinition` cancellation, a unit of work as one repository method under one `DbTransaction`, DbUp migrations, integration tests against the production engine. |
| [`overlays/benchmarks.md`](.claude/rules/overlays/benchmarks.md) | BenchmarkDotNet under `bench/`, built by CI but never run there, baselines produced locally. |
| [`overlays/frontend-mvc.md`](.claude/rules/overlays/frontend-mvc.md) | Server-rendered Razor UI: Razor Pages by default, thin controllers/handlers, view models never domain entities, tag helpers, Post/Redirect/Get, global antiforgery, markup tested at the boundary via `WebApplicationFactory`. |
| [`overlays/frontend-blazor.md`](.claude/rules/overlays/frontend-blazor.md) | Blazor Web App across all render modes: static SSR by default, per-mode DI-lifetime and state rules, prerender double-execution, JS interop timing, disposal, bUnit-first testing. |

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

Each sync stamps the source commit into `.claude/rules/.sync-source`; commit it
with the copied files. Re-run with `-Check` to audit a repo for drift instead of
overwriting it — it also flags as `EXTRA` any module the set no longer contains,
and lists the commits since the stamped one that touched a file the repo carries
or should carry:

```powershell
./tools/sync.ps1 -Target C:\path\to\your-repo -Profile application-solo -Check
```

Need a different posture or an extra overlay? Recompose while copying — `-Workflow
solo|team` swaps the posture, `-Add <overlay>` appends an opt-in one. A recomposed
set matches no profile, so the modules are copied without a profile manifest and
the `@import` lines to paste are printed for you:

```powershell
./tools/sync.ps1 -Target C:\path\to\your-repo -Profile application-solo -Workflow team
```

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

## Example

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

There is no `src/` or `test/` at the repository root — this repo ships rules
only; example code lives under `examples/`.

## License

[MIT](LICENSE)
