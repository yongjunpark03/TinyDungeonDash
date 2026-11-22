# Project Rules: Godot 4.7 Game Workspace

## Engine & Language Invariants
* Target engine: **Godot 4.7.2+** (`GDScript 2.0`, Compatibility renderer `gl_compatibility` for cross-platform + HTML5 Web export compatibility).
* Never use Godot 3.x APIs (e.g., use `TileMapLayer` instead of `TileMap`, `CharacterBody2D.move_and_slide()` with no arguments, `@export`, `@onready`, `instantiate()`, typed `Signal.connect()`, `await`).
* Always enforce strict static typing on variables, parameters, and return types. Use `:=` only when the right-hand side has a statically inferred type.
* Never edit `project.godot`, `override.cfg`, or `.godot/` directly via raw file writes unless explicitly approved (prefer Godot Editor or `godot-ai` MCP tools).

## File & UID Integrity (Critical)
* When moving or renaming any `.gd` or `.gdshader` file, ALWAYS move or rename its companion `.uid` sidecar file together (prefer `godot-ai` `filesystem_manage` tool).
* Never add `*.uid` or `*.import` to `.gitignore`, and never delete `.uid` or `.import` files manually.

## Verification Contract
* Before claiming any task complete, run the workspace verification script:
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools/verify.ps1`
  which executes:
  1. `gdlint` on `scripts/`, `scenes/`, and `tests/`
  2. Headless `--import` and runtime smoke check (`--quit-after 300`) checking `run.log` for `SCRIPT ERROR` or `^ERROR:`
  3. GUT headless unit tests (`addons/gut/gut_cmdln.gd`) verifying `reports/gut_results.xml` has `tests >= 1`, `failures == 0`, and `errors == 0`.
* When unsure about a Godot 4.7 API signature, query the `context7` MCP server before writing code.
