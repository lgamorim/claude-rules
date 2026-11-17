# Overlay — Architecture (areas)

Add when an area-scoped overlay the repo imports applies to part of the
repo and not all of it. An overlay is **area-scoped** when its file name
starts with `architecture-` or `design-`, this file excepted. Compose
with `archetype/application.md`.

- The root `CLAUDE.md` has a section headed `## Architecture areas`
  holding one table with the columns `Area`, `Paths`, and `Overlays`. Each
  row is an area: its name, the globs its files match, and the file names
  of the area-scoped overlays it follows, at least one. A glob is
  relative to the repo root; `*` matches within one path segment and `**`
  across segments.
- What an area-scoped overlay requires of an area's own files binds a
  file only when the file's row names that overlay.
- What it requires of a project outside an area — a host, the migrator,
  or any other project, in another area or in none — binds that project
  in its dealings with each area whose row names the overlay.
- No file matches the `Paths` of two rows, and every overlay a row names
  is imported.
- A file that matches no row is in no area. Core, the archetype, and the
  other overlays bind it unchanged, and an area-scoped overlay binds it
  only under its rules for projects outside an area.
- Where a module says an area follows an overlay, the area's row names
  that overlay.
- A change that adds a project matching no row first asks the maintainer
  which row it joins, which overlays a new row names, or that it stays
  outside every area. The table edit lands in the same commit as the
  project.
- The table is edited only on the maintainer's instruction: moving an
  area to another overlay is an architecture decision, never a side
  effect of a change.
