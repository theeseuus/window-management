#!/usr/bin/env bash
set -euo pipefail

validation_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
validation_runner="$validation_root/tests/run.lua"

if [[ -n "${VALIDATION_LUA_BIN:-}" ]]; then
  "$VALIDATION_LUA_BIN" "$validation_runner"
elif command -v lua >/dev/null 2>&1; then
  lua "$validation_runner"
elif command -v mise >/dev/null 2>&1; then
  mise exec -- lua "$validation_runner"
else
  echo "No Lua runtime found. Run 'mise install' or set VALIDATION_LUA_BIN." >&2
  exit 1
fi
