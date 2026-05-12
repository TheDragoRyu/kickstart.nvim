---
name: godot-nvim-setup
description: Set up a Godot 4 project so Godot opens GDScript and C# files in this Neovim config through the running Neovim server.
user_invocable: true
---

# Godot Project Setup for Neovim

The user will provide a path to a Godot project. Configure that project and the user's Godot editor settings so opening scripts from Godot routes into the running Neovim instance.

## Steps

1. **Validate the project** - Confirm the path exists and contains `project.godot`. Accept either the project root or the `project.godot` file. Abort with a clear message if validation fails.

2. **Run the setup script** - Resolve the script relative to this skill file:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .claude/skills/scripts/setup-godot-nvim.ps1 -ProjectPath "<project-path>"
   ```

   If running from outside the Neovim config root, use the absolute path to `.claude/skills/scripts/setup-godot-nvim.ps1`.

3. **Report the result** - Summarize the project root, wrapper path, Godot editor settings file, backup file, `.git/info/exclude` entry, and warnings.

## Script Behavior

- Creates or updates a project-local wrapper:
  - Windows: `.godot-nvim-open.cmd`
  - Unix-like PowerShell hosts: `.godot-nvim-open.sh`
- Updates Godot user editor settings:
  - `text_editor/external/use_external_editor = true`
  - `text_editor/external/exec_path = <wrapper>`
  - `text_editor/external/exec_flags = "\"{file}\" {line} {col}"`
  - `text_editor/behavior/files/auto_reload_scripts_on_external_change = true`
  - `dotnet/editor/external_editor = 6`
  - `dotnet/editor/custom_exec_path = <wrapper>`
  - `dotnet/editor/custom_exec_path_args = "\"{file}\" {line} {col}"`
- Backs up `editor_settings-*.tres` before editing.
- Adds the generated wrapper to `.git/info/exclude`, never `.gitignore`.
- Warns if no `.sln` or `.csproj` exists at the project root.

## Options

- `-SkipGodotSettings`: create only the wrapper.
- `-SkipDotnetSettings`: leave the Godot C# editor setting unchanged.
- `-NvimServer <addr>`: override the Neovim server address. Defaults to `\\.\pipe\nvim-unity` on Windows and `${XDG_RUNTIME_DIR:-/tmp}/nvim-unity.sock` on Unix-like hosts.
- `-NvimExe <path-or-command>`: use a specific Neovim executable.

## Important

- Neovim must already be open when Godot tries to open a file.
- Restart Godot if it was already open while the settings file changed.
- Do not overwrite user project files except the generated `.godot-nvim-open.*` wrapper.
