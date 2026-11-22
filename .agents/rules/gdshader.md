---
trigger: glob
globs: "*.gdshader"
description: "Godot 4.7 shader rules and Compatibility/WebGL 2.0 constraints"
---

# Godot 4.7 Shader Guidelines (.gdshader)

- `.gdshader` files do not open automatically in the Godot External Editor setting; edit them directly in VS Code and let Godot auto-reload on change.
- Keep shaders compatible with the `gl_compatibility` (OpenGL / WebGL 2.0) renderer so Web exports work cleanly:
  - Avoid Forward+-only features such as compute shaders, `hint_screen_texture` mismatches without GL compatibility checks, or desktop-only GLSL extensions.
  - Specify explicit `shader_type` (`canvas_item`, `spatial`, `particles`, `sky`, or `fog`) and clean `uniform` type hints (`source_color`, `hint_range(...)`).
- When moving or renaming a `.gdshader`, keep its `.uid` sidecar file synchronized.
