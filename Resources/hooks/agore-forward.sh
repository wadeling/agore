#!/usr/bin/env bash
# Cursor user hook: strip secrets, forward presence to Agore, never block the agent.
python3 -c '
import json, os, sys, urllib.request
from datetime import datetime, timezone

raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    print("{}")
    sys.exit(0)

def last_component(path):
    if not path:
        return ""
    return os.path.basename(str(path).rstrip("/"))

roots = data.get("workspace_roots") or []
slug = last_component(roots[0]) if roots else ""

payload = {
    "conversation_id": data.get("conversation_id"),
    "hook_event_name": data.get("hook_event_name") or "",
    "tool_name": data.get("tool_name"),
    "project_slug": slug,
    "occurred_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
    "subagent_id": data.get("subagent_id"),
    "parent_conversation_id": data.get("parent_conversation_id"),
    "tool_use_id": data.get("tool_use_id") or data.get("tool_call_id"),
}

port_file = os.path.expanduser("~/Library/Application Support/Agore/ingest.port")
try:
    with open(port_file, "r", encoding="utf-8") as handle:
        port = handle.read().strip()
    int(port)
except Exception:
    print("{}")
    sys.exit(0)

body = json.dumps(payload).encode("utf-8")
req = urllib.request.Request(
    "http://127.0.0.1:%s/events" % port,
    data=body,
    headers={"Content-Type": "application/json", "Content-Length": str(len(body))},
    method="POST",
)
try:
    urllib.request.urlopen(req, timeout=0.4).read()
except Exception:
    pass
print("{}")
' || true
exit 0
