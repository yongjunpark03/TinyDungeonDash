import json
import re
import sys


DELETE_CMD_RE = re.compile(r"(^|[;&|\s])(del|erase|rm|rmdir|remove-item|ri)\b", re.IGNORECASE)
UID_OR_IMPORT_RE = re.compile(r"(\.uid\b|\.import\b|\*\.uid|\*\.import)", re.IGNORECASE)
GITIGNORE_UID_RE = re.compile(r"\.gitignore.*(\.uid|\.import)|(\*\.uid|\*\.import).*\.gitignore", re.IGNORECASE)
CRITICAL_TARGET_RE = re.compile(r"(project\.godot|\bscenes\b|\bscripts\b|[\\/]\.git\b|^\.git\b|\s\.git\b)", re.IGNORECASE)


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

    tool_call = payload.get("toolCall") or {}
    args = tool_call.get("args") or {}
    cmd = str(args.get("CommandLine") or args.get("command") or "")

    reason = ""
    if GITIGNORE_UID_RE.search(cmd):
        reason = "Safety check: never add *.uid or *.import to .gitignore in a Godot 4.4+ project."
    elif DELETE_CMD_RE.search(cmd) and UID_OR_IMPORT_RE.search(cmd):
        reason = "Safety check: deleting .uid or .import files can break Godot scene/resource references."
    elif DELETE_CMD_RE.search(cmd) and CRITICAL_TARGET_RE.search(cmd):
        reason = "Safety check: destructive deletion targeting project.godot, scenes, scripts, or .git requires confirmation."

    if reason:
        print(json.dumps({"decision": "ask", "reason": reason}))
    else:
        print(json.dumps({"decision": "allow"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
