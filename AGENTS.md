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

## Architecture & Maintainability (SOLID in Godot 4.7)
* **S — Single Responsibility Principle (SRP)**: Keep each script focused on a single cohesive responsibility. Isolate pure domain logic into `RefCounted` classes (e.g., `WaveDirector`, `UpgradeManager`, `BenchmarkMetrics`) separate from `Node`/UI glue so logic is fast and trivial to test in GUT.
* **O — Open/Closed Principle (OCP)**: Extend gameplay via `Resource` data assets (`EnemyData`, `PlayerStats`), modular child components, and `Callable` hooks rather than growing `if/elif` chains inside core controllers.
* **L — Liskov Substitution Principle (LSP)**: Any pooled or polymorphic entity (`SlashProjectile`, `MagicOrb`, `XpGem`, `StressEntity`) must uphold its base lifecycle contract—cleanly resetting all transient state on `activate()` and disabling cleanly on `release()`.
* **I — Interface Segregation Principle (ISP)**: Prefer narrow typed `Signal`s, `Callable` callbacks, and focused component scripts over monolithic god-classes or deep inheritance hierarchies.
* **D — Dependency Inversion Principle (DIP)**: Follow **"Call Down, Signal Up"**. Inject dependencies via `@export`, `setup(...)`, or `Callable` callbacks instead of hardcoding `/root/...` node paths inside leaf scripts.
* **Pragmatic Balance (SOLID + DoD)**: Apply SOLID OOP/Composition across gameplay, UI, and systems; drop down to Data-Oriented SoA (`Packed*Array` + `MultiMeshInstance2D`) inside encapsulated modules only for measured hot loops.

## Reusable Optimization Toolkit (On-Demand Reference)
* `scripts/perf_overlay.gd` (`PerfOverlay`): `F3` global profiler displaying rolling Avg/P95 ms, sparkline graph, Draw Calls, and SceneTree Node count.
* `scripts/node_pool.gd` (`NodePool`): Zero-churn object pool for high-frequency spawns/despawns (`2.61x` faster than `new()`/`free()`).
* `shaders/dissolve.gdshader`: WebGL 2.0 / `gl_compatibility`-safe shared-material vertex-color batching (`self_modulate` channels replace per-instance `ShaderMaterial` copies).
* `scripts/spatial_grid_2d.gd` (`SpatialGrid2D`): Zero-per-frame-allocation uniform spatial hash grid for $O(N)$ radius queries and Chebyshev-ring early-exit `find_nearest_node2d()` (`98.48%` pair-check reduction at 2,000 entities).
* `scripts/swarm_multimesh_2d.gd` (`SwarmMultiMesh2D`) & `scripts/multimesh_burst_2d.gd` (`MultiMeshBurst2D`): 1-Draw-Call `MultiMeshInstance2D` + SoA `PackedVector2Array` + 12-float `multimesh.buffer` bulk upload (`y.y = -scale` for upright 2D `QuadMesh`; scales to 10,000 entities with 0 child nodes).
* `tools/benchmark.ps1` + `scripts/cli_benchmark_runner.gd`: Automated CLI benchmark generating `reports/benchmark_report.md` and `reports/benchmark_results.json` (supports optional `-Gpu` switch).
* **Windows CLI Note**: Always invoke the direct `Godot_*win64.exe` binary (excluding `*_console.exe`) in automation scripts to avoid Godot 4.7.2 Windows console-wrapper exit hangs.

