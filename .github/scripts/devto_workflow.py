#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

import devto_publish

DEVTO_ENV_NAME = "DEVTO_API_KEY"
DEVTO_FLAG_NAME = "--api-key"
LOCAL_DUMMY_VALUE = "dummy-local-" + "token"


def run_git(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        check=check,
        text=True,
        capture_output=True,
    )


def write_github_output(output_path: str | None, values: dict[str, str]) -> None:
    if not output_path:
        return

    with open(output_path, "a", encoding="utf-8") as f:
        f.writelines(f"{key}={value}\n" for key, value in values.items())


def changed_articles_for_dispatch() -> list[str]:
    return sorted(
        str(path) for path in Path("articles").glob("**/*.md") if path.is_file()
    )


def changed_articles_for_push(before: str, sha: str) -> list[str]:
    result = run_git(
        ["diff", "--name-only", "-z", before, sha, "--", "articles/**/*.md"]
    )
    paths = result.stdout.split("\0")
    return [path for path in paths if path and Path(path).is_file()]


def write_nul_file(path: str, values: list[str]) -> None:
    Path(path).write_bytes(b"\0".join(value.encode("utf-8") for value in values))


def read_nul_file(path: str) -> list[str]:
    source = Path(path)
    if not source.exists():
        return []

    return [
        value.decode("utf-8") for value in source.read_bytes().split(b"\0") if value
    ]


def command_changed(args: argparse.Namespace) -> int:
    if args.event_name == "workflow_dispatch":
        articles = changed_articles_for_dispatch()
    else:
        articles = changed_articles_for_push(args.before, args.sha)

    write_nul_file(args.changed_file, articles)
    count = len(articles)
    should_publish = "true" if count else "false"
    write_github_output(
        args.github_output,
        {
            "publish": should_publish,
            "count": str(count),
        },
    )

    if count:
        print(f"Found {count} changed article file(s).")
    else:
        print("No changed article files to publish.")
    return 0


def command_publish(args: argparse.Namespace) -> int:
    devto_key = args.devto_key or os.environ.get(DEVTO_ENV_NAME, "")
    act = os.environ.get("ACT") == "true"

    if act and (not devto_key or devto_key == LOCAL_DUMMY_VALUE):
        print(
            "Running under act without a real DEV.to credential; skipping remote publish step."
        )
        return 0

    dry_run = args.dry_run or act
    if act and dry_run:
        print("Running under act; enabling DEV.to dry-run mode.")

    for article_file in read_nul_file(args.changed_file):
        print(f"Publishing {article_file}")
        publish_args = [
            "--file",
            article_file,
            "--repo",
            args.repo,
            "--branch",
            args.branch,
        ]
        if devto_key:
            publish_args.extend([DEVTO_FLAG_NAME, devto_key])
        if dry_run:
            publish_args.append("--dry-run")

        status = devto_publish.main(publish_args)
        if status:
            return status
        time.sleep(args.delay)

    return 0


def has_article_diff() -> bool:
    result = run_git(["diff", "--quiet", "--", "articles"], check=False)
    return result.returncode != 0


def command_commit_metadata(args: argparse.Namespace) -> int:
    if os.environ.get("ACT") == "true":
        print("Running under act; skipping metadata commit step.")
        return 0

    if not has_article_diff():
        print("No metadata changes to commit.")
        return 0

    run_git(["config", "user.name", args.git_user_name])
    run_git(["config", "user.email", args.git_user_email])
    run_git(["add", "articles"])
    run_git(["commit", "-m", args.message])
    run_git(["push", "origin", f"HEAD:{args.branch}"])
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="GitHub Actions helper for DEV.to publishing"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    changed = subparsers.add_parser("changed", help="Compute changed article files")
    changed.add_argument("--event-name", required=True)
    changed.add_argument("--before", required=True)
    changed.add_argument("--sha", required=True)
    changed.add_argument("--changed-file", default=".changed_articles")
    changed.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    changed.set_defaults(func=command_changed)

    publish = subparsers.add_parser(
        "publish", help="Publish changed articles to DEV.to"
    )
    publish.add_argument("--changed-file", default=".changed_articles")
    publish.add_argument("--devto-key", default="")
    publish.add_argument("--repo", required=True)
    publish.add_argument("--branch", required=True)
    publish.add_argument("--delay", default=2, type=float)
    publish.add_argument("--dry-run", action="store_true")
    publish.set_defaults(func=command_publish)

    commit_metadata = subparsers.add_parser(
        "commit-metadata", help="Commit DEV.to metadata changes"
    )
    commit_metadata.add_argument("--branch", required=True)
    commit_metadata.add_argument(
        "--message", default="chore(devto): sync article metadata [skip ci]"
    )
    commit_metadata.add_argument("--git-user-name", default="github-actions[bot]")
    commit_metadata.add_argument(
        "--git-user-email",
        default="41898282+github-actions[bot]@users.noreply.github.com",
    )
    commit_metadata.set_defaults(func=command_commit_metadata)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
