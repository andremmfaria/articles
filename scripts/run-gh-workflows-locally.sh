#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Run GitHub Actions workflows locally with act.

Usage:
  ./scripts/run-gh-workflows-locally.sh [workflow ...]

Examples:
  ./scripts/run-gh-workflows-locally.sh
  ./scripts/run-gh-workflows-locally.sh publish.yml
  ./scripts/run-gh-workflows-locally.sh pre-commit.yml publish.yml

Notes:
  - Requires: act, Docker
  - Uses workflow_dispatch for all runs
  - If .secrets.act exists at repo root, it is passed to act automatically
  - If no DEV_TO_API_KEY is provided, the publish workflow skips the remote DEV.to step during local runs
  - Publish workflow runs in dry-run mode automatically when executed via act
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v act >/dev/null 2>&1; then
  echo "Error: act is not installed or not available in PATH." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker is not installed or not available in PATH." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

WORKFLOWS=("$@")
if [[ ${#WORKFLOWS[@]} -eq 0 ]]; then
  WORKFLOWS=("pre-commit.yml" "publish.yml")
fi

EVENT_FILE=$(mktemp)
cleanup() {
  rm -f "$EVENT_FILE"
}
trap cleanup EXIT

cat > "$EVENT_FILE" <<'EOF'
{
  "ref": "refs/heads/main",
  "repository": {
    "full_name": "local/articles"
  }
}
EOF

COMMON_ARGS=(workflow_dispatch --container-architecture linux/amd64 --eventpath "$EVENT_FILE")

if [[ -f .secrets.act ]]; then
  COMMON_ARGS+=(--secret-file .secrets.act)
fi

if [[ -n "${DEV_TO_API_KEY:-}" ]]; then
  COMMON_ARGS+=(--secret "DEV_TO_API_KEY=${DEV_TO_API_KEY}")
fi

for workflow in "${WORKFLOWS[@]}"; do
  workflow_path=".github/workflows/$workflow"
  if [[ ! -f "$workflow_path" ]]; then
    echo "Error: workflow not found: $workflow_path" >&2
    exit 1
  fi

  echo "Running $workflow_path"
  act "${COMMON_ARGS[@]}" -W "$workflow_path"
done
