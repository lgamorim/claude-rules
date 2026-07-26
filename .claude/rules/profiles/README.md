# Profiles — archetype → modules matrix

A profile is a one-line adoption unit: a consuming repo's root `CLAUDE.md`
imports a single profile and gets the tailored subset.

| Profile | core | archetype | workflow | other overlays |
|---|---|---|---|---|
| `library-team` | all 5 | library | team | benchmarks |
| `application-solo` | all 5 | application | solo | — |
| `game-unity` | all 5 | library + game-unity | team | benchmarks |

Add `overlays/persistence-efcore.md` to any profile whose project uses EF Core.

Add `overlays/workflow-agent-review.md` to a **team**-posture project that runs a
separate implement agent and review agent over its PRs. It is policy only — the
agent/CI wiring lives in the consuming repo's automation, not here.

New repo with no code yet? Don't reach for a profile — import the core files
directly until the archetype is clear, then adopt its profile. A fresh repo is a
transient state, not a durable archetype, so it gets no profile of its own.

## Changing workflow posture

The workflow posture baked into each profile (`team` for `library-team` and
`game-unity`, `solo` for `application-solo`) is a **default for the common
case, not a fixed pairing** — it reflects that libraries and shared packages
tend to be collaborative while single-deployable apps often start solo. Any
archetype works under either posture; there is deliberately no `library-solo`
or `application-team` profile, because posture is one orthogonal line and
enumerating every combination is the fan-out the module system exists to avoid.

To run an archetype under the other posture, don't fork a profile — compose the
one line yourself in your repo's `CLAUDE.md`. For example, a solo library:

    @.../core/coding-standards.md
    @.../core/design-principles.md
    @.../core/architecture.md
    @.../core/testing-philosophy.md
    @.../core/workflow-core.md
    @.../overlays/workflow-solo.md      # solo instead of the team default
    @.../archetype/library.md
    @.../overlays/benchmarks.md

Switch postures later by swapping that single `workflow-solo.md` ⇄
`workflow-team.md` line — nothing else changes.

`tools/sync.ps1 -Workflow solo|team` copies exactly that set for you, and prints
the `@import` lines to paste. Because the result no longer matches any profile,
it ships the modules **without** a profile manifest — so import the modules
directly, not a profile.

## Adopting a profile

Option A — submodule (single source of truth, zero drift):
add this repo under `.claude/rules-src/`, then in your root `CLAUDE.md`:

    @.claude/rules-src/.claude/rules/profiles/application-solo.md

Option B — copy (self-contained): run `tools/sync.ps1 -Target <repo> -Profile
application-solo` to copy the profile and every module it imports into the
target's `.claude/rules/`, then import the profile from your `CLAUDE.md`.
Re-run with `-Check` to report drift.

Recompose while copying with `-Workflow solo|team` (swap the posture) and
`-Add <overlay>` (append an opt-in overlay, e.g. `persistence-efcore`). Pass the
same flags to `-Check` later, or the audit compares against the wrong set.

## Path-scoped domain rules

Narrow, area-specific invariants (a parser's AST contract, a geometry kernel's
epsilon, a Unity package's API floor) do **not** belong in this shared set —
they are project-specific. Author them in the consuming repo from
`templates/path-scoped-rule.md`, which uses YAML `paths:` frontmatter so the
rule activates only when a matching file is touched.
