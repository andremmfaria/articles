# Articles → auto-published to DEV.to

This repository contains markdown articles that are automatically published to [dev.to/andremmfaria](https://dev.to/andremmfaria) using the `sinedied/publish-devto` GitHub Action.

## How it works

- On every push to `main` (or when triggered manually), a workflow runs the [`sinedied/publish-devto`](https://github.com/sinedied/publish-devto) action to publish or update markdown posts to DEV.to.
- The action also commits back metadata (like article IDs) to your markdown files so subsequent runs update instead of creating duplicates.

## Setup

1. In GitHub, add a repository secret named `DEV_TO_API_KEY` with your DEV.to API key (Settings → Secrets and variables → Actions → New repository secret).

1. Ensure articles include YAML front matter at the top. Minimum required field is `title`. Example:

```yaml
---
title: Continuous integration with containers and inceptions
tags: [ci, containers, devops]
published: true
canonical_url: https://slides.com/andremmfaria/inception#/  # optional
cover_image: https://example.com/cover.png                  # optional
series: Infrastructure Series                                # optional
# devto_id: 123456                                           # set automatically after first publish
---
```

Article markdown body starts here…

1. Push to `main` or run the workflow manually (Actions → “Publish articles to DEV.to” → Run workflow).

## Local upload

Publishing is handled by GitHub Actions, but for local testing or ad‑hoc publishes you can use the helper scripts in `scripts/`. Both PowerShell (`devto_test.ps1`) and Bash (`devto_test.sh`) are thin wrappers around a shared Python CLI (`devto_publish.py`). The wrappers add cross‑platform checks so the tooling works reliably on Windows and Linux (verifying Python installation, required inputs, and optional dry‑run behavior) and then forward flags to the Python core.

Wrapper behavior:

- `devto_test.ps1` and `devto_test.sh` check for Python (`python`/`python3`) in `PATH` and forward all flags to `devto_publish.py`.
- Both wrappers validate that the file exists and, unless `--dry-run`/`-DryRun` is set, an API key is provided via flag or `DEVTO_API_KEY`.
- Use `--dry-run`/`-DryRun` to print the payload JSON without sending to the API.

Common options (script‑agnostic; provided by `devto_publish.py` and used by both wrappers):

- File path: required (`-FilePath` in PowerShell, `--file` in Bash)
- API key: optional (`-ApiKey` or `--api-key`); defaults to `DEVTO_API_KEY` env var
- Publish: optional (`-Publish` or `--publish`); forces `published: true`
- Minimal: optional (`-Minimal` or `--minimal`); sends only `title`, `published`, `body_markdown`
- Remove headers: optional (`-RemoveHeaders` or `--remove-headers`); selectively omit optional fields `Cover,Tags,Description,CanonicalUrl,Series`

Behavior notes:

- Required fields (`title`, `published`, `body_markdown`) are always sent.
- In non‑minimal mode, optional fields present in front matter are included unless explicitly removed via the remove‑headers option.
- Cover removal via `Cover` replaces any prior `NoCover` behavior.

### Examples

PowerShell:

```powershell
# Publish with all optional fields present in front matter
./scripts/devto_test.ps1 -FilePath "articles/Continuous integration with containers and inceptions/Continuous integration with containers and inceptions.md" -Publish

# Minimal publish (helpful for troubleshooting 422s)
./scripts/devto_test.ps1 -FilePath "articles/Automate Ghydra installation/Automate Ghydra installation.md" -Publish -Minimal

# Omit tags and cover only
./scripts/devto_test.ps1 -FilePath "articles/Transparent LAGG (LACP) Bridge with OPNsense, UDM, and UniFi — A Practical Guide/Transparent LAGG (LACP) Bridge with OPNsense, UDM, and UniFi — A Practical Guide.md" -Publish -RemoveHeaders Tags,Cover

# Omit description and canonical URL
./scripts/devto_test.ps1 -FilePath "articles/Service metrics and its meanings/Service metrics and its meanings.md" -Publish -RemoveHeaders Description,CanonicalUrl
```

Shell:

```shell
# Publish with all optional fields present in front matter
./scripts/devto_test.sh --file "articles/Continuous integration with containers and inceptions/Continuous integration with containers and inceptions.md" --publish

# Minimal publish (helpful for troubleshooting 422s)
./scripts/devto_test.sh --file "articles/Automate Ghydra installation/Automate Ghydra installation.md" --publish --minimal

# Omit tags and cover only
./scripts/devto_test.sh --file "articles/Transparent LAGG (LACP) Bridge with OPNsense, UDM, and UniFi — A Practical Guide/Transparent LAGG (LACP) Bridge with OPNsense, UDM, and UniFi — A Practical Guide.md" --publish --remove-headers "Tags,Cover"

# Omit description and canonical URL
./scripts/devto_test.sh --file "articles/Service metrics and its meanings/Service metrics and its meanings.md" --publish --remove-headers "Description,CanonicalUrl"
```

### Pre-commit hooks

This repo uses [pre-commit](https://pre-commit.com/) to enforce simple hygiene and catch secrets:

Hooks configured:

- YAML validity (`check-yaml`)
- End-of-file newline (`end-of-file-fixer`)
- Trailing whitespace cleanup (`trailing-whitespace`)
- Secret detection (`detect-secrets`)
- Markdown lint (`markdownlint`, with long line rule MD013 disabled)

Install & activate:

```powershell
python -m pip install pre-commit
pre-commit install
```

Run on all files (e.g. after bulk edits):

```powershell
pre-commit run --all-files
```

If a hook fails, fix the reported issue and re-run. Some hooks auto-fix (e.g. trailing whitespace); just stage the changes again.

In CI, these hooks also run on pull requests (see `.github/workflows/pre-commit.yml`).

## Notes

- Only markdown files are considered. The top-level `README.md` is ignored.
- Front matter is optional; if missing, the first `#` heading becomes the title, but adding front matter is recommended to control tags, publish status, etc.
- The workflow file lives at `.github/workflows/publish.yml`.

## Troubleshooting

This section collects common failure modes and how to resolve them.

### Upload Errors

If publishing via the GitHub Action or direct API fails, check logs under Actions → “Publish articles to DEV.to”. Typical issues include front matter formatting, tag constraints, and cover image URLs.

#### DEV.to 422 (Unprocessable Entity)

When DEV.to returns `422`, validate these common issues:

- Tags: must be lowercase, alphanumeric only, and meet DEV.to constraints (max 4 tags; each 1–20 characters). Avoid spaces, punctuation, and symbols; use simple words like `malware`, `security`, `staticanalysis`. See DEV Community API docs: <https://developers.forem.com/api/v0#operation/createArticle>
- Cover image: use a reachable, publicly accessible URL (HTTPS). Prefer stable hosts (e.g., Wikimedia, GitHub user content). If in doubt, omit `cover_image` and try again.
- Front matter: ensure valid YAML at the top of the file delimited by `---` … `---`. Quote strings that contain special characters. YAML tips: <https://yaml.org/spec/>
- Required fields: at minimum `title` must be present. Start with a minimal payload (title + body + `published`) and reintroduce optional fields gradually.
- Tags formatting in array: when using inline YAML lists (`tags: [a, b, c]`), ensure components are simple tokens; for multiline lists, indent with two spaces under `tags:`.
- Publish flag: confirm `published: true` or `false` is a proper boolean (no quotes).

Suggested isolation steps:

1. Remove `tags`, `description`, `cover_image`, `canonical_url`, `series`, and set only `title` and `published`.
2. Publish; if it succeeds, add `description` next; then add `tags` (lowercase alphanumeric only, up to 4); finally add `cover_image`.
3. If `422` returns on adding `tags`, simplify to known-good tags (e.g., `malware`, `security`, `staticanalysis`, `devops`).
4. If `422` returns on adding `cover_image`, try a different host or omit it.

Example minimal front matter:

```yaml
---
title: I wanted to know how malware works, so I built an analyser
published: true
---
```

Example with tags (lowercase alphanumeric):

```yaml
---
title: I wanted to know how malware works, so I built an analyser
published: true
tags: [malware, security, staticanalysis]
---
```

### Fixing pre-commit hooks

If pre-commit fails locally or in CI:

- Install or update pre-commit: `python -m pip install --upgrade pre-commit`
- Install hooks: `pre-commit install`
- Run on all files: `pre-commit run --all-files`
- Auto-fixable issues (e.g., trailing whitespace) will modify files; re-stage and commit.
- Update hook versions by re-running: `pre-commit autoupdate` (then commit the updated `.pre-commit-config.yaml`).

Common hook fixes:

- YAML validity (`check-yaml`): ensure front matter is properly delimited and indented; validate with `yamllint` or an online YAML validator.
- Markdown lint (`markdownlint`): wrap long lines or disable MD013 in config; fix headings and list formatting per rule output. Docs: <https://github.com/DavidAnson/markdownlint>
- Secret detection (`detect-secrets`): remove secrets or add baseline updates after auditing. Docs: <https://github.com/Yelp/detect-secrets>

Resources:

- pre-commit documentation: <https://pre-commit.com/>
- GitHub Action used for publishing: <https://github.com/sinedied/publish-devto>
