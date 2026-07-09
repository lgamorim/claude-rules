# claude-rules

Opinionated [Claude Code](https://claude.com/claude-code) rules for .NET and C#
with conventions, architecture guidance, and guardrails for idiomatic,
production-ready code.

## What this is

This repository is **not an application** — it is a shared, reusable set of
project rules that tell Claude Code how to write and review C# the way you'd
want it written: Microsoft conventions, a sane project layout, SOLID without
overengineering, and test-driven development. The rules live as plain Markdown
under [`.claude/rules/`](.claude/rules/) and are meant to be referenced or
copied into your own .NET repositories.

A small, buildable sample under [`examples/sample-project/`](examples/sample-project/)
shows every rule applied to real code.

## The rules

| File | What it covers |
|------|----------------|
| [`architecture.md`](.claude/rules/architecture.md) | Physical layout: source under `src/<ProjectName>/`, tests under `test/<ProjectName>.Tests/`, one solution file at the root, shared MSBuild properties centralized in `Directory.Build.props`. |
| [`coding-standards.md`](.claude/rules/coding-standards.md) | Microsoft C# conventions and .NET naming: PascalCase/camelCase/`_camelCase`, `I`-prefixed interfaces, `Async` suffixes, one type per file, file-scoped namespaces, nullable enabled, XML docs on public APIs, zero-warning builds. Codified in an `.editorconfig` so `dotnet format` and the build enforce them. |
| [`design-principles.md`](.claude/rules/design-principles.md) | OOP/SOLID guidance: composition over inheritance, dependencies pointing inward, patterns only when they earn their keep, and an explicit YAGNI constraint — no speculative abstractions or single-implementation interfaces. |
| [`testing.md`](.claude/rules/testing.md) | Mandatory red/green/refactor TDD, `Should_ExpectedOutcome_When_Scenario` naming, Arrange-Act-Assert, deterministic tests (no real I/O or clock — abstract time via `TimeProvider`), `dotnet test` after every change. |
| [`workflow.md`](.claude/rules/workflow.md) | Minimal focused changes, imperative *why*-focused commits, feature branches merged by squash (with a solo-project exception that waives the PR), and no direct commits to the default branch. |

## Using the rules in your repo

Claude Code automatically loads a repository's root `CLAUDE.md` into context;
the rule files become active when that `CLAUDE.md` imports them. To adopt these
rules:

1. Copy the [`.claude/rules/`](.claude/rules/) directory into your repository.
2. Reference the rules from your own `CLAUDE.md` using Claude Code's `@` import
   syntax, so a fresh session always has them in context:

   ```markdown
   ## Conventions
   @.claude/rules/coding-standards.md
   @.claude/rules/architecture.md
   @.claude/rules/design-principles.md
   @.claude/rules/testing.md
   @.claude/rules/workflow.md
   ```

3. Copy [`examples/sample-project/.editorconfig`](examples/sample-project/.editorconfig)
   to your solution root and set `<EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>`
   so the coding standards are enforced by tooling, not just prose.

The sample project's [`CLAUDE.md`](examples/sample-project/CLAUDE.md) is a
working example of exactly this — it imports all five rule files via
`@../../.claude/rules/...` and adds a few project-specific notes.

## Repository layout

```
.claude/rules/          the five rule files — the actual content of this repo
CLAUDE.md               guidance for Claude Code working in this repo
examples/sample-project/  a buildable Contoso.Orders API demonstrating the rules
```

There is no `src/` or `test/` at the repository root — this repo ships rules
only; example code lives under `examples/`.

## Sample project

[`examples/sample-project/`](examples/sample-project/) is a tiny ASP.NET Core
minimal API + EF Core (Npgsql) service, `Contoso.Orders`, that exists so each
rule can be seen in action rather than just read. Its
[`README.md`](examples/sample-project/README.md) is a guided tour of which file
demonstrates which rule. To build and test it:

```sh
cd examples/sample-project
dotnet build
dotnet test
```

## License

[MIT](LICENSE)
