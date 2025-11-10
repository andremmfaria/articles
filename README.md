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

## Local development

The publishing is handled entirely by the GitHub Action; there is no local script to run. You can still use pre-commit hooks locally to keep files tidy and valid.

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
