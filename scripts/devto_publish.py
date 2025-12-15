#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, Tuple


def read_file(path: str) -> str:
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()


def extract_front_matter(raw: str) -> Tuple[str, str]:
    m = re.match(r"^---\s*(.*?)\s*---\s*(.*)$", raw, re.DOTALL)
    if not m:
        raise ValueError("YAML front matter not found at top of file")
    return m.group(1), m.group(2)


def parse_simple_yaml(yaml_text: str) -> Dict[str, Any]:
    meta: Dict[str, Any] = {}
    lines = yaml_text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        # key: value (single line)
        m = re.match(r"^(\w[\w_]*):\s*(.*)\s*$", line)
        if m:
            key = m.group(1)
            val = m.group(2)
            # handle quoted strings
            if val.startswith(('"', "'")) and val.endswith(('"', "'")) and len(val) >= 2:
                val = val[1:-1]
            # boolean
            if val.lower() in ("true", "false"):
                meta[key] = val.lower() == "true"
            # inline tags [a, b, c]
            elif key == "tags" and val.startswith("[") and val.endswith("]"):
                inner = val[1:-1]
                tags = [t.strip() for t in inner.split(',') if t.strip()]
                meta[key] = tags
            elif val == "":
                # possible multiline list under this key (e.g., tags: \n  - a)
                # collect indented - items
                items: List[str] = []
                j = i + 1
                while j < len(lines):
                    lm = re.match(r"^\s*-\s+(.*)\s*$", lines[j])
                    if lm:
                        items.append(lm.group(1).strip('"\''))
                        j += 1
                    else:
                        break
                if items:
                    meta[key] = items
                    i = j - 1
                else:
                    meta[key] = ""
            else:
                meta[key] = val
        i += 1
    return meta


def build_payload(meta: Dict[str, Any], body: str, publish_flag: bool, minimal: bool, remove_headers: List[str]) -> Dict[str, Any]:
    title = meta.get("title")
    if not title:
        raise ValueError("Missing title in front matter")

    published = meta.get("published")
    if publish_flag:
        published = True
    if published is None:
        published = False

    article: Dict[str, Any] = {
        "title": title,
        "published": bool(published),
        "body_markdown": body,
    }

    if not minimal:
        # optional fields
        if meta.get("description") and ("Description" not in remove_headers):
            article["description"] = meta["description"]
        tags = meta.get("tags") or []
        if isinstance(tags, list) and tags and ("Tags" not in remove_headers):
            article["tags"] = tags
        if meta.get("cover_image") and ("Cover" not in remove_headers):
            article["cover_image"] = meta["cover_image"]
        if meta.get("canonical_url") and ("CanonicalUrl" not in remove_headers):
            article["canonical_url"] = meta["canonical_url"]
        if meta.get("series") and ("Series" not in remove_headers):
            article["series"] = meta["series"]

    return {"article": article}


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="DEV.to publish helper")
    parser.add_argument("--file", dest="file", required=True, help="Path to Markdown file")
    parser.add_argument("--api-key", dest="api_key", required=False, help="DEV.to API key (defaults to DEVTO_API_KEY)")
    parser.add_argument("--publish", dest="publish", action="store_true", help="Force published=true")
    parser.add_argument("--minimal", dest="minimal", action="store_true", help="Send only title/published/body")
    parser.add_argument("--remove-headers", dest="remove_headers", default="", help="CSV of headers to omit: Cover,Tags,Description,CanonicalUrl,Series")
    parser.add_argument("--dry-run", dest="dry_run", action="store_true", help="Print payload JSON and exit")
    args = parser.parse_args(argv)

    api_key = args.api_key or os.environ.get("DEVTO_API_KEY", "")
    if not api_key and not args.dry_run:
        print("DEVTO_API_KEY not provided. Set --api-key or DEVTO_API_KEY env var.", file=sys.stderr)
        return 1

    if not os.path.isfile(args.file):
        print(f"File not found: {args.file}", file=sys.stderr)
        return 1

    raw = read_file(args.file)
    yaml_text, body = extract_front_matter(raw)
    meta = parse_simple_yaml(yaml_text)

    remove_headers = [h.strip() for h in args.remove_headers.split(',') if h.strip()]
    payload = build_payload(meta, body, args.publish, args.minimal, remove_headers)
    json_payload = json.dumps(payload, ensure_ascii=False)

    if args.dry_run:
        print(json_payload)
        return 0

    # Perform request using Python stdlib
    import urllib.request
    req = urllib.request.Request(
        url="https://dev.to/api/articles",
        data=json_payload.encode('utf-8'),
        headers={"api-key": api_key, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode('utf-8')
            print(body)
            return 0
    except Exception as e:
        print(f"API error: {e}", file=sys.stderr)
        print("Request payload:", file=sys.stderr)
        print(json_payload, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
