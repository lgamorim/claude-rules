# Archetype — Unity game / tooling

For Unity 6 packages and the C# libraries that feed them. Compose with the five
core rules plus `archetype/library.md` for the engine-agnostic projects.

- Unity 6.0 LTS+ APIs only; no back-compat shims. IL2CPP compatibility is a
  requirement, not a nice-to-have.
- Ship the Unity side as a UPM package under `unity/com.<org>.<package>/`; keep
  engine-agnostic logic in plain `src/` libraries with zero Unity dependencies.
- When a hot path has a native/Burst backend, keep a managed reference
  implementation as the correctness oracle; the two must agree under parity
  tests added in the same PR.
- Prefer differential/golden-corpus tests against a trusted reference over
  hand-picked assertions for geometry/asset pipelines; never weaken tolerances
  to make them pass — investigate instead.
- Editor/play-mode tests run headless in CI (e.g. GameCI); never add tests that
  require manual interaction.
