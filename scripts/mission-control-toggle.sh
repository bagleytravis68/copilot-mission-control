#!/usr/bin/env bash
set -euo pipefail

command="${1:-}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$repo_root/.tmp"
plugin_name="mission-control-agent-team"
hooks_marker="$tmp_dir/mission-control.disabled"
guard_marker="$tmp_dir/mission-control-guard.disabled"
trace_marker="$tmp_dir/mission-control-trace.disabled"

enable_marker() {
  mkdir -p "$(dirname "$1")"
  : > "$1"
}

disable_marker() {
  rm -f "$1"
}

case "$command" in
  status)
    echo "Mission Control plugin: use 'copilot plugin list' for installed state."
    echo "All hooks disabled: $([ -f "$hooks_marker" ] && echo true || echo false)"
    echo "Guard disabled: $([ -f "$guard_marker" ] && echo true || echo false)"
    echo "Trace disabled: $([ -f "$trace_marker" ] && echo true || echo false)"
    echo "Env MISSION_CONTROL_DISABLED: ${MISSION_CONTROL_DISABLED:-}"
    echo "Env MISSION_CONTROL_GUARD_DISABLED: ${MISSION_CONTROL_GUARD_DISABLED:-}"
    echo "Env MISSION_CONTROL_TRACE_DISABLED: ${MISSION_CONTROL_TRACE_DISABLED:-}"
    ;;
  enable-plugin)
    copilot plugin install "$repo_root/plugins/mission-control"
    ;;
  disable-plugin)
    copilot plugin uninstall "$plugin_name"
    ;;
  enable-hooks)
    disable_marker "$hooks_marker"
    echo "Mission Control hooks enabled for this repository."
    ;;
  disable-hooks)
    enable_marker "$hooks_marker"
    echo "Mission Control hooks disabled for this repository."
    ;;
  enable-guard)
    disable_marker "$guard_marker"
    echo "Mission Control communication guard enabled for this repository."
    ;;
  disable-guard)
    enable_marker "$guard_marker"
    echo "Mission Control communication guard disabled for this repository."
    ;;
  enable-trace)
    disable_marker "$trace_marker"
    echo "Mission Control session trace enabled for this repository."
    ;;
  disable-trace)
    enable_marker "$trace_marker"
    echo "Mission Control session trace disabled for this repository."
    ;;
  *)
    echo "Usage: $0 status|enable-plugin|disable-plugin|enable-hooks|disable-hooks|enable-guard|disable-guard|enable-trace|disable-trace" >&2
    exit 2
    ;;
esac
