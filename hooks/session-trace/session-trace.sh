#!/usr/bin/env bash
set -u

event="${1:-}"
payload="$(cat)"

if [ "${MISSION_CONTROL_DISABLED:-}" = "1" ] || [ "${MISSION_CONTROL_TRACE_DISABLED:-}" = "1" ] || [ -f ./.tmp/mission-control.disabled ] || [ -f ./.tmp/mission-control-trace.disabled ]; then
  echo "{}"
  exit 0
fi

TRACE_EVENT="$event" TRACE_PAYLOAD="$payload" python3 - <<'PY'
import datetime
import json
import os
import pathlib
import re
import sys


def iso_timestamp(value):
    if value is None:
        return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")
    if isinstance(value, (int, float)):
        return datetime.datetime.fromtimestamp(value / 1000, datetime.timezone.utc).isoformat().replace("+00:00", "Z")
    return datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00")).astimezone(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def safe_path_segment(value, fallback):
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip("-")
    return safe or fallback


def agent_key(value):
    return safe_path_segment(value.lower(), "unknown-agent")


try:
    event = os.environ.get("TRACE_EVENT", "")
    raw = os.environ.get("TRACE_PAYLOAD", "")
    if not raw.strip():
        print("{}")
        raise SystemExit(0)

    payload = json.loads(raw)
    session_id = str(payload.get("sessionId") or payload.get("session_id") or "unknown-session")
    repo_root = str(payload.get("cwd") or os.getcwd())
    at = iso_timestamp(payload.get("timestamp"))
    session_dir = pathlib.Path(repo_root) / ".tmp" / "sessions" / safe_path_segment(session_id, "unknown-session")
    trace_path = session_dir / "session.json"

    session_dir.mkdir(parents=True, exist_ok=True)

    if trace_path.exists():
        trace = json.loads(trace_path.read_text(encoding="utf-8"))
    else:
        trace = {
            "schemaVersion": 1,
            "harness": "github-copilot-cli",
            "sessionId": session_id,
            "repoRoot": repo_root,
            "status": "running",
            "startedAt": at,
            "endedAt": None,
            "agents": {},
            "handoffs": [],
            "events": [],
        }

    trace.setdefault("agents", {})
    trace.setdefault("handoffs", [])
    trace.setdefault("events", [])
    if trace.get("harness") == "github-copilot-app":
        trace["harness"] = "multi"
    trace["sessionId"] = session_id
    trace["repoRoot"] = repo_root

    event_record = {
        "type": event,
        "at": at,
        "eventSource": "copilot-cli-hook",
        "agentName": None,
        "status": None,
        "reason": None,
    }

    if event == "sessionStart":
        trace["status"] = "running"
        trace["startedAt"] = at
        trace["endedAt"] = None
        event_record["status"] = "running"
        event_record["reason"] = payload.get("source")
    elif event == "sessionEnd":
        reason = str(payload.get("reason") or "complete")
        trace["status"] = {
            "complete": "complete",
            "error": "error",
            "timeout": "timeout",
            "abort": "aborted",
            "user_exit": "user_exit",
        }.get(reason, "complete")
        trace["endedAt"] = at
        event_record["status"] = trace["status"]
        event_record["reason"] = reason
    elif event == "subagentStart":
        name = str(payload.get("agentName") or payload.get("agent_name") or "unknown-agent")
        key = agent_key(name)
        trace["agents"][key] = {
            "name": name,
            "displayName": payload.get("agentDisplayName") or payload.get("agent_display_name"),
            "description": payload.get("agentDescription"),
            "status": "running",
            "startedAt": at,
            "completedAt": None,
            "handoffIds": [],
        }
        event_record["agentName"] = name
        event_record["status"] = "running"
    elif event == "subagentStop":
        name = str(payload.get("agentName") or payload.get("agent_name") or "unknown-agent")
        key = agent_key(name)
        trace["agents"].setdefault(
            key,
            {
                "name": name,
                "displayName": payload.get("agentDisplayName") or payload.get("agent_display_name"),
                "description": None,
                "status": "running",
                "startedAt": at,
                "completedAt": None,
                "handoffIds": [],
            },
        )
        trace["agents"][key]["status"] = "complete"
        trace["agents"][key]["completedAt"] = at
        event_record["agentName"] = name
        event_record["status"] = "complete"
        event_record["reason"] = payload.get("stopReason") or payload.get("stop_reason")

    trace["events"].append(event_record)
    temp_path = trace_path.with_name(f"session.{os.getpid()}.{int(datetime.datetime.now(datetime.timezone.utc).timestamp() * 1000)}.tmp")
    temp_path.write_text(json.dumps(trace, indent=2) + "\n", encoding="utf-8")
    os.replace(temp_path, trace_path)
except Exception as exc:
    print(f"Mission Control session trace hook skipped: {exc}", file=sys.stderr)

print("{}")
PY
