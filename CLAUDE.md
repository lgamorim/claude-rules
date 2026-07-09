# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is **not an application codebase** — it is a shared, opinionated set of Claude Code project rules for .NET/C# development. The rules live under `.claude/rules/` and are meant to be applied when Claude Code writes or reviews C# code, either directly in this repo or by being referenced/copied into other .NET repositories.

A small reference/demo project showing these rules applied to real code lives under `examples/sample-project/` (see "Sample project" below). This repository itself ships only rule files — there are no build, lint, or test commands for the repository's own content.

## The rules (`.claude/rules/`)

These five files are the actual content of this repository and take precedence over any default behavior:

- **`coding-standards.md`** — Microsoft C# conventions and .NET naming guidelines: PascalCase/camelCase/`_camelCase` conventions, `I`-prefixed interfaces, `Async`-suffixed async methods, one top-level type per file, file-scoped namespaces, nullable reference types enabled with no unjustified `!` suppression, XML docs on public APIs, zero-warning builds (`TreatWarningsAsErrors`).
- **`architecture.md`** — physical project/solution structure: source under `src/<ProjectName>/`, tests under `test/<ProjectName>.Tests/`, one solution file per repo or example at its root, and shared MSBuild properties centralized in a `Directory.Build.props`.
- **`design-principles.md`** — OOP/SOLID guidance: composition over inheritance, small cohesive classes, dependencies pointing inward (Application/Domain define interfaces, Infrastructure implements them), and an explicit YAGNI constraint — no speculative abstractions, no single-implementation interfaces unless required for testing/layer isolation.
- **`testing.md`** — mandatory TDD workflow (red/green/refactor): no production code without a failing test first, `Should_ExpectedOutcome_When_Scenario` naming, Arrange-Act-Assert structure, deterministic unit tests (no real I/O/clock — abstract time via `TimeProvider`), `dotnet test` run after every change.
- **`workflow.md`** — minimal, focused changes (one logical change per commit) with imperative *why*-focused messages; present both options with trade-offs when unsure between two designs; no direct commits to the default branch — changes land via squash-merged PRs from `feature/` branches (enforced with branch protection on multi-contributor repos), with a solo-project exception that waives the PR when there is no second reviewer while keeping the feature-branch and squash steps; keep the file updated as new conventions are established.

When modifying these rule files, keep them consistent with each other (e.g., a change to naming conventions in `coding-standards.md` should not contradict examples elsewhere) and update `workflow.md` itself whenever a new convention or correction is established, per its own instruction.

## Sample project

`examples/sample-project/` contains a small ASP.NET Core minimal API + EF
Core (Npgsql) sample ("Contoso.Orders") that demonstrates the five rules
above applied to a real, if tiny, codebase. Its own `CLAUDE.md` imports the
same five rule files via `@../../.claude/rules/...` and adds a handful of
project-specific notes; see `examples/sample-project/README.md` for a guided
tour of which file demonstrates which rule.

There is no `src/` or `test/` at the repo root — this repository ships rules
only; example/reference code lives under `examples/`.
