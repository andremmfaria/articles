---
title: 'Giving Your AI Agent Hands: Driving Your CLI Tools Safely'
description: 'Your agent can already talk. This article is about giving it something to do: driving the CLI tools you already use, from gh to aws to acli, safely and without memorizing every flag.'
published: false
cover_image: 'https://cdn.sanity.io/images/7p2whiua/production/6b12b0331c52caad4f4be4a8f5cabc4f9ecc968d-2048x1536.jpg'
tags:
  - ai
  - agents
  - cli
  - security
id: 3979775
---

In the [first article in this series](https://dev.to/andremmfaria/giving-your-ai-assistant-a-soul-agentsmd-soulmd-and-the-art-of-agent-identity-52dn), I gave my agent a durable identity: memory files, a character file, and a roster of specialists led by an orchestrator named Aulë that delegates to focused agents like Celebrimbor for writing code, Rúmil for research, and Námo for the harder design calls. In the [second](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb), I hardened that agent against prompt injection, because an agent that can act is also an agent that can be manipulated.

<!-- TODO: link article #3 once published -->
In the previous article, *Your First AI Agent in the Terminal*, I walked through getting a terminal agent running from scratch. That one was written for people who had never opened a terminal. This one is written for people who have, and who are wondering what comes next.

This is that next step. And it is, genuinely, the thing I use agents for most.

---

## 1. From talking to operating

Here is the progression I have noticed across the series.

Article one: the agent knows who it is and remembers things between sessions. Useful for consistency.

Article two: the agent is hardened against malicious input. Useful for safety.

Article three: the agent runs in your terminal and can read your files. Useful for reach.

This article: the agent drives the tools that are already on your system. That is useful in a way the others are not, because it changes the nature of the interaction.

Up until now, the agent is still mostly a very capable assistant. You ask it things; it tells you things. It might read a file or fetch a page. But you are still the one who opens the AWS console, runs the `gh` command, looks up your Jira tickets.

Once the agent can drive your CLI tools, you stop being the operator and start being the approver. Plain English becomes the front end. The flags, subcommands, and syntax become the agent's problem.

That shift in my own workflow is what this article is about.

---

## 2. Your CLIs are the agent's hands

The insight here is obvious once you see it: `gh`, `aws`, `kubectl`, `docker`, `acli` are just programs. They read from standard input, accept flags, print to standard output, and return exit codes. The terminal agent can run them the same way you run them, because from the shell's perspective, there is no difference.

What this means in practice: any CLI tool you have installed and authenticated becomes something the agent can drive. You describe what you want. The agent figures out the right invocation, runs it, reads the output, and either reports back or continues the task.

Here is a concrete example. I have a repo with several open feature branches. I want to see which ones are stale. I used to do something like:

```bash
gh pr list --state open --json title,headRefName,updatedAt | jq '.[] | select(.updatedAt < "2026-01-01")'
```

Which requires me to remember whether it is `headRefName` or `branchName`, whether the date filter goes in `jq` or in a flag, and whether `jq` is even on this machine.

Now I just say: "Show me all open PRs that have not been updated since January."

The agent runs the equivalent query, handles the `jq` parsing or formats the output itself, and shows me a readable list. If I want to close them, I say so and it asks before acting.

That is the model. Plain English is the front end. The flags are the agent's problem.

A note on the agent itself: I use Claude Code and Codex as the examples throughout this article, but the same pattern works with other terminal agents, including [OpenCode](https://opencode.ai/docs), [OpenClaw](https://docs.openclaw.ai), [Aider](https://aider.chat/docs/), and [Ollama](https://docs.ollama.com) for running models locally. The permission and safety mechanics in the next sections are specific to Claude Code and Codex, so check your tool's own docs for the equivalents, but the core idea of letting an agent drive your installed CLIs carries across all of them.

---

## 3. Three things I actually rely on

### GitHub CLI: opening a PR you would not have written yourself

I commit fairly often in short bursts. The problem is that good PR descriptions take longer to write than the commit itself, especially when the change spans a few unrelated fixes bundled into one branch because I was in a hurry.

When I have something ready to ship, I say something like:

```text
Open a PR for this branch. Look at the diff, write a sensible title and description,
and target main. Do not merge yet.
```

The agent inspects the diff with `git log` and `git diff`, drafts a description, then runs something like:

```bash
gh pr create --title "Fix null check in auth middleware and update timeout defaults" \
  --body "..." \
  --base main
```

It shows me the draft before running. I read it, tweak the title if needed, and say go. The PR lands with a description that actually explains the change, which my teammates appreciate more than "wip: fixes".

The install is straightforward:

```bash
# macOS
brew install gh

# Windows
winget install GitHub.cli
```

Then `gh auth login` to connect it to your account. Official docs: [cli.github.com](https://cli.github.com).

### AWS CLI: asking questions about your infrastructure without touching anything

I have several S3 buckets, some from old side projects, and I periodically want to audit which ones have public access, which ones have no versioning, that sort of thing. I used to do this manually in the console. Now I ask:

```text
Which of my S3 buckets have public access enabled? Just read, do not change anything.
```

The agent runs read-only queries to check:

```bash
aws s3api list-buckets --query "Buckets[].Name" --output text
aws s3api get-public-access-block --bucket <bucket-name>
```

It iterates over each bucket, checks the block-public-access settings, and reports back a clean summary. I never wrote the loop. I never looked up the flag name. I got the answer in about thirty seconds.

I want to be explicit about the "read-only" part. In this example, the agent is not changing anything. That is intentional. The safety section below covers why you want your destructive operations to require a separate, explicit approval step rather than flowing naturally from a casual ask.

AWS CLI setup: download the v2 installer from [awscli.amazonaws.com](https://awscli.amazonaws.com), run it, then `aws configure` to provide your key and region. Full guide at the [official docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

### Atlassian CLI: turning a pile of tickets into a status update

This one saves me the most time on a weekly basis.

My team uses Jira. I have anywhere from eight to fifteen open tickets at a given moment, across different epics and stages. Writing a coherent status update for a standup or a manager check-in requires me to mentally parse all of them, figure out what is blocked, what is done, and what I actually worked on.

I ask:

```text
Summarize my open Jira tickets, group them by status, flag anything blocked,
and draft a two-paragraph status update I could send to my manager.
```

The agent uses `acli` to query my tickets with a JQL filter:

```bash
acli jira workitem list --jql "assignee = currentUser() AND status IN ('In Progress', 'To Do', 'Blocked')"
```

It reads the results, groups them, identifies the blocked ones, and writes the draft. I edit it for tone and send it. The whole thing takes two minutes instead of fifteen.

The exact subcommand and flags depend on your `acli` version and on whether you are on Jira Cloud or Data Center, so run `acli jira workitem --help` to see what your install supports. Atlassian CLI installation varies slightly by OS; download the installer from [developer.atlassian.com/cloud/acli/guides/install-acli](https://developer.atlassian.com/cloud/acli/guides/install-acli/) and follow the auth setup for your product.

---

## 4. The part that matters: permissions and approval

This is the core of the article. The three examples above are useful. This section is why they are not dangerous.

An agent that can run `aws` can delete infrastructure. One that can run `gh` can push to main. One that can run `acli` can close tickets, modify issues, or post public comments. The access that makes these tools powerful is the same access that makes them worth being careful with.

Claude Code has a layered permission model. Understanding it is not optional once you start pointing the agent at real tools.

**How permission evaluation works:** every tool call is checked against a rule list in order: Deny first, then Ask, then Allow, then a mode-dependent default. First match wins. If something is in Deny, it never runs, regardless of anything else. If it is in Ask, the agent pauses and asks you. If it is in Allow, it proceeds without prompting.

**Where the rules live:** `~/.claude/settings.json` applies to all your projects. `.claude/settings.json` inside a project applies to that project. Both use the same shape. Org-managed settings, if your employer provides them, cannot be overridden by either.

Here is a sane starting config for someone working with `gh`, `aws`, and `git`:

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

The allow list covers read-only operations that should flow without interruption. The ask list covers mutations that need a human in the loop. The deny list covers things that should never happen without you explicitly overriding.

One nuance worth knowing: `Bash(aws s3api get-*)` matches any command starting with `aws s3api get-`. A space before the `*`, as in `Bash(git status *)`, adds a word boundary, so the prefix only matches as a whole word: `Bash(ls *)` matches `ls -la` but not `lsof`, while `Bash(ls*)` would match both. The more specific allow rules at the top take precedence over the broader `aws *` in the ask list, because evaluation stops at the first match.

**Permission modes** give you a global stance independent of the rule list. The useful ones:

- `default`: reads never prompt, but the agent asks before any file edit or shell command. A reasonable baseline.
- `plan`: the agent reads files and runs read-only commands to explore, then proposes a plan without editing anything. Good for seeing the approach it intends to take before it touches your files.
- `auto`: approves most things, with a background safety classifier filtering out high-risk operations. The classifier catches things like production deploys, mass storage deletion, IAM changes, force pushes, and `terraform destroy`. The Anthropic docs note explicitly that auto mode "is not suitable for high-stakes infrastructure without human oversight." That quote is worth keeping in mind.
- `bypassPermissions`: skips all checks. Only use this inside a container or VM where the blast radius is bounded.

Protected paths that never get auto-approved regardless of mode: `.git`, `.claude`, your shell config files, editor config directories. The circuit breaker on root and home directory deletions also stays active even in permissive modes.

**Codex CLI's approach** is simpler. The interactive `codex` REPL prompts before every command by default. For non-interactive use, `codex exec` runs without prompting, and you bound what it can touch with sandbox levels such as `--sandbox workspace-write` (the restricted default) or `--sandbox danger-full-access`. OS-native sandboxing backs this: Seatbelt on macOS, Bubblewrap on Linux.

The reusable permission configuration in Claude Code (described below) does not have a direct equivalent in Codex CLI. For sophisticated permission setups, Claude Code is currently the better fit.

Full Claude Code permissions reference: [code.claude.com/docs/en/permissions](https://code.claude.com/docs/en/permissions).

---

## 5. Skills: turning a repeated ask into a reusable capability

The three examples in section 3 are things I do regularly. Typing the same prompt variations every time is tedious and inconsistent. Claude Code has a feature built for exactly this: Skills. I am using Claude Code as the example throughout this section, but the feature is not unique to it; the other agent CLIs have their own equivalents, which I list at the end.

A **Skill** is a `SKILL.md` file with YAML frontmatter and a markdown body describing the task. Here is a minimal example for the PR creation workflow:

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

The `allowed-tools` frontmatter pre-approves the listed commands for this skill. When the skill runs, those specific commands do not prompt, because I have already made the trust decision at definition time rather than at execution time. That is the key difference from just typing the same prompt every session: the permission scope is packaged with the task description, versioned alongside your project, and applied consistently.

Skills are not limited to git and cloud tools. Another one I lean on wraps [pandoc](https://pandoc.org), the universal document converter, so I can turn a markdown report into a polished PDF without remembering its flags:

```yaml
---
name: md-to-pdf
description: Convert a markdown file to a PDF using pandoc
allowed-tools: Bash(pandoc *)
---

## Instructions

1. Run `pandoc` to convert the given markdown file to PDF, choosing a sensible PDF engine.
2. If pandoc reports a missing PDF engine, tell me what to install rather than guessing.
3. Show me the output path once the file is written.
```

The shape is identical to the PR skill: a description so the agent knows when to reach for it, a tight `allowed-tools` list so it can only run `pandoc`, and a few plain-language steps. The full pandoc options live in its [manual](https://pandoc.org/MANUAL.html); the point of the skill is that I never have to open it.

**Discovery:** Claude auto-detects skills by fuzzy-matching the `description` field when you describe a task. If I say "create a PR for this branch," it may recognize the skill without me naming it. I can also invoke it explicitly with `/create-pr`.

**Where skills live and their precedence:**

- `~/.claude/skills/<name>/SKILL.md`: personal skills, available across all your projects
- `.claude/skills/<name>/SKILL.md`: project skills, scoped to that repo
- Enterprise-managed and plugin-provided skills also exist in Claude Code's skill hierarchy

Precedence goes Enterprise over Personal over Project. A personal skill with the same name as a project skill wins. Worth keeping in mind when you share a project with a team. Plugin-provided skills sit under their own namespace, so they do not collide with the ones you write.

**When to use a skill vs a one-off prompt:** a skill makes sense when you have done the same thing three or more times and know the shape of it. The PR workflow, the S3 audit, the weekly status update: those are skills. An exploratory ask where you are not sure what you want yet is better as a direct prompt. Do not over-skill; a skill you never invoke is just noise in your config.

Skills, as described here, are a Claude Code feature, but the idea is not exclusive to it. If you use a different agent, look for its own reusable-instruction harness. OpenAI Codex CLI has [AGENTS.md and Agent Skills](https://developers.openai.com/codex/skills), [OpenCode](https://opencode.ai/docs) supports custom commands, rules, and agents, and [Aider](https://aider.chat/docs/) leans on a config file plus coding conventions and in-chat commands. The format differs from tool to tool, but the goal is the same: package a repeatable task, together with the tools it is trusted to run, so you are not reassembling it from scratch every session.

Claude Code Skills reference: [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills).

---

## 6. Staying safe when the agent can touch real things

Let me be direct about the risk model.

Once you wire up `aws`, `gh`, and `acli`, the agent has the same access you do. Your IAM credentials, your GitHub token, your Atlassian session: they authorize the agent's commands the same way they authorize yours. The agent does not need to steal them. It just runs commands.

This means a confused or manipulated agent can do real damage. Not because it is malicious. Because it is capable.

Anthropic's safety classifier in auto mode blocks a specific list of high-risk operations: production deploys and migrations, mass cloud-storage deletion, granting IAM or repository permissions, force-pushing to any branch, pushing to main, `git reset --hard`, `terraform destroy`, `pulumi destroy`, `cdk destroy`, and irreversible deletion of files that existed before the session started. These are the things that are hard or impossible to undo without a backup. The classifier catching them is a useful last line of defense, but it is not a substitute for having the right rules in place.

My recommended stance:

1. **Start with default mode plus an explicit ask rule for every cloud and git mutation.** The allow list covers reads. The ask list covers writes. The deny list covers the truly irreversible. Do not wait until something goes wrong to add the deny list.

2. **Use sandbox isolation.** Both Claude Code and Codex CLI support OS-level sandboxing. Enable it. It limits what a confused agent can do outside the working directory even if all your permission rules allow it.

3. **Review before destructive ops.** If the task involves deleting things, replacing things, or pushing to a shared branch, switch to `plan` mode first. Read the plan. Then give the go-ahead.

4. **Never use `bypassPermissions` outside a container or VM.** The only reasonable use of bypass mode is an isolated CI environment where the worst case is a broken build, not a broken production environment.

5. **Credentials stay at the proxy boundary.** Claude Code's sandboxing design wires repo tokens into the sandbox's git remote so push and pull work without the agent ever seeing the raw token. The agent issues the command; the credential is resolved outside its context. That is the right model. Do not manually paste credentials into the conversation.

The prompt injection angle matters here too. An agent that can run `aws` is a more valuable target for prompt injection than one that can only answer questions. If a hostile README or a Jira ticket body contains embedded instructions, you want the untrusted-content boundary from [article two](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb) in place before the agent runs anything against real infrastructure. The hardening work and the permission work are complementary, not alternatives.

The summary version: layered defense. Permission rules catch known-bad patterns. Sandbox isolation limits blast radius. The auto-mode classifier catches high-risk edge cases. Human review before destructive ops catches everything else.

---

## 7. Where to go next

If you want to keep building on this:

- [Giving Your AI Assistant a Soul](https://dev.to/andremmfaria/giving-your-ai-assistant-a-soul-agentsmd-soulmd-and-the-art-of-agent-identity-52dn) is article one: persistent identity, memory files, the agent roster that underlies everything here.
- [Hardening AI Agents Against Prompt Injection with Boring Markdown](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb) is article two: the untrusted-content boundary that should be in place before you point an agent at real tools.
- <!-- TODO: link article #3 once published --> *Your First AI Agent in the Terminal* is article three: getting a terminal agent running from scratch, including install, auth, and first tasks.

Official documentation worth bookmarking:

- [Claude Code Skills](https://code.claude.com/docs/en/skills)
- [Claude Code Permissions](https://code.claude.com/docs/en/permissions)
- [OpenAI Codex CLI](https://developers.openai.com/codex/cli)
- [GitHub CLI](https://cli.github.com)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Atlassian CLI](https://developer.atlassian.com/cloud/acli/guides/install-acli/)

The thing I hope this series has shown is that these tools are not magic and they are not toys. They are capable, they have real access, and they reward the people who take five minutes to understand how they work before trusting them with something they care about.

The five minutes is worth it.
