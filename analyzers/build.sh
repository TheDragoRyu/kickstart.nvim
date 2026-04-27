#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$SCRIPT_DIR/UnityAnalyzer/UnityAnalyzer.csproj"

dotnet build "$PROJ" -c Release

DLL="$SCRIPT_DIR/UnityAnalyzer/bin/Release/netstandard2.0/UnityAnalyzer.dll"
if [[ ! -f "$DLL" ]]; then
    echo "Build did not produce $DLL" >&2
    exit 1
fi

if [[ -n "${LOCALAPPDATA:-}" ]]; then
    CACHE_DIR="$LOCALAPPDATA/nvim-roslyn-analyzers"
else
    CACHE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim-roslyn-analyzers"
fi
mkdir -p "$CACHE_DIR"

DEST="$CACHE_DIR/UnityAnalyzer.dll"
cp -f "$DLL" "$DEST"

echo "Cached at $DEST"
