---
name: unity-setup
description: Set up a Unity C# project so Neovim (Roslyn LSP, treesitter, telescope) works efficiently, including the local UnityAnalyzer Roslyn analyzer.
user_invocable: true
---

# Unity C# Project Setup for Neovim

The user will provide a path to a Unity project. Set it up so this Neovim config works efficiently with it, and wire in the local `UnityAnalyzer` Roslyn analyzer for closure-allocation and other Unity-specific checks.

## Steps

1. **Validate the project** — Confirm the path exists and contains an `Assets/` directory and `ProjectSettings/ProjectVersion.txt` (both hallmarks of a Unity project). Read `ProjectVersion.txt` to determine the Unity version. Abort with a clear message if validation fails.

2. **Determine C# language version** — Map the Unity version to the correct C# LangVersion:
   - Unity 2020.x → `8.0`
   - Unity 2021.x → `9.0`
   - Unity 2022.x → `9.0`
   - Unity 6+ (6000.x) → `9.0`
   If unsure, default to `9.0`.

3. **Resolve the UnityAnalyzer cache path** — Per platform:
   - Windows: `%LOCALAPPDATA%\nvim-roslyn-analyzers\UnityAnalyzer.dll`
   - Unix: `${XDG_DATA_HOME:-$HOME/.local/share}/nvim-roslyn-analyzers/UnityAnalyzer.dll`

   Locate the analyzer source dir at `<nvim-config>/analyzers/UnityAnalyzer/`. Build/refresh the DLL when:
   - the cache path does not exist, OR
   - any `.cs` file under `<nvim-config>/analyzers/UnityAnalyzer/` has a newer mtime than the cached DLL.

   To build, run from `<nvim-config>/analyzers/`:
   - Windows: `pwsh ./build.ps1`
   - Unix: `./build.sh`

   Both scripts run `dotnet build -c Release` and copy the resulting DLL into the cache path. After build, verify the DLL exists. Capture the absolute cache path for step 4.

4. **Create `Directory.Build.props`** — Write at the Unity project root (next to the `.sln`) if it does not already exist:

   ```xml
   <Project>
     <PropertyGroup>
       <LangVersion>{version}</LangVersion>
       <Nullable>disable</Nullable>
     </PropertyGroup>
     <ItemGroup>
       <Analyzer Include="{absolute-path-to-cached-UnityAnalyzer.dll}" />
       <AdditionalFiles Include="$(MSBuildThisFileDirectory)unity-analyzer.config" />
     </ItemGroup>
   </Project>
   ```

   If the file already exists:
   - Verify `<LangVersion>` is set; offer to add it if missing.
   - Verify the `<Analyzer Include="...UnityAnalyzer.dll" />` line is present (compare on filename suffix `UnityAnalyzer.dll`); if not, append into an existing `<ItemGroup>` or add a new one.
   - Verify `<AdditionalFiles Include="...unity-analyzer.config" />` is present; if not, append.
   - All edits must be idempotent. Never overwrite a hand-edited file silently.

5. **Create `omnisharp.json`** — Write this file at the Unity project root if it does not already exist. If it exists, leave it alone.

   ```json
   {
     "RoslynExtensionsOptions": {
       "EnableAnalyzersSupport": true
     }
   }
   ```

6. **Create `.editorconfig`** — Only if one does not already exist. Use the standard Unity `.editorconfig` with C# conventions (tabs, indent size 4). If one exists, leave it alone. Do not write any `dotnet_diagnostic.UA####` lines — UA rule on/off is governed by `unity-analyzer.config` (step 7), not `.editorconfig`. The user can still add a `dotnet_diagnostic.UA####.severity = ...` line manually to override severity per project.

7. **Create `unity-analyzer.config`** — Write at the Unity project root if it does not already exist:

   ```
   # Unity Analyzer rule configuration.
   # Format: <RuleId> = enabled | disabled
   # Lines starting with # are comments.

   UA0001 = enabled
   ```

   If the file already exists, parse its existing keys. For every shipped rule (currently just `UA0001`) that is missing, append a new `<RuleId> = enabled` line at the end. Do not modify lines that are already present — the user may have set them to `disabled`.

   Shipped rule list, for reference (keep in sync with `<nvim-config>/analyzers/UnityAnalyzer/AnalyzerReleases.Shipped.md`):
   - `UA0001` — closure allocation

8. **Add new files to `.git/info/exclude`** — Find the git repo root for the project (`git -C <path> rev-parse --show-toplevel`). For every file the skill creates or maintains in steps 4-7, ensure an entry exists in `.git/info/exclude` (NOT `.gitignore`). Use paths relative to the repo root. The full list is:

   - `Directory.Build.props`
   - `omnisharp.json`
   - `.editorconfig` (only if this skill created it)
   - `unity-analyzer.config`

   Skip duplicates. Never modify `.gitignore`.

9. **Verify `.sln` exists** — Check that a `.sln` file exists at the project root. If not, warn the user that they need to open the project in Unity Editor and enable "Preferences > External Tools > Generate .csproj files" to generate it, as Roslyn LSP requires a solution file.

10. **Summary** — Print a short summary of:
    - Whether the analyzer DLL was rebuilt or already cached, and the cache path used.
    - Which files were created vs. left untouched.
    - Which entries were appended to `.git/info/exclude`.
    - Any manual steps remaining (e.g. regenerate `.csproj` from Unity Editor, `:LspRestart` in nvim).

## Important

- NEVER modify `.gitignore` — always use `.git/info/exclude` for files this skill creates.
- NEVER overwrite existing files without asking the user first.
- The cached `UnityAnalyzer.dll` lives outside any repo — do not add it to `.git/info/exclude` and do not place it under `Assets/`.
- All created files in the Unity project should be added to `.git/info/exclude` using paths relative to the git repo root.
- UA rule on/off lives in `unity-analyzer.config` (step 7), not `.editorconfig`. Severity is owned by the analyzer (Warning by default) and can be overridden in `.editorconfig` by the user manually if needed.
