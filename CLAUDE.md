# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is **not an application codebase** — it is a shared, opinionated set of
Claude Code project rules for .NET/C# development. The rules live under
`.claude/rules/` and are meant to be applied when Claude Code writes or reviews
C# code, either directly in this repo or by being referenced/copied into other
.NET repositories.

A reference project showing these rules applied to real code lives under
`examples/application/` (see "Example" below). This repository itself ships only
rule files and a sync script — there are no build, lint, or test commands for the
repository's own content.

## Structure

The rules are **composable modules**, not one monolithic set, because projects of
different scope need different subsets — even within the same tech stack:

- **`core/`** (5 files) — archetype-invariant; every profile imports all of them.
  `coding-standards.md`, `design-principles.md`, `architecture.md`,
  `testing-philosophy.md`, `workflow-core.md`.
- **`archetype/`** — pick exactly one per project: `library.md`,
  `application.md`, `game-unity.md`.
- **`overlays/`** — orthogonal toggles: `workflow-solo.md` / `workflow-team.md`
  (mutually exclusive; every project needs one), `persistence-efcore.md`,
  `benchmarks.md`.
- **`profiles/`** — thin manifests that `@import` a tailored subset. A consuming
  repo imports **one profile** and gets everything it needs.
- **`templates/`** — `path-scoped-rule.md`, the skeleton for project-specific
  rules that use YAML `paths:` frontmatter.

`tools/sync.ps1` copies a profile and its modules into a target repo, or audits
one for drift with `-Check`.

## Rules for working on this repository

- **Portable files name no external project.** Everything under `core/`,
  `archetype/`, `overlays/`, `profiles/`, and `templates/` gets copied or
  imported into other repositories, so it must be project-neutral: describe
  *kinds* of projects (library, application, Unity package) and generic tooling
  (BenchmarkDotNet, EF Core, Testcontainers), never a specific repo name. The
  concrete repo→profile mapping belongs only in `README.md`, which never leaves
  this repo.
- **Graduate by file, not by conditional.** Claude treats all imported prose as
  active, so it cannot skip an "if solo…" paragraph in a team project. Anything
  that toggles per project must be its own small module selected by a profile —
  that is why `workflow-solo`/`workflow-team` are separate files. Only split a
  module when a real profile needs the halves apart.
- **Don't add speculative profiles.** Profiles map to durable archetypes, not to
  lifecycle phases or every archetype×posture combination. There is deliberately
  no `scaffold`, `library-solo`, or `application-team` profile; posture is one
  orthogonal line a consumer can swap. This is the same YAGNI constraint
  `design-principles.md` imposes on production code.
- **Keep the modules mutually consistent.** A change to naming conventions in
  `core/coding-standards.md` must not contradict examples elsewhere. Every
  module must either be imported by at least one profile or be documented in
  `profiles/README.md` as an opt-in overlay a consumer adds directly (as
  `persistence-efcore.md` is) — otherwise it is dead weight.
- **Update `core/workflow-core.md`** (or the relevant workflow overlay) whenever
  a new convention or correction is established, per its own instruction.
- When changing a rule that consuming repos already copied, expect drift: run
  `tools/sync.ps1 -Check` against those repos rather than assuming they match.

## Example

`examples/application/` contains a small ASP.NET Core minimal API + EF Core
(Npgsql) sample ("Contoso.Orders") demonstrating the `application-solo` profile
plus the `persistence-efcore` overlay. Its own `CLAUDE.md` imports the profile
via `@../../.claude/rules/profiles/application-solo.md` and adds
project-specific notes; see `examples/application/README.md` for a guided tour of
which file demonstrates which rule.

Build and test it with `dotnet build` / `dotnet test` from that directory. There
is no `src/` or `test/` at the repo root — this repository ships rules only;
example/reference code lives under `examples/`.
