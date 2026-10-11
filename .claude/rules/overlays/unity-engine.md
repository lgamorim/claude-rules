# Overlay — Unity engine

Add when the project has C# the Unity Editor compiles — a Unity game, or the
Unity side of a package. These rules govern that code; plain .NET projects in
the same repo follow core unchanged.

- Unity 6 LTS+ APIs only; no back-compat shims. IL2CPP compatibility is a
  requirement, not a nice-to-have.
- Code reached only through reflection is marked `[Preserve]`, so managed code
  stripping keeps it; use `link.xml` only for types in assemblies you cannot
  annotate.
- Every script folder belongs to an assembly definition (`.asmdef`). Code
  referencing the `UnityEditor` namespace lives in an assembly whose only
  included platform is Editor — Editor scripts are not available in player
  builds.
- Compiler arguments — `-nullable:enable` and `-warnaserror` — live in
  `csc.rsp` at the root of the `Assets/` folder of the Unity project the repo
  builds and tests in (for a package, the project its tests run in), never in
  Player Settings' Additional Compiler Arguments, since an argument defined in
  both can cause errors. Install `Microsoft.Unity.Analyzers` in that project
  as a DLL labelled `RoslynAnalyzer`, with a `Default.ruleset` in the same
  `Assets/` root raising `UNT0007`, `UNT0008`, `UNT0023`, and `UNT0029` from
  their default `Info` to `Warning`, so the Editor compile reports its
  diagnostics and `-warnaserror` fails on them. The build gate for this code
  is a zero-warning Editor compile; core's `EnforceCodeStyleInBuild` and
  `dotnet format` gates apply to SDK-style projects only.
- A value whose type derives from `UnityEngine.Object` is null-checked with
  `== null` or `!= null`. Never `is null`, `is not null`, `?.`, `??`, or
  `??=`: they bypass Unity's overloaded equality and treat a destroyed
  object as alive. Never its implicit `bool` either: it honors destruction
  but is a second spelling of the same check. Core's pattern-matching
  preference does not extend to these checks; the analyzers flag each
  bypassing form (`UNT0007`, `UNT0008`, `UNT0023`, `UNT0029`).
- State the Inspector edits or a scene, prefab, or asset stores is a
  `[SerializeField] private` field — never a public field, and never an
  auto-property marked `[field: SerializeField]`, whose backing field the
  compiler generates and names rather than the code declaring it. A
  property, record, `readonly` or `static` field, or `Dictionary` is not
  serialized at all. Core's "prefer records / `readonly`" applies to the
  types Unity does not serialize. A serialized field is renamed only together
  with `[FormerlySerializedAs("oldName")]`. A field typed as an interface or
  abstract class whose values are `[Serializable]` plain classes carries
  `[SerializeReference]`; a field whose values derive from
  `UnityEngine.Object` — assets, components — never does, since Unity already
  serializes it as a reference.
- Records and `init` setters compile only when the assembly declares
  `System.Runtime.CompilerServices.IsExternalInit`; each assembly that uses
  them declares it once, as an `internal static class`.
- `Awake` initializes the component's own state and sets up its references,
  caching in fields the `GetComponent` results for components on its own
  GameObject; `Start` runs any setup that reads another object's state —
  every `Awake` finishes before any `Start`, and `Awake` order across objects
  is not deterministic. Subscriptions made in `OnEnable` are removed in
  `OnDisable`. Physics work — forces, Rigidbody movement — runs in
  `FixedUpdate`.
- Async methods return `Awaitable`, message methods included
  (`async Awaitable Start()`) — never `async void`. A message method keeps
  the predefined name Unity documents for it, so core's `Async` suffix does
  not apply to it. Write an `IEnumerator` coroutine only where an API other
  than `StartCoroutine` requires one: a `[UnityTest]` method, written only
  when the test yields a `UnityEngine.TestTools` instruction —
  `EnterPlayMode`, `ExitPlayMode`, `RecompileScripts`, `WaitForDomainReload`,
  or a custom `IEditModeTestYieldInstruction`; every other test that spans
  frames or waits for time is `[Test] async Task`, awaiting
  `Awaitable.NextFrameAsync` or `Awaitable.WaitForSecondsAsync` instead of
  yielding. Never await one `Awaitable` instance twice — Unity pools them.
  Work owned by a component is cancelled with `destroyCancellationToken`,
  read into a local at the top of the method.
- Logic that depends on time — elapsed or absolute — takes it as a
  parameter, read from `Time.deltaTime`, `Time.fixedDeltaTime`, or
  `Time.time` at the component boundary. This replaces core's
  `TimeProvider`, which neither of Unity's API compatibility levels
  includes.
- Code Unity runs every frame or every physics step — `Update`, `LateUpdate`,
  `FixedUpdate`, `OnGUI`, the `OnCollisionStay`/`OnTriggerStay` family, a
  coroutine body, and everything they call — allocates no managed memory: no
  LINQ, closures capturing variables, boxing, string concatenation or
  interpolation, or new arrays and collections. Physics queries fill a
  caller-owned buffer (`Physics.*NonAlloc`; the `Physics2D` overloads taking
  a results array or `List`). Objects that per-frame code creates come from
  a `UnityEngine.Pool.ObjectPool<T>`.
- Testing: EditMode tests drive core's TDD loop; behavior that needs the
  lifecycle, physics, or a loaded scene is tested in PlayMode tests, which
  play the role of `.IntegrationTests`. Core's "run `dotnet test`" means
  running both platforms through the Unity CLI
  (`-batchmode -runTests -testPlatform EditMode|PlayMode -testResults <path>`,
  without `-quit`). Async tests return `Task`, the return type the Test
  Framework documents for them. CI runs them headless (e.g. GameCI); never
  add tests that require manual interaction.
- Keep the default Force Text asset serialization and Visible Meta Files
  modes. Commit every asset together with its `.meta` file, which holds the
  ID references resolve through, and move or rename assets inside the Editor.
  Never commit `Library/`, `Temp/`, `obj/`, `Logs/`, `UserSettings/`, player
  build output, or the IDE-generated `.csproj`/`.sln` files.
- Never hand-edit a file Unity serializes as YAML (its first line is
  `%YAML`): scenes, prefabs, and other assets. Change it in the Editor or
  through an Editor script, and resolve its merge conflicts with
  UnityYAMLMerge.
