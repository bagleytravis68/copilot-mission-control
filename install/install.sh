#!/usr/bin/env bash
set -euo pipefail

TARGET="copilot"
SOURCE="local"
MARKETPLACE_SPEC=""
MARKETPLACE_NAME="mission-control-marketplace"
PLUGIN_NAME="mission-control-agent-team"
BUILD="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --source)
      SOURCE="$2"
      shift 2
      ;;
    --marketplace-spec)
      MARKETPLACE_SPEC="$2"
      shift 2
      ;;
    --marketplace-name)
      MARKETPLACE_NAME="$2"
      shift 2
      ;;
    --plugin-name)
      PLUGIN_NAME="$2"
      shift 2
      ;;
    --build)
      BUILD="true"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$TARGET" != "copilot" ]]; then
  echo "Only the 'copilot' target is implemented right now." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_PATH="$REPO_ROOT/plugins/mission-control"

if [[ "$BUILD" == "true" ]]; then
  if ! command -v pwsh >/dev/null 2>&1; then
    echo "The 'pwsh' command is required for --build but was not found on PATH." >&2
    exit 1
  fi

  pwsh -File "$REPO_ROOT/adapters/copilot/build.ps1"
fi

if ! command -v copilot >/dev/null 2>&1; then
  echo "The 'copilot' CLI was not found on PATH." >&2
  exit 1
fi

if [[ "$SOURCE" == "local" ]]; then
  copilot plugin install "$PLUGIN_PATH"
  exit 0
fi

if [[ "$SOURCE" == "marketplace" ]]; then
  if [[ -z "$MARKETPLACE_SPEC" ]]; then
    echo "Marketplace installs require --marketplace-spec OWNER/REPO or a marketplace path." >&2
    exit 1
  fi

  copilot plugin marketplace add "$MARKETPLACE_SPEC"
  copilot plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}"
  exit 0
fi

echo "Unsupported source: $SOURCE" >&2
exit 1
