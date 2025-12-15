#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat >&2 <<USAGE
Usage:
  ./scripts/devto_test.sh --file <markdown-file> [--api-key <key>] [--publish] [--minimal] [--remove-headers <csv>]

Options:
  --file             Path to Markdown article (required)
  --api-key          DEV.to API key (defaults to DEVTO_API_KEY env var)
  --publish          Force published=true in payload
  --minimal          Send only title/published/body_markdown (omit optional fields)
  --remove-headers   Comma-separated list of optional headers to omit: Cover,Tags,Description,CanonicalUrl,Series
USAGE
}

FILE_PATH=""
API_KEY="${DEVTO_API_KEY:-}"
PUBLISH=false
MINIMAL=false
REMOVE_HEADERS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE_PATH="$2"; shift 2;;
    --api-key) API_KEY="$2"; shift 2;;
    --publish) PUBLISH=true; shift;;
    --minimal) MINIMAL=true; shift;;
    --remove-headers) REMOVE_HEADERS="$2"; shift 2;;
    -h|--help) show_usage; exit 0;;
    *) echo "Unknown option: $1" >&2; show_usage; exit 1;;
  esac
done

if [[ -z "$FILE_PATH" ]]; then
  show_usage; exit 1
fi
if [[ -z "$API_KEY" ]]; then
  echo "DEVTO_API_KEY not set and --api-key not provided" >&2
  exit 1
fi
if [[ ! -f "$FILE_PATH" ]]; then
  echo "File not found: $FILE_PATH" >&2
  exit 1
fi

RAW=$(cat "$FILE_PATH")
# Extract front matter block
if [[ "$RAW" =~ ^---[[:space:]]*$([[:space:][:print:]]*)---[[:space:]]* ]]; then
  YAML_BLOCK=$(echo "$RAW" | awk 'BEGIN{p=0} /^---/{if(p==0){p=1;next}else{p=0;exit}} p{print}')
  BODY=$(echo "$RAW" | awk 'BEGIN{p=0} /^---/{c++} {if(c>=2){print}}')
else
  echo "YAML front matter not found at top of file" >&2
  exit 1
fi

"# Minimal parse for common keys"
TITLE=$(echo "$YAML_BLOCK" | awk -F': ' '/^title:/ {sub(/^title: /,"\"\"","$0"); print substr($0, index($0,": ")+2)}' | sed 's/^\"//; s/\"$//')
DESC=$(echo "$YAML_BLOCK" | awk -F': ' '/^description:/ {sub(/^description: /,"\"\"","$0"); print substr($0, index($0,": ")+2)}' | sed 's/^\"//; s/\"$//')
COVER=$(echo "$YAML_BLOCK" | awk -F': ' '/^cover_image:/ {sub(/^cover_image: /,"\"\"","$0"); print substr($0, index($0,": ")+2)}' | sed 's/^\"//; s/\"$//')
CANONICAL=$(echo "$YAML_BLOCK" | awk -F': ' '/^canonical_url:/ {sub(/^canonical_url: /,"\"\"","$0"); print substr($0, index($0,": ")+2)}' | sed 's/^\"//; s/\"$//')
SERIES=$(echo "$YAML_BLOCK" | awk -F': ' '/^series:/ {sub(/^series: /,"\"\"","$0"); print substr($0, index($0,": ")+2)}' | sed 's/^\"//; s/\"$//')
TAGS_LINE=$(echo "$YAML_BLOCK" | awk -F': ' '/^tags:/ {print $2}')

# Parse tags: either list or inline [a,b]
TAGS_JSON="[]"
if echo "$TAGS_LINE" | grep -q '\['; then
  TAGS_JSON=$(echo "$TAGS_LINE" | sed 's/\[\(.*\)\]/\1/' | awk -F',' '{printf("["); for(i=1;i<=NF;i++){gsub(/^ +| +$/,"",$i); printf("\"%s\"", $i); if(i<NF) printf(","); } printf("]") }')
else
  # Multiline map form
  TAGS_JSON=$(echo "$YAML_BLOCK" | awk '/^tags:/ {p=1;next} p{ if($0 ~ /^  - /){gsub(/^  - /,"",$0); a[++n]=$0} else if($0 !~ /^ /){p=0} } END{ printf("["); for(i=1;i<=n;i++){printf("\"%s\"", a[i]); if(i<n) printf(",") } printf("]") }')
fi

if [[ -z "$TITLE" ]]; then
  echo "Missing title in front matter" >&2
  exit 1
fi

PUBLISHED=false
if [[ "$PUBLISH" == "true" ]]; then PUBLISHED=true; fi

# Helper: check if header should be removed
should_remove() {
  local key="$1"
  [[ -n "$REMOVE_HEADERS" ]] && echo ",$REMOVE_HEADERS," | grep -qi ",$key,"
}

# Build JSON payload
if [[ "$MINIMAL" == "true" ]]; then
  jq -n --arg title "$TITLE" \
        --argjson published $PUBLISHED \
        --arg body_markdown "$BODY" \
        '{article:{title:$title,published:$published,body_markdown:$body_markdown}}'
else
  # Start with required fields
  PAYLOAD=$(jq -n --arg title "$TITLE" --argjson published $PUBLISHED --arg body_markdown "$BODY" '{article:{title:$title,published:$published,body_markdown:$body_markdown}}')

  # Conditionally add optional fields
  if [[ -n "$DESC" ]] && ! should_remove "Description"; then
    PAYLOAD=$(echo "$PAYLOAD" | jq --arg description "$DESC" '.article.description = $description')
  fi
  if [[ -n "$COVER" ]] && ! should_remove "Cover"; then
    PAYLOAD=$(echo "$PAYLOAD" | jq --arg cover_image "$COVER" '.article.cover_image = $cover_image')
  fi
  if [[ "$TAGS_JSON" != "[]" ]] && ! should_remove "Tags"; then
    PAYLOAD=$(echo "$PAYLOAD" | jq --argjson tags "$TAGS_JSON" '.article.tags = $tags')
  fi
  if [[ -n "$CANONICAL" ]] && ! should_remove "CanonicalUrl"; then
    PAYLOAD=$(echo "$PAYLOAD" | jq --arg canonical_url "$CANONICAL" '.article.canonical_url = $canonical_url')
  fi
  if [[ -n "$SERIES" ]] && ! should_remove "Series"; then
    PAYLOAD=$(echo "$PAYLOAD" | jq --arg series "$SERIES" '.article.series = $series')
  fi

  echo "$PAYLOAD"
fi |
  curl -sSf -X POST "https://dev.to/api/articles" \
    -H "api-key: $API_KEY" -H "Content-Type: application/json" \
    --data-binary @- \
    | jq '.'
