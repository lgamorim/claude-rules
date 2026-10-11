# Archetype — Unity package

For Unity 6 packages and the C# libraries that feed them. Compose with the five
core rules plus `archetype/library.md` for the engine-agnostic projects and
`overlays/unity-engine.md` for the package's Unity side.

- Ship the Unity side as a UPM package under `unity/com.<org>.<package>/`; keep
  engine-agnostic logic in plain `src/` libraries with zero Unity dependencies.
- The package's tests run in a Unity project at
  `unity/<PackageName>.TestProject/`, which references the package by local
  path — `"file:../../com.<org>.<package>"`, relative to its `Packages/`
  folder — in `Packages/manifest.json`; `csc.rsp` and the analyzer DLL live
  in its `Assets/`.
- CI builds an IL2CPP player of the test project besides running the tests,
  since the Editor compile never exercises IL2CPP.
- When a hot path has a native/Burst backend, keep a managed reference
  implementation as the correctness oracle; the two must agree under parity
  tests added in the same PR.
- Prefer differential/golden-corpus tests against a trusted reference over
  hand-picked assertions for geometry/asset pipelines; never weaken tolerances
  to make them pass — investigate instead.
