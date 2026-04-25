---
name: unity-setup
description: Set up a Unity C# project so Neovim (Roslyn LSP, treesitter, telescope) works efficiently
user_invocable: true
---

# Unity C# Project Setup for Neovim

The user will provide a path to a Unity project. Set it up so this Neovim config works efficiently with it.

## Steps

1. **Validate the project** — Confirm the path exists and contains an `Assets/` directory and `ProjectSettings/ProjectVersion.txt` (both hallmarks of a Unity project). Read `ProjectVersion.txt` to determine the Unity version. Abort with a clear message if validation fails.

2. **Determine C# language version** — Map the Unity version to the correct C# LangVersion:
   - Unity 2020.x → `8.0`
   - Unity 2021.x → `9.0`
   - Unity 2022.x → `9.0`
   - Unity 6+ (6000.x) → `9.0`
   If unsure, default to `9.0`.

3. **Create `Directory.Build.props`** — Write this file at the Unity project root (next to the `.sln`) if it does not already exist. If it exists, read it and verify it has `<LangVersion>` set; offer to update if missing.

   ```xml
   <Project>
     <PropertyGroup>
       <LangVersion>{version}</LangVersion>
       <Nullable>disable</Nullable>
     </PropertyGroup>
   </Project>
   ```

4. **Create `omnisharp.json`** — Write this file at the Unity project root if it does not already exist. If it exists, leave it alone.

   ```json
   {
     "RoslynExtensionsOptions": {
       "EnableAnalyzersSupport": true
     }
   }
   ```

5. **Create `.editorconfig`** — Only if one does not already exist. Use the standard Unity `.editorconfig` with C# conventions (tabs, indent size 4). If one exists, leave it alone.

6. **Add new files to `.git/exclude`** — Find the git repo root for the project (`git -C <path> rev-parse --show-toplevel`). For every file created in steps 3-5, add it to `.git/info/exclude` (NOT `.gitignore`). Use paths relative to the repo root. Do not add duplicates if entries already exist.

7. **Verify `.sln` exists** — Check that a `.sln` file exists at the project root. If not, warn the user that they need to open the project in Unity Editor and enable "Preferences > External Tools > Generate .csproj files" to generate it, as Roslyn LSP requires a solution file.

8. **Summary** — Print a short summary of what was created/verified and any manual steps the user still needs to take.

## Important

- NEVER modify `.gitignore` — always use `.git/info/exclude` for files this skill creates.
- NEVER overwrite existing files without asking the user first.
- All created files should be added to `.git/info/exclude` using paths relative to the git repo root.
