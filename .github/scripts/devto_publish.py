#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


def read_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def extract_front_matter(raw: str) -> tuple[str, str]:
    m = re.match(r"^---\s*(.*?)\s*---\s*(.*)$", raw, re.DOTALL)
    if not m:
        raise ValueError("YAML front matter not found at top of file")
    return m.group(1), m.group(2)


def parse_simple_yaml(yaml_text: str) -> dict[str, Any]:
    meta: dict[str, Any] = {}
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
            if (
                val.startswith(('"', "'"))
                and val.endswith(('"', "'"))
                and len(val) >= 2
            ):
                val = val[1:-1]
            # boolean
            if val.lower() in ("true", "false"):
                meta[key] = val.lower() == "true"
            # inline tags [a, b, c]
            elif key == "tags" and val.startswith("[") and val.endswith("]"):
                inner = val[1:-1]
                tags = [t.strip() for t in inner.split(",") if t.strip()]
                meta[key] = tags
            elif val == "":
                # possible multiline list under this key (e.g., tags: \n  - a)
                # collect indented - items
                items: list[str] = []
                j = i + 1
                while j < len(lines):
                    lm = re.match(r"^\s*-\s+(.*)\s*$", lines[j])
                    if lm:
                        items.append(lm.group(1).strip("\"'"))
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


def build_payload(
    meta: dict[str, Any],
    body: str,
    publish_flag: bool,
    minimal: bool,
    remove_headers: list[str],
) -> dict[str, Any]:
    title = meta.get("title")
    if not title:
        raise ValueError("Missing title in front matter")

    published = meta.get("published")
    if publish_flag:
        published = True
    if published is None:
        published = False

    article: dict[str, Any] = {
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
            article["main_image"] = meta["cover_image"]
        if meta.get("canonical_url") and ("CanonicalUrl" not in remove_headers):
            article["canonical_url"] = meta["canonical_url"]
        if meta.get("series") and ("Series" not in remove_headers):
            article["series"] = meta["series"]

    return {"article": article}


def raw_github_url(path: str, repo: str, branch: str) -> str:
    return f"https://raw.githubusercontent.com/{repo}/{branch}/{urllib.parse.quote(path, safe='/')}"


def rewrite_local_media_urls(body: str, file_path: str, repo: str, branch: str) -> str:
    base_dir = os.path.dirname(file_path)

    def to_raw_url(url: str) -> str:
        if re.match(r"^[a-z][a-z0-9+.-]*:", url, re.IGNORECASE) or url.startswith("#"):
            return url
        local_path = os.path.normpath(os.path.join(base_dir, urllib.parse.unquote(url)))
        return raw_github_url(local_path.replace(os.sep, "/"), repo, branch)

    def replace_markdown_image(match: re.Match[str]) -> str:
        alt, url = match.group(1), match.group(2)
        return f"![{alt}]({to_raw_url(url)})"

    def replace_html_src(match: re.Match[str]) -> str:
        quote, url = match.group(1), match.group(2)
        return f"src={quote}{to_raw_url(url)}{quote}"

    body = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", replace_markdown_image, body)
    body = re.sub(r"src=(['\"])([^'\"]+)\\1", replace_html_src, body)
    return body


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="DEV.to publish helper")
    parser.add_argument(
        "--file", dest="file", required=True, help="Path to Markdown file"
    )
    parser.add_argument(
        "--api-key",
        dest="api_key",
        required=False,
        help="DEV.to API key (defaults to DEVTO_API_KEY)",
    )
    parser.add_argument(
        "--publish", dest="publish", action="store_true", help="Force published=true"
    )
    parser.add_argument(
        "--minimal",
        dest="minimal",
        action="store_true",
        help="Send only title/published/body",
    )
    parser.add_argument(
        "--remove-headers",
        dest="remove_headers",
        default="",
        help="CSV of headers to omit: Cover,Tags,Description,CanonicalUrl,Series",
    )
    parser.add_argument(
        "--repo",
        dest="repo",
        default=os.environ.get("GITHUB_REPOSITORY", "andremmfaria/articles"),
        help="GitHub repo used for local media URLs",
    )
    parser.add_argument(
        "--branch",
        dest="branch",
        default=os.environ.get("GITHUB_REF_NAME", "main"),
        help="GitHub branch used for local media URLs",
    )
    parser.add_argument(
        "--dry-run",
        dest="dry_run",
        action="store_true",
        help="Print payload JSON and exit",
    )
    args = parser.parse_args(argv)

    api_key = args.api_key or os.environ.get("DEVTO_API_KEY", "")
    if not api_key and not args.dry_run:
        print(
            "DEVTO_API_KEY not provided. Set --api-key or DEVTO_API_KEY env var.",
            file=sys.stderr,
        )
        return 1

    if not os.path.isfile(args.file):
        print(f"File not found: {args.file}", file=sys.stderr)
        return 1

    raw = read_file(args.file)
    yaml_text, body = extract_front_matter(raw)
    meta = parse_simple_yaml(yaml_text)
    body = rewrite_local_media_urls(body, args.file, args.repo, args.branch)

    remove_headers = [h.strip() for h in args.remove_headers.split(",") if h.strip()]
    payload = build_payload(meta, body, args.publish, args.minimal, remove_headers)
    json_payload = json.dumps(payload, ensure_ascii=False)
    article_id = str(meta.get("id") or "").strip()

    if args.dry_run:
        print(json_payload)
        return 0

    method = "PUT" if article_id else "POST"
    url = (
        f"https://dev.to/api/articles/{article_id}"
        if article_id
        else "https://dev.to/api/articles"
    )
    req = urllib.request.Request(
        url=url,
        data=json_payload.encode("utf-8"),
        headers={
            "api-key": api_key,
            "Content-Type": "application/json",
            "User-Agent": "andremmfaria-articles-publisher/1.0",
        },
        method=method,
    )
    for attempt in range(1, 6):
        try:
            with urllib.request.urlopen(req) as resp:
                response_body = resp.read().decode("utf-8")
                response = json.loads(response_body)
                print(f"{method} {url}")
                print(
                    json.dumps(
                        {
                            "id": response.get("id"),
                            "title": response.get("title"),
                            "url": response.get("url"),
                            "edited_at": response.get("edited_at"),
                            "published": response.get("published"),
                        },
                        ensure_ascii=False,
                    )
                )
                return 0
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8", errors="replace")
            if e.code == 429 and attempt < 5:
                retry_after = e.headers.get("Retry-After")
                delay = (
                    int(retry_after)
                    if retry_after and retry_after.isdigit()
                    else attempt * 10
                )
                print(
                    f"Rate limited by DEV.to; retrying in {delay}s (attempt {attempt}/5)",
                    file=sys.stderr,
                )
                time.sleep(delay)
                continue
            print(f"API error: HTTP {e.code} {e.reason}", file=sys.stderr)
            print(f"Response body: {error_body[:1000]}", file=sys.stderr)
            print(f"Request method: {method}", file=sys.stderr)
            print(f"Request URL: {url}", file=sys.stderr)
            print(f"Article title: {meta.get('title', '')}", file=sys.stderr)
            return 2
        except (OSError, json.JSONDecodeError, urllib.error.URLError) as e:
            print(f"API error: {e}", file=sys.stderr)
            print(f"Request method: {method}", file=sys.stderr)
            print(f"Request URL: {url}", file=sys.stderr)
            print(f"Article title: {meta.get('title', '')}", file=sys.stderr)
            return 2
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
