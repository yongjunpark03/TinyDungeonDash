import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def resolve_target_path(payload: dict) -> Path | None:
    tool_call = payload.get("toolCall") or {}
    args = tool_call.get("args") or {}
    raw_path = None
    for key in ("Path", "path", "file_path", "script_path", "res_path", "TargetFile", "file"):
        val = args.get(key)
        if isinstance(val, str) and val.strip():
            raw_path = val.strip()
            break

    if not raw_path:
        return None

    workspace_root = Path(__file__).resolve().parents[2]
    workspace_paths = payload.get("workspacePaths")
    if isinstance(workspace_paths, list) and workspace_paths:
        workspace_root = Path(str(workspace_paths[0]))

    if raw_path.startswith("res://"):
        rel = raw_path[len("res://") :].lstrip("/\\")
        target = workspace_root / rel
    else:
        candidate = Path(raw_path)
        if candidate.is_absolute():
            target = candidate
        else:
            base = Path(str(payload.get("cwd") or workspace_root))
            target = base / candidate

    return target


def find_gdlint() -> str | None:
    found = shutil.which("gdlint")
    if found:
        return found
    fallback = Path(os.path.expandvars(r"%USERPROFILE%\.local\bin\gdlint.exe"))
    if fallback.is_file():
        return str(fallback)
    return None


def main() -> int:
    raw = sys.stdin.buffer.read().decode("utf-8-sig", errors="replace").strip()
    payload: dict = {}
    if raw:
        try:
            loaded = json.loads(raw)
            if isinstance(loaded, dict):
                payload = loaded
        except json.JSONDecodeError:
            payload = {}

    target = resolve_target_path(payload)
    if target is None or target.suffix.lower() != ".gd":
        print("{}")
        return 0

    normalized_parts = {part.lower() for part in target.parts}
    if "addons" in normalized_parts or ".godot" in normalized_parts:
        print("{}")
        return 0

    if not target.is_file():
        print("{}")
        return 0

    gdlint_bin = find_gdlint()
    if not gdlint_bin:
        print("{}")
        return 0

    proc = subprocess.run([gdlint_bin, str(target)], capture_output=True, text=True)
    if proc.stdout:
        sys.stderr.write(proc.stdout)
    if proc.stderr:
        sys.stderr.write(proc.stderr)

    print("{}")
    return 0 if proc.returncode == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
