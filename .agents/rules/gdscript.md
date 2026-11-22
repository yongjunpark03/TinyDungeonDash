---
trigger: glob
globs: "*.gd"
description: "GDScript 2.0 coding standards and Godot 4.7+ invariants"
---

# GDScript 2.0 Standards (Godot 4.7+)

- Declare explicit static types for all member variables, parameters, and return types (including `-> void`).
- Only use `:=` when the RHS type is unambiguously static (avoid `:=` on untyped `Variant` calls like `get_node()` or `instantiate()` without `as Type`).
- Use Godot 4 syntax exclusively: `@export`, `@onready`, `super()`, typed `signal` + `.emit()` / `.connect(callable)`, `TileMapLayer`, and `move_and_slide()` with zero arguments.
- Free dynamically created nodes safely with `queue_free()`.
- Keep indentation as tabs (`gdlint` / `gdformat` compatible), lines <= 120 characters, and avoid unused-parameter warnings by prefixing unused parameters with `_` (e.g., `_delta: float`).
- Do not modify or delete `.uid` sidecar files separately from their `.gd` scripts.
