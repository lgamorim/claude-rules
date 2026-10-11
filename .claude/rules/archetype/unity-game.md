# Archetype — Unity game

For a game built and shipped as a Unity player. Compose with the core rules
except `core/architecture.md`, which this archetype replaces — never import
both — plus `overlays/unity-engine.md`.

Structure (replaces `core/architecture.md`)
- The Unity project is the repository root: `Assets/`, `Packages/`, and
  `ProjectSettings/` sit beside the root `CLAUDE.md`.
- Game code lives under `Assets/<GameName>/Scripts/Runtime/` (assembly
  `<GameName>`) and `Assets/<GameName>/Scripts/Editor/` (assembly
  `<GameName>.Editor`); tests under `Assets/<GameName>/Tests/EditMode/`
  (`<GameName>.EditModeTests`) and `Assets/<GameName>/Tests/PlayMode/`
  (`<GameName>.PlayModeTests`).
- Third-party content imported into `Assets/` keeps its own top-level folder
  and is never edited in place.
- Every binary file under `Assets/` — textures, audio, models, video, fonts,
  plugin DLLs — is tracked by Git LFS through `.gitattributes`.
- No `dotnet pack` — the deliverable is the player build.

Conventions
- The game is the boundary, not a consumed API: XML docs are required only
  where intent isn't obvious from the code (core's public-API-docs rule
  relaxes here).
- Components are humble: game rules live in plain C# classes that depend on
  no `UnityEngine.Object` type, so EditMode tests cover them directly; a
  component reads input and Unity state, calls that logic, and applies the
  result.
- Designer-tunable data — stats, balance values, spawn tables — lives in
  ScriptableObject assets, the game's counterpart of `appsettings*.json`.
  Code never writes to a ScriptableObject asset at runtime: in the Editor a
  Play-mode write can be saved into the asset, and a player cannot save it at
  all. Runtime state lives in plain objects.
- A component reaches a component on its own GameObject with `GetComponent`,
  cached in `Awake`. It reaches another GameObject, or a component on one,
  through a serialized field assigned in the Editor or a reference passed by
  whatever creates it — never a method of `GameObject` or
  `UnityEngine.Object` whose name starts with `Find`, never a `GetComponent`
  method whose name ends in `InChildren` or `InParent`, never a `Transform`
  member that yields another `Transform` (`Find`, `GetChild`, `parent`,
  `root`, or enumerating its children), and never a static field holding
  an instance.
- Nothing in a player build is secret: no keys, credentials, or tokens in
  code, assets, or `StreamingAssets/`.

Testing
- Core's red/green/refactor binds code. Asset data — scene layout, art,
  animation curves, material values, ScriptableObject tuning numbers — has
  no test-first step.
- CI builds a player for every platform the game ships on, besides running
  the tests: the Editor runs scripts on Mono and managed code stripping
  happens only when a player is built, so IL2CPP and stripping failures
  surface only there.
