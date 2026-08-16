---
title: Giving Your AI Agent Hands by Driving Your CLI Tools Safely
description: Your agent can already talk. This article is about giving it something to do by driving the CLI tools you already use safely, from gh to aws to acli, without memorizing every flag.
published: false
cover_image: 'https://raw.githubusercontent.com/andremmfaria/articles/main/articles/Giving%20Your%20AI%20Agent%20Hands/cover-ai-agent-hands.jpg'
tags:
  - ai
  - agents
  - cli
  - security
id: 3979775
---
Earlier in this series, the [first article in this series](https://dev.to/andremmfaria/giving-your-ai-assistant-a-soul-agentsmd-soulmd-and-the-art-of-agent-identity-52dn) gave the agent a durable identity, and the [second article](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb) hardened it against prompt injection. In the previous article, *Your First AI Agent in the Terminal*, I walked through getting a terminal agent running from scratch.

This article is the next step. Once an agent can drive the CLI tools already on your system, it stops being only a conversational assistant. It becomes a practical operator, with you as the reviewer and approver. That is the workflow I use agents for most.

## 1. From talking to operating

The series progression is straightforward. First the agent knows who it is and remembers useful context. Then it gets a safety boundary around hostile input. Then it runs in your terminal and can read your files. This article adds the part that changes the workflow most. The agent drives the tools already installed on your system.

Up until now, the agent is still mostly a very capable assistant. You ask it things and it tells you things. It might read a file or fetch a page, but you still open the AWS console, run the `gh` command, and look up your Jira tickets.

Once the agent can drive your CLI tools, you stop being the operator and start being the approver. Plain English becomes the front end. The flags, subcommands, and syntax become the agent's problem.

## 2. Your CLIs are the agent's hands

The insight here is obvious once you see it. `gh`, `aws`, `kubectl`, `docker`, `acli` are just programs. They read from standard input, accept flags, print to standard output, and return exit codes. The terminal agent can run them the same way you run them, because from the shell's perspective, there is no difference.

In practice, any CLI tool you have installed and authenticated becomes something the agent can drive. You describe what you want. The agent figures out the right invocation, runs it, reads the output, and either reports back or continues the task.

Here is a concrete example. I have a repo with several open feature branches. I want to see which ones are stale. I used to do something like this.

```bash
gh pr list --state open --json title,headRefName,updatedAt | jq '.[] | select(.updatedAt < "2026-01-01")'
```

Which requires me to remember whether it is `headRefName` or `branchName`, whether the date filter goes in `jq` or in a flag, and whether `jq` is even on this machine.

Now I just say, "Show me all open PRs that have not been updated since January."

The agent runs the equivalent query, handles the `jq` parsing or formats the output itself, and shows me a readable list. If I want to close them, I say so and it asks before acting.

That is the model. Plain English is the front end. The flags are the agent's problem.

I use Claude Code and Codex as the examples here, but the pattern also works with terminal agents such as [OpenCode](https://opencode.ai/docs), [OpenClaw](https://docs.openclaw.ai), [Aider](https://aider.chat/docs/), and [Ollama](https://docs.ollama.com). The permission mechanics differ by tool. The core idea does not. Let the agent drive installed CLIs, then make the risky steps explicit approval events.

## 3. Three things I actually rely on

### GitHub CLI opens a PR you would not have written yourself

I commit fairly often in short bursts. The problem is that good PR descriptions take longer to write than the commit itself, especially when the change spans a few unrelated fixes bundled into one branch because I was in a hurry. When I have something ready to ship, I say something like this.

```text
Open a PR for this branch. Look at the diff, write a sensible title and description,
and target main. Do not merge yet.
```

The agent inspects the diff with `git log` and `git diff`, drafts a description, then runs something like this.

```bash
gh pr create --title "Fix null check in auth middleware and update timeout defaults" \
  --body "..." \
  --base main
```

It shows me the draft before running. I read it, tweak the title if needed, and say go. The PR lands with a description that actually explains the change, which my teammates appreciate more than "wip fixes".

The install is straightforward.

```bash
# macOS
brew install gh

# Windows
winget install GitHub.cli
```

Then `gh auth login` to connect it to your account. Official docs are at [cli.github.com](https://cli.github.com).

### AWS CLI asks questions about infrastructure without touching anything

I have several S3 buckets, some from old side projects, and I periodically want to audit which ones have public access, which ones have no versioning, that sort of thing. I used to do this manually in the console. Now I ask this.

```text
Which of my S3 buckets have public access enabled? Just read, do not change anything.
```

The agent runs read-only queries to check.

```bash
aws s3api list-buckets --query "Buckets[].Name" --output text
aws s3api get-public-access-block --bucket <bucket-name>
```

It iterates over each bucket, checks the block-public-access settings, and reports back a clean summary. I never wrote the loop. I never looked up the flag name. I got the answer in about thirty seconds.

I want to be explicit about the "read-only" part. In this example, the agent is not changing anything. That is intentional. The safety section below covers why you want your destructive operations to require a separate, explicit approval step rather than flowing naturally from a casual ask.

AWS CLI setup starts by downloading and running the v2 installer from [awscli.amazonaws.com](https://awscli.amazonaws.com), then using `aws configure` to provide your key and region. Full guide at the [official docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

### Atlassian CLI turns tickets into a status update

This one saves me the most time on a weekly basis. My team uses Jira. I have anywhere from eight to fifteen open tickets at a given moment, across different epics and stages. Writing a coherent status update for a standup or a manager check-in requires me to mentally parse all of them, figure out what is blocked, what is done, and what I actually worked on.

I ask this.

```text
Summarize my open Jira tickets, group them by status, flag anything blocked,
and draft a two-paragraph status update I could send to my manager.
```

The agent uses `acli` to query my tickets with a JQL filter.

```bash
acli jira workitem list --jql "assignee = currentUser() AND status IN ('In Progress', 'To Do', 'Blocked')"
```

It reads the results, groups them, identifies the blocked ones, and writes the draft. I edit it for tone and send it. The whole thing takes two minutes instead of fifteen.

The exact subcommand and flags depend on your `acli` version and on whether you are on Jira Cloud or Data Center, so run `acli jira workitem --help` to see what your install supports. Atlassian CLI installation varies slightly by OS. Download the installer from [developer.atlassian.com/cloud/acli/guides/install-acli](https://developer.atlassian.com/cloud/acli/guides/install-acli/) and follow the auth setup for your product.

## 4. The part that matters is permissions and approval

This is the core of the article. The three examples above are useful. This section is why they are not dangerous.

An agent that can run `aws` can delete infrastructure. One that can run `gh` can push to main. One that can run `acli` can close tickets, modify issues, or post public comments. The access that makes these tools powerful is the same access that makes them worth constraining.

Claude Code checks tool calls against permission rules in order. Deny wins first, then Ask, then Allow, then the current permission mode. Global rules live in `~/.claude/settings.json`, project rules live in `.claude/settings.json`, and managed org settings sit above both.

Here is a sane starting config for `gh`, `aws`, and `git`.

```json
{
  "permissions": {
    "allow": [
      "Bash(gh pr list *)",
      "Bash(gh pr view *)",
      "Bash(aws s3 ls *)",
      "Bash(aws s3api get-*)",
      "Bash(aws s3api list-*)",
      "Bash(git status *)",
      "Bash(git log *)",
      "Bash(git diff *)"
    ],
    "ask": [
      "Bash(gh pr create *)",
      "Bash(gh pr merge *)",
      "Bash(aws *)",
      "Bash(git push *)",
      "Bash(git commit *)"
    ],
    "deny": [
      "Bash(aws s3 rb *)",
      "Bash(aws s3 rm *)",
      "Bash(rm -rf *)",
      "Bash(git push --force *)"
    ]
  }
}
```

The allow list covers read-only operations. The ask list covers mutations that need a human in the loop. The deny list covers things that should not happen during normal agent work. Specific allow rules should come before broader ask rules, because evaluation stops at the first match.

Claude's useful permission modes are:

- `default` asks before file edits or shell commands and is a reasonable baseline.
- `plan` lets the agent explore and propose a plan before touching files.
- `auto` approves most things but relies on a safety classifier for high-risk operations.
- `bypassPermissions` skips checks and only belongs inside a disposable container or VM.

Codex CLI is simpler. The interactive REPL prompts before commands by default, while `codex exec` relies on sandbox levels such as `workspace-write` or `danger-full-access`. OS-native sandboxing backs this on macOS and Linux. For reusable permission policy, Claude Code is currently the more expressive tool.

Full Claude Code permissions reference is at [code.claude.com/docs/en/permissions](https://code.claude.com/docs/en/permissions).

## 5. Skills turn a repeated ask into a reusable capability

The examples in section 3 are things I do regularly. Typing the same prompt variations every time is tedious and inconsistent. Claude Code has a feature built for exactly this called Skills.

A **Skill** is a `SKILL.md` file with YAML frontmatter and a markdown body describing the task. Here is a minimal version of the PR workflow.

```text
.claude/skills/create-pr/SKILL.md
```

```yaml
---
name: create-pr
description: Open a pull request for the current branch with a description generated from the diff
allowed-tools: Bash(git log *) Bash(git diff *) Bash(gh pr create *)
---

## Instructions

1. Run `git log --oneline origin/main..HEAD` to see the commits on this branch.
2. Run `git diff origin/main` to inspect the changes.
3. Write a clear PR title and description based on what you find.
4. Run `gh pr create` with the draft. Do not merge. Do not push.
5. Show me the PR link when done.
```

The `allowed-tools` frontmatter pre-approves only the listed commands for this skill. That is the key difference from typing the same prompt every session. The permission scope is packaged with the task, versioned alongside your project, and applied consistently.

Skills are not limited to git or cloud tools. I also use one around [pandoc](https://pandoc.org) to convert markdown reports to PDF. The shape is the same. A description tells the agent when to use it, `allowed-tools` limits execution to `pandoc`, and the instructions tell it to report missing PDF engines instead of guessing. The full options stay in the [pandoc manual](https://pandoc.org/MANUAL.html), where they belong.

Claude discovers skills by fuzzy-matching the `description` field, or you can invoke one explicitly with a slash command. Personal skills live under `~/.claude/skills/<name>/SKILL.md`. Project skills live under `.claude/skills/<name>/SKILL.md`. Enterprise and plugin-provided skills sit above or beside those depending on your setup.

A skill makes sense when you have done the same task three or more times and know its shape. The PR workflow, the S3 audit, and the weekly status update qualify. Exploratory work is better as a direct prompt. Do not over-skill. A skill you never invoke is just noise in your config.

The idea is not exclusive to Claude Code. OpenAI Codex CLI has [AGENTS.md and Agent Skills](https://developers.openai.com/codex/skills), [OpenCode](https://opencode.ai/docs) supports custom commands and agents, and [Aider](https://aider.chat/docs/) leans on config files plus in-chat commands. The format differs, but the goal is the same. Package a repeatable task together with the tools it is trusted to run.

Claude Code Skills reference is at [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills).

## 6. Staying safe when the agent can touch real things

Let me be direct about the risk model.

Once you wire up `aws`, `gh`, and `acli`, the agent has the same access you do. Your IAM credentials, GitHub token, and Atlassian session authorize the agent's commands the same way they authorize yours. The agent does not need to steal them. It just runs commands. That means a confused or manipulated agent can do real damage. Not because it is malicious. Because it is capable.

Anthropic's auto-mode classifier blocks categories of high-risk operations such as production deploys and migrations, mass cloud-storage deletion, permission grants in IAM or repositories, force pushes and pushes to main, destructive infrastructure commands, and irreversible deletion of files that existed before the session.

That classifier is a useful last line of defense, not a substitute for the right rules. My recommended stance is:

1. Start with default mode plus explicit ask rules for every cloud and git mutation.
2. Use sandbox isolation in Claude Code and Codex CLI.
3. Switch to plan mode before deleting, replacing, or pushing to shared branches.
4. Use `bypassPermissions` only inside a container or VM.
5. Keep credentials at the proxy boundary and never paste them into the conversation.

Prompt injection matters more once the agent can run tools. A hostile README or Jira ticket body can become an instruction source unless the untrusted-content boundary from [Hardening AI Agents Against Prompt Injection with Boring Markdown](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb) is already in place. For the broader local-agent risk model, see [When Chat Turns into Control](https://dev.to/andremmfaria/when-chat-turns-into-control-security-lessons-from-running-a-local-ai-agent-21l0). Permission rules, sandboxing, and prompt-injection hardening are complementary, not alternatives.

The summary version is layered defense. Permission rules catch known-bad patterns. Sandbox isolation limits blast radius. The auto-mode classifier catches high-risk edge cases. Human review before destructive operations catches everything else.

## 7. Where to go next

If you want to keep building on this, start with these:

- [Giving Your AI Assistant a Soul](https://dev.to/andremmfaria/giving-your-ai-assistant-a-soul-agentsmd-soulmd-and-the-art-of-agent-identity-52dn) covers persistent identity, memory files, and the agent roster that underlies everything here.
- [Hardening AI Agents Against Prompt Injection with Boring Markdown](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb) covers the untrusted-content boundary that should be in place before you point an agent at real tools.
- [When Chat Turns into Control](https://dev.to/andremmfaria/when-chat-turns-into-control-security-lessons-from-running-a-local-ai-agent-21l0) covers the wider security model for local AI agents with real tool access.
- *Your First AI Agent in the Terminal* covers install, auth, and first tasks.

Official documentation worth bookmarking:

- [Claude Code Skills](https://code.claude.com/docs/en/skills)
- [Claude Code Permissions](https://code.claude.com/docs/en/permissions)
- [OpenAI Codex CLI](https://developers.openai.com/codex/cli)
- [GitHub CLI](https://cli.github.com)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Atlassian CLI](https://developer.atlassian.com/cloud/acli/guides/install-acli/)

The thing I hope this series has shown is that these tools are not magic and they are not toys. They are capable, they have real access, and they reward the people who take five minutes to understand how they work before trusting them with something they care about. The five minutes is worth it.
