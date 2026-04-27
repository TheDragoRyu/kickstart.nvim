# UnityAnalyzer

Custom Roslyn analyzer used by this Neovim config to surface Unity-relevant C# issues — starting with closure allocations. The DLL is built locally per machine, never committed into Unity projects, and wired into them via the `unity-setup` skill.

## Build

```powershell
pwsh ./build.ps1
```

```sh
./build.sh
```

Both scripts:

1. Run `dotnet build -c Release` on `UnityAnalyzer/UnityAnalyzer.csproj`.
2. Copy `UnityAnalyzer.dll` to a per-user cache:
   - Windows: `%LOCALAPPDATA%\nvim-roslyn-analyzers\UnityAnalyzer.dll`
   - Unix: `${XDG_DATA_HOME:-$HOME/.local/share}/nvim-roslyn-analyzers/UnityAnalyzer.dll`

The `unity-setup` skill points each Unity project's `Directory.Build.props` at this cached DLL.

## Per-project config — `unity-analyzer.config`

The skill drops a `unity-analyzer.config` at each Unity project root. Format:

```
# Lines starting with # are comments.
UA0001 = enabled
```

Set a rule to `disabled` to mute it for that project only. Future per-rule options can be added as `UA####.<key> = <value>` lines without breaking existing entries.

If the file is missing, all rules are enabled by default.

## Diagnostics

| ID     | Title                  | Severity | Description                                                                 |
|--------|------------------------|----------|-----------------------------------------------------------------------------|
| UA0001 | Closure allocation     | Warning  | Lambda or anonymous method captures a variable; a display class is allocated. Use a `static` lambda or refactor to remove the capture. |

`static` lambdas (`static () => ...`) are intentionally not flagged — they cannot capture.

## Adding a rule

1. Add a new ID constant in `UnityAnalyzer/DiagnosticIds.cs` (next free `UA####`).
2. Add a new analyzer file under `UnityAnalyzer/Rules/`. Pattern:
   - `[DiagnosticAnalyzer(LanguageNames.CSharp)]`
   - In `Initialize`, call `RegisterCompilationStartAction` and gate on `UnityAnalyzerConfig.Load(start.Options).IsEnabled(...)`.
3. Append the new ID to `UnityAnalyzer/AnalyzerReleases.Unshipped.md` (and shift to `Shipped.md` on the next release).
4. Run `build.ps1` / `build.sh`.
5. On Unity projects already set up, add `UA#### = enabled` to their `unity-analyzer.config`.

## Layout

```
analyzers/
├── README.md
├── build.ps1
├── build.sh
└── UnityAnalyzer/
    ├── UnityAnalyzer.csproj
    ├── DiagnosticIds.cs
    ├── AnalyzerReleases.Shipped.md
    ├── AnalyzerReleases.Unshipped.md
    ├── Configuration/
    │   ├── ConfigKeys.cs
    │   └── UnityAnalyzerConfig.cs
    └── Rules/
        └── ClosureAllocationAnalyzer.cs
```
