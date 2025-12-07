#!/usr/bin/env bash
set -euo pipefail

FILE_PATH="${1:-}"
PUBLISH="${PUBLISH:-false}"
API_KEY="${DEVTO_API_KEY:-}"

if [[ -z "$FILE_PATH" ]]; then
  echo "Usage: DEVTO_API_KEY=... PUBLISH=false ./scripts/devto_test.sh <markdown-file>" >&2
  exit 1
fi
if [[ -z "$API_KEY" ]]; then
  echo "DEVTO_API_KEY not set" >&2
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

# Minimal parse for common keys
TITLE=$(echo "$YAML_BLOCK" | awk -F': ' '/^title:/ {sub(/^title: /,""); print}' | sed 's/^\"//; s/\"$//')
DESC=$(echo "$YAML_BLOCK" | awk -F': ' '/^description:/ {sub(/^description: /,""); print}' | sed 's/^\"//; s/\"$//')
COVER=$(echo "$YAML_BLOCK" | awk -F': ' '/^cover_image:/ {sub(/^cover_image: /,""); print}' | sed 's/^\"//; s/\"$//')
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

# Build JSON payload
jq -n --arg title "$TITLE" \
      --argjson published $PUBLISHED \
      --arg description "$DESC" \
      --arg cover_image "$COVER" \
      --arg body_markdown "$BODY" \
      --argjson tags "$TAGS_JSON" \
      '{article:{title:$title,published:$published,description:$description,body_markdown:$body_markdown,cover_image:$cover_image,tags:$tags}}' |
  curl -sSf -X POST "https://dev.to/api/articles" \
    -H "api-key: $API_KEY" -H "Content-Type: application/json" \
    --data-binary @- \
    | jq '.'
