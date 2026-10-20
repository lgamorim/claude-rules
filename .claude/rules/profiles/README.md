# Profiles — archetype → modules matrix

A profile is a one-line adoption unit: a consuming repo's root `CLAUDE.md`
imports a single profile and gets the tailored subset.

| Profile | core | archetype | workflow | other overlays |
|---|---|---|---|---|
| `library-team` | all 5 | library | team | benchmarks |
| `application-solo` | all 5 | application | solo | — |
| `unity-package` | all 5 | library + unity-package | team | unity-engine, benchmarks |
| `unity-game` | all but architecture | unity-game | solo | unity-engine |

Every profile imports all of `core/`, except that a profile omits
`core/architecture.md` when its archetype states the physical layout in its
place.

Add `overlays/persistence-efcore.md` to any profile whose project uses EF Core,
or `overlays/persistence-dapper.md` when it uses Dapper; a project using both
carries both.

Add `overlays/frontend-mvc.md` when the app serves server-rendered Razor UI
(MVC and/or Razor Pages), or `overlays/frontend-blazor.md` when it renders UI
with Blazor. Both compose with `archetype/application.md`; a hybrid app may
carry both.

Add an agent-review overlay to a project that runs a separate implement agent
and review agent over each change — pick the variant matching the workflow
posture: `overlays/workflow-agent-review-team.md` has the reviewer read the PR
(**team** posture), `overlays/workflow-agent-review-solo.md` has it read the
`feature/` branch diff before the squash-merge (**solo** posture, no PR). Both
are policy only — which model runs each role is pinned in the consuming
repo, not here; `templates/reviewer-subagent.md` in this rule set's source
repository is a skeleton for the `code-reviewer` agent the overlays look for
in the consuming repo's `.claude/agents/` (copy it there and pin the model).

New repo with no code yet? Don't reach for a profile — import the core files
directly until the archetype is clear, then adopt its profile. A fresh repo is a
transient state, not a durable archetype, so it gets no profile of its own.

## Changing workflow posture

The workflow posture baked into each profile (`team` for `library-team` and
`unity-package`, `solo` for `application-solo` and `unity-game`) is a
**default for the common case, not a fixed pairing** — it reflects that
libraries and shared packages tend to be collaborative while single-deployable
apps and games often start solo. Any
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
`workflow-team.md` line — plus the matching agent-review overlay variant, if
the set includes one; nothing else changes.

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
The sync stamps the source commit into `.claude/rules/.sync-source`; commit it
with the copied files. Re-run with `-Check` to report drift, files the set no
longer contains, and the commits since the stamped one that touched a file the
target carries or should carry.

Recompose while copying with `-Workflow solo|team` (swap the posture) and
`-Add <overlay>` (append an opt-in overlay, e.g. `persistence-efcore`). Pass the
same flags to `-Check` later, or the audit compares against the wrong set.

## Path-scoped domain rules

Narrow, area-specific invariants (a parser's AST contract, a geometry kernel's
epsilon, a Unity package's API floor) do **not** belong in this shared set —
they are project-specific. Author them in the consuming repo from
`templates/path-scoped-rule.md`, which uses YAML `paths:` frontmatter so the
rule activates only when a matching file is touched.
