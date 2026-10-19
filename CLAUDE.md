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
rule files and two scripts — there is no build or test command for the
repository's own content; `tools/check.ps1` is its one lint command.

## Structure

The rules are **composable modules**, not one monolithic set, because projects of
different scope need different subsets — even within the same tech stack:

- **`core/`** (5 files) — every profile imports all of them, except that a
  profile omits `architecture.md` when its archetype states the physical
  layout in its place. `coding-standards.md`, `design-principles.md`,
  `architecture.md`, `testing-philosophy.md`, `workflow-core.md`.
- **`archetype/`** — pick exactly one per project: `library.md`,
  `application.md`, `unity-package.md`, `unity-game.md`.
- **`overlays/`** — orthogonal toggles: `workflow-solo.md` / `workflow-team.md`
  (mutually exclusive; every project needs one),
  `workflow-agent-review-solo.md` / `workflow-agent-review-team.md` (mutually
  exclusive opt-ins matched to the workflow posture), `persistence-efcore.md`,
  `persistence-dapper.md`, `benchmarks.md`, `frontend-mvc.md`,
  `frontend-blazor.md`, `unity-engine.md`.
- **`profiles/`** — thin manifests that `@import` a tailored subset. A consuming
  repo imports **one profile** and gets everything it needs.
- **`templates/`** — skeletons a consuming repo copies and fills in:
  `path-scoped-rule.md` for project-specific rules with YAML `paths:`
  frontmatter, `reviewer-subagent.md` for the reviewer agent behind the
  agent-review overlays.

`tools/sync.ps1` copies a profile and its modules into a target repo, or audits
one for drift with `-Check`. `tools/check.ps1` checks this repository itself:
profile and example imports resolve, no module is dead weight, the lines a
branch adds meet the hygiene rule, and the profile tables in `README.md` and
`profiles/README.md` agree. It prints `file:line` for each failure and exits
non-zero. `.github/workflows/check.yml` runs it on every push, alongside the
example's build, tests, and `dotnet format --verify-no-changes`.

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
  that toggles on a condition the agent cannot observe in its context — team
  size, lifecycle phase — must be its own module, selected by a profile or
  added as an opt-in overlay; that is why `workflow-solo`/`workflow-team`
  are separate files. A condition it can observe — which modules are
  imported, a type's shape — may stay in prose. Only split a module when a
  real profile needs the halves apart.
- **Rule prose two agents would follow differently is a defect**, not a
  style preference: a hedge, an undefined term, or a choice with no stated
  selector is a finding.
- **A claim about how a library, framework, or runtime behaves is verified
  against the release the commit message names**, never taken from memory
  or from the handoff.
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
  a new convention or correction is established for consuming projects, per
  its own instruction. A convention that binds only this repository's own
  maintenance — how its rule changes are committed, verified, and reviewed —
  lives in this section instead.
- **This repo runs `overlays/workflow-agent-review-solo.md` on itself.** Rule
  prose is this repo's production code, so changes get the same two-role flow:
  implement on a `feature/` branch and end with a handoff summary (intent,
  checks done, deliberate deviations); an independent reviewer — a fresh
  context with none of the implementer's state beyond the handoff summary —
  reviews the branch diff against `master` before the merge, judging it
  against the imported modules and the rules in this section, which this
  repo adds to the overlay's rule set, so a finding may cite either. The
  maintainer adjudicates the findings, accepted ones land as new commits on
  the branch from an implementer context — one commit per accepted finding,
  in the order the maintainer relays them, so any one can be reverted alone;
  a fix that closes several findings is one commit naming each, placed at
  the first of them in that order — and the squash-merge happens only on
  the maintainer's explicit approval.
- **A review reports a finding only in one of five categories**, each
  citing the rule it violates: a contradiction, naming both locations;
  divergent outputs, naming the two concrete outputs two agents would
  produce — "could be read two ways" alone is not a finding; a false claim
  about a library, framework, runtime, or tool, where a claim naming no
  release or one the reviewer could not check is reported as unverified;
  a breach of any other rule the review judges against; or hygiene. It
  does not re-raise an item the maintainer lists as already adjudicated,
  and it ends with what it verified, in at most five lines.
- **Hygiene:** every line a change's diff adds to a Markdown file is at
  most 80 characters, excluding its line ending, unless it is a table row;
  no line a change's diff adds to any file ends in whitespace; commit
  messages follow `core/workflow-core.md`.
- **The implementer runs `tools/check.ps1` on the committed branch before
  the handoff summary**, and lists the run among the checks done. Every
  failure it prints is fixed or named in the summary as a deliberate
  deviation.
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
