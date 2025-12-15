#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat >&2 <<USAGE
Usage:
  ./scripts/devto_test.sh --file <markdown-file> [--api-key <key>] [--publish] [--minimal] [--remove-headers <csv>] [--dry-run]

Options:
  --file             Path to Markdown article (required)
  --api-key          DEV.to API key (defaults to DEVTO_API_KEY env var)
  --publish          Force published=true in payload
  --minimal          Send only title/published/body_markdown (omit optional fields)
  --remove-headers   Comma-separated list of optional headers to omit: Cover,Tags,Description,CanonicalUrl,Series
  --dry-run          Print JSON payload and exit (no API call)
USAGE
}

FILE_PATH=""
API_KEY="${DEVTO_API_KEY:-}"
PUBLISH=false
MINIMAL=false
REMOVE_HEADERS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE_PATH="$2"; shift 2;;
    --api-key) API_KEY="$2"; shift 2;;
    --publish) PUBLISH=true; shift;;
    --minimal) MINIMAL=true; shift;;
    --remove-headers) REMOVE_HEADERS="$2"; shift 2;;
    --dry-run) DRY_RUN=true; shift;;
    -h|--help) show_usage; exit 0;;
    *) echo "Unknown option: $1" >&2; show_usage; exit 1;;
  esac
done

if [[ -z "$FILE_PATH" ]]; then
  show_usage; exit 1
fi
if [[ ! -f "$FILE_PATH" ]]; then
  echo "File not found: $FILE_PATH" >&2
  exit 1
fi

# Find python
PYTHON_BIN=""
if command -v python >/dev/null 2>&1; then PYTHON_BIN="python"; fi
if command -v python3 >/dev/null 2>&1; then PYTHON_BIN="python3"; fi
if [[ -z "$PYTHON_BIN" ]]; then
  echo "Python is not installed or not in PATH. Please install Python 3." >&2
  exit 1
fi

ARGS=("--file" "$FILE_PATH")
if [[ -n "$API_KEY" ]]; then ARGS+=("--api-key" "$API_KEY"); fi
if [[ "$PUBLISH" == "true" ]]; then ARGS+=("--publish"); fi
if [[ "$MINIMAL" == "true" ]]; then ARGS+=("--minimal"); fi
if [[ -n "$REMOVE_HEADERS" ]]; then ARGS+=("--remove-headers" "$REMOVE_HEADERS"); fi
if [[ "$DRY_RUN" == "true" ]]; then ARGS+=("--dry-run"); fi

# Pre-check API key when not dry-run for clearer error
if [[ "$DRY_RUN" != "true" ]] && [[ -z "$API_KEY" ]]; then
  echo "DEVTO_API_KEY not provided. Use --api-key or set DEVTO_API_KEY, or run with --dry-run." >&2
  exit 1
fi

exec "$PYTHON_BIN" "$(dirname "$0")/devto_publish.py" "${ARGS[@]}"
