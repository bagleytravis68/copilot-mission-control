#!/usr/bin/env bash
set -u

event="${1:-}"
payload="$(cat)"

if [ "${MISSION_CONTROL_DISABLED:-}" = "1" ] || [ "${MISSION_CONTROL_GUARD_DISABLED:-}" = "1" ] || [ -f ./.tmp/mission-control.disabled ] || [ -f ./.tmp/mission-control-guard.disabled ]; then
  echo "{}"
  exit 0
fi

TRACE_EVENT="$event" TRACE_PAYLOAD="$payload" python3 - <<'PY'
import json
import os
import pathlib
import re
import sys

AGENT_PATTERNS = [
    r"maestro", r"maestro-orchestrator", r"maestro \(orchestrator\)", r"mission-control-agent-team:maestro-orchestrator",
    r"pax", r"pax-planner", r"pax \(planner\)", r"mission-control-agent-team:pax-planner",
    r"scout", r"scout-explorer", r"scout \(explorer\)", r"mission-control-agent-team:scout-explorer",
    r"ava", r"ava-architect", r"ava \(architect\)", r"mission-control-agent-team:ava-architect",
    r"carl", r"carl-coder", r"carl \(coder\)", r"mission-control-agent-team:carl-coder",
    r"tess", r"tess-tester", r"tess \(tester\)", r"mission-control-agent-team:tess-tester",
    r"sera", r"sera-security", r"sera \(security\)", r"mission-control-agent-team:sera-security",
    r"riley", r"riley-relay", r"riley \(relay\)", r"mission-control-agent-team:riley-relay",
    r"sam", r"sam-scribe", r"sam \(scribe\)", r"mission-control-agent-team:sam-scribe",
    r"libby", r"libby-librarian", r"libby \(librarian\)", r"mission-control-agent-team:libby-librarian",
]


def is_mission_text(text):
    lowered = (text or "").lower()
    return any(re.search(rf"(?<![a-z0-9_-]){pattern}(?![a-z0-9_-])", lowered) for pattern in AGENT_PATTERNS)


def is_mission_request(tool_args, objects, combined):
    for obj in objects:
        if is_mission_text(str(obj.get("to") or "")):
            return True
    if isinstance(tool_args, dict):
        for field in ("to", "agent", "agentName", "agent_name", "name", "subagent", "target", "targetAgent", "target_agent"):
            if is_mission_text(str(tool_args.get(field) or "")):
                return True
    return False


def strings(value):
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        result = []
        for item in value.values():
            result.extend(strings(item))
        return result
    if isinstance(value, list):
        result = []
        for item in value:
            result.extend(strings(item))
        return result
    return []


def json_objects(text):
    decoder = json.JSONDecoder()
    objects = []
    for match in re.finditer(r"\{", text or ""):
        try:
            obj, _ = decoder.raw_decode(text[match.start():])
        except Exception:
            continue
        if isinstance(obj, dict):
            objects.append(obj)
    return objects


def list_errors(value, name):
    errors = []
    if not isinstance(value, list):
        return [f"{name} must be an array of short strings."]
    if len(value) > 12:
        errors.append(f"{name} must contain 12 or fewer entries.")
    if any(not isinstance(item, str) or not item.strip() for item in value):
        errors.append(f"{name} entries must be non-empty strings.")
    return errors


def request_errors(obj):
    required = {"handoff_id", "to", "goal", "scope", "constraints", "success", "deliverable"}
    allowed = required | {"custom"}
    errors = [f"Missing request field: {field}." for field in sorted(required - obj.keys())]
    for field in ("handoff_id", "to", "goal", "deliverable"):
        if field in obj and (not isinstance(obj[field], str) or not obj[field].strip()):
            errors.append(f"{field} must be a non-empty string.")
    for field in ("scope", "constraints", "success"):
        if field in obj:
            errors.extend(list_errors(obj[field], field))
    errors.extend(f"Unknown request field: {field}." for field in sorted(set(obj) - allowed))
    return errors


def response_errors(obj):
    required = {"handoff_id", "status", "summary", "evidence", "artifacts", "gaps", "next"}
    allowed = required | {"custom"}
    errors = [f"Missing response field: {field}." for field in sorted(required - obj.keys())]
    if obj.get("status") not in {"SUCCESS", "PARTIAL", "FAILED", "BLOCKED"}:
        errors.append("status must be SUCCESS, PARTIAL, FAILED, or BLOCKED.")
    for field in ("handoff_id", "summary"):
        if field in obj and (not isinstance(obj[field], str) or not obj[field].strip()):
            errors.append(f"{field} must be a non-empty string.")
    for field in ("evidence", "artifacts"):
        if field in obj:
            errors.extend(list_errors(obj[field], field))
    errors.extend(f"Unknown response field: {field}." for field in sorted(set(obj) - allowed))
    return errors


def instruction():
    return (
        'Mission Control communication wrapper required. Request JSON: {"handoff_id":"...",'
        '"to":"agent","goal":"one sentence","scope":["paths/systems"],"constraints":["hard limits"],'
        '"success":["measurable result"],"deliverable":"expected output"}. Response JSON only: '
        '{"handoff_id":"same","status":"SUCCESS|PARTIAL|FAILED|BLOCKED","summary":"1-2 sentences",'
        '"evidence":["commands/files/facts"],"artifacts":["paths"],"gaps":null,"next":null,"custom":{}}. '
        "Keep it concise; do not include prompt text, secrets, or tool output dumps."
    )


try:
    event = os.environ.get("TRACE_EVENT", "")
    raw = os.environ.get("TRACE_PAYLOAD", "")
    if not raw.strip():
        print("{}")
        raise SystemExit(0)
    payload = json.loads(raw)

    if event == "subagentStart":
        agent_name = str(payload.get("agentName") or payload.get("agent_name") or "")
        if is_mission_text(agent_name):
            print(json.dumps({"additionalContext": instruction()}, separators=(",", ":")))
            raise SystemExit(0)

    if event == "preToolUse":
        tool_name = str(payload.get("toolName") or payload.get("tool_name") or "")
        if tool_name not in {"agent", "task"}:
            print("{}")
            raise SystemExit(0)
        tool_args = payload.get("toolArgs") or payload.get("tool_input")
        combined = "\n".join(strings(tool_args))
        objects = json_objects(combined)
        if not is_mission_request(tool_args, objects, combined):
            print("{}")
            raise SystemExit(0)
        request = next((obj for obj in objects if "handoff_id" in obj), None)
        if request is None:
            print(json.dumps({
                "permissionDecision": "deny",
                "permissionDecisionReason": "Mission Control subagent handoffs must include the compact JSON request wrapper with handoff_id, to, goal, scope, constraints, success, and deliverable.",
            }, separators=(",", ":")))
            raise SystemExit(0)
        errors = request_errors(request)
        if errors:
            print(json.dumps({
                "permissionDecision": "deny",
                "permissionDecisionReason": "Invalid Mission Control handoff request: " + " ".join(errors),
            }, separators=(",", ":")))
            raise SystemExit(0)

    if event == "subagentStop":
        agent_name = str(payload.get("agentName") or payload.get("agent_name") or "")
        if not is_mission_text(agent_name):
            print("{}")
            raise SystemExit(0)
        transcript = pathlib.Path(str(payload.get("transcriptPath") or payload.get("transcript_path") or ""))
        if not transcript.exists():
            print("{}")
            raise SystemExit(0)
        text = transcript.read_text(encoding="utf-8", errors="replace")[-200000:]
        responses = [obj for obj in json_objects(text) if "handoff_id" in obj and "status" in obj]
        if not responses:
            print(json.dumps({
                "decision": "block",
                "reason": "Return the Mission Control response wrapper as JSON only: handoff_id, status, summary, evidence, artifacts, gaps, next, optional custom.",
            }, separators=(",", ":")))
            raise SystemExit(0)
        errors = response_errors(responses[-1])
        if errors:
            print(json.dumps({
                "decision": "block",
                "reason": "Fix the Mission Control response wrapper: " + " ".join(errors) + " Return JSON only.",
            }, separators=(",", ":")))
            raise SystemExit(0)
except Exception as exc:
    print(f"Mission Control communication guard skipped: {exc}", file=sys.stderr)

print("{}")
PY
