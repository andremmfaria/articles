---
title: 'Your First AI Agent in the Terminal: A Guide for People Who Have Never Touched One'
description: 'You do not need to be a developer to run a real AI agent. This is the practical guide for getting from zero to a working agent in your terminal, on macOS or Windows, without assuming any prior experience.'
published: false
cover_image: ''
tags:
  - ai
  - agents
  - beginners
  - cli
id: 3979399
---

I have written two articles in this series for people who already use a terminal. One was about [giving an AI assistant a durable identity](https://dev.to/andremmfaria/giving-your-ai-assistant-a-soul-agentsmd-soulmd-and-the-art-of-agent-identity-52dn), covering memory files, character files, the works. The other was about hardening those agents against prompt injection (see my [hardening article](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb) for the full picture).

After both of those went out, several friends asked the same question in slightly different words: *"This sounds interesting. But I don't use the command line. Where do I even start?"*

This one is for them. And if you are reading this and you have never typed a command in your life, that is fine. You are exactly who this is written for.

---

## 1. Before we talk about the terminal, should you even bother?

Fair question. There are perfectly good ways to use AI without ever opening a terminal. I use the web version of Claude and ChatGPT regularly. They work. They are the right tool for a quick question, a draft email, or a brainstorming session. I am not going to pretend that typing commands is obviously superior.

Here is the honest tradeoff.

**Web interfaces are easier to start.** You go to a website, you type, you get an answer. No setup. No installation. The experience is polished and the guardrails are friendly.

**Terminal agents do things web interfaces cannot.** They can read and write files on your actual computer. They can run real commands, automate tasks across folders, and act on your machine rather than just talking to you about it. The power-user tools, the ones that developers actually reach for, are almost always terminal-first. If you have ever wanted an AI to actually touch your files, reorganize a folder, or find every document that mentions a specific name, that work happens in the terminal.

The short version: the web interface is the easier on-ramp. The terminal is where the interesting control lives. You do not have to choose permanently; plenty of people use both, depending on the job.

If you are reading this, you are probably curious enough to try the terminal. So let's go.

---

## 2. What the terminal actually is

The **terminal** (also called the **command line** or **shell**) is a window where you type instructions and the computer executes them. That is genuinely all it is. There is no mouse, no icons. You type a command, you press Enter, something happens.

**On macOS:** Open Spotlight by pressing `Command + Space`, type `Terminal`, and press Enter. A plain window with a cursor will appear. That blinking cursor is waiting for you to type something.

**On Windows:** Press the Windows key, type `PowerShell`, and click **Windows PowerShell**. A blue window opens. That is your terminal.

> **Linux users:** You already know how to open a terminal. The install commands shown here are for macOS and Windows. Linux is fully supported by both tools; check each tool's official docs for the one-liner.

The thing you will see in the terminal is called a **prompt**. On macOS it often looks like `yourname@MacBook ~ %`. On Windows it looks like `PS C:\Users\yourname>`. The prompt is just the terminal saying: *"I'm ready. What do you want to do?"*

You type a command. You press Enter. The terminal does it.

That is the whole model. You will use about five commands total in this guide.

---

## 3. Choosing your agent

There are two well-supported terminal AI agents worth knowing about. This guide covers both so you can choose based on what you already pay for.

**Claude Code**, made by Anthropic, the same company behind Claude. Requires a paid Claude plan (Pro or Max) or Anthropic API credits. The free Claude.ai plan does not work with Claude Code; this is a hard requirement, not a warning to ignore.

**OpenAI Codex CLI**, made by OpenAI. Works with a ChatGPT Plus, Pro, or Business subscription, or an OpenAI API key.

Pick the one that matches an account you already have. Both work well. Both do essentially the same thing at this level.

---

## 4. Installing your agent

You only need to do this once. Paste the command for your system, press Enter, and let it run. These commands reach out to the official servers and install the tool automatically.

### Claude Code

**macOS (Terminal):**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

If you prefer using Homebrew (a popular macOS package manager; if you don't have it, use the curl command above):

```bash
brew install --cask claude-code
```

**Windows (PowerShell):**

```powershell
irm https://claude.ai/install.ps1 | iex
```

Or, if you have the Windows Package Manager (winget) installed:

```powershell
winget install Anthropic.ClaudeCode
```

Official docs: [code.claude.com/docs/en/setup](https://code.claude.com/docs/en/setup)

---

### OpenAI Codex CLI

**macOS (Terminal):**

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Or with Homebrew:

```bash
brew install --cask codex
```

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Official docs: [developers.openai.com/codex/cli](https://developers.openai.com/codex/cli)

> **A note on Windows:** PowerShell has a security feature called execution policy that can block scripts from running. The Codex command above already handles this with `-ExecutionPolicy ByPass`. Claude Code's installer handles it automatically too. Both native installers will also set up your system PATH (the list of places Windows looks for commands) without you having to do anything extra. If something does not work, the official docs are the first place to check. Installation steps can change, and the docs will always be more current than any article.
>
> **A note on Node.js for Codex:** Codex CLI works best with Node.js version 22 or later. On most modern systems it will either be present already or the installer will prompt you. You do not need to understand what Node.js is. If the installer asks about it, follow the prompt.

---

## 5. Signing in

Once the tool is installed, you start it with a single command. This will open your browser for a normal login, just like signing into any website.

### Signing into Claude Code

```bash
claude
```

Type `claude` and press Enter. Your browser opens to Anthropic's login page. Sign in with your Anthropic account (the one associated with your Claude Pro or Max plan). Come back to the terminal when it confirms you are logged in.

If you are using an API key instead of a subscription (advanced; skip this if unsure):

- **macOS:** `export ANTHROPIC_API_KEY=your-key-here`
- **Windows:** `$env:ANTHROPIC_API_KEY="your-key-here"` <!-- pragma: allowlist secret -->

### Signing into OpenAI Codex CLI

```bash
codex
```

Type `codex` and press Enter. Your browser opens to OpenAI's login page. Sign in with your ChatGPT account. Same pattern: authorize, come back to the terminal.

If you are using an API key:

- **macOS:** `export OPENAI_API_KEY=your-key-here`
- **Windows:** `$env:OPENAI_API_KEY="your-key-here"` <!-- pragma: allowlist secret -->

Once you are logged in, the agent is ready. You will see something like a prompt or a greeting in the terminal. At this point, you can just start talking to it in plain English, no special syntax required.

---

## 6. Three things to try first

Here are three tasks that work well for beginners. None of them require coding knowledge. Each one shows a different kind of thing a terminal agent can do that a web chat box cannot.

### 1. Summarize a folder of files

Say you have a folder of meeting notes, project documents, or downloaded articles you have been meaning to read. You can ask the agent to summarize them all at once.

In the terminal, navigate to the folder first (type `cd ~/Documents` to go to your Documents folder, for example), then ask:

```text
Summarize every text file in this folder and give me a one-paragraph overview of each.
```

The agent will read each file and give you a digest. This alone is worth the install.

### 2. Find and fix a recurring typo

If you have a folder of documents and you notice you always spelled someone's name wrong, or a product name changed, the agent can find every occurrence and fix it.

```text
Find every document in this folder that contains the word "Accme" and replace it with "Acme".
```

The agent will tell you what it found and what it changed, and ask for your confirmation before writing anything. (More on that in a moment.)

### 3. Ask it to explain something step by step

This is the simplest use and often the most useful. You can drop any text into the conversation, a confusing document, a technical email, a legal clause, and ask:

```text
Explain this to me like I've never worked in finance: [paste the text here]
```

The agent has the same language model under the hood as the web version, but now it can also reach out to your local files if you point it at them. Same brains, more reach.

---

## 7. A few words about staying safe

Here is something worth understanding before you go further: **a terminal agent can take real actions on your computer**. It can create files, delete them, rename things, run programs. That power is what makes it useful. It is also why you should not blindly click "yes" to everything it asks.

Most agents will pause and ask for your approval before doing anything consequential. Pay attention to those prompts. Read what it says it is about to do. If you are not sure, say no and ask it to explain first.

A few simple habits go a long way:

- **Work in a test folder first.** Create a new folder with some copies of files you do not care about. Try things there before pointing the agent at anything important.
- **Read before you approve.** If the agent asks "Can I delete these 12 files?", read the list. Make sure they are what you expected.
- **You can always say no.** Declining an action never breaks anything. The agent will wait for a revised instruction.

For a much deeper look at this, including why the file and memory structure of these agents matters for security, see my [hardening article](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb). That piece is where the second article in this series lands, and it is worth reading once you have the basics running.

---

## 8. A few useful commands

Once the agent is running interactively, you control it through conversation. But here are a couple of extra terminal commands worth knowing:

**Run a single task without starting a session:**

```bash
claude "summarize the file report.txt"
```

**Pick up where you left off in the last session (Claude Code):**

```bash
claude -c
```

**Quit the agent:** Press `Ctrl + C` (on both macOS and Windows) or type `/exit` if the tool supports it. The terminal does not break if you just close the window; it is fine.

---

## 9. Where to go next

If this worked and you are curious about going further:

- **The first article in this series** explains how to give your agent a persistent identity across sessions, covering memory files, character files, and why that matters: [Giving Your AI Assistant a Soul](https://dev.to/andremmfaria/giving-your-ai-assistant-a-soul-agentsmd-soulmd-and-the-art-of-agent-identity-52dn).
- **The second article** covers hardening the agent against malicious content that tries to manipulate it, relevant once you start pointing the agent at files and web pages you did not create.
- **Official documentation** is always more current than any article. Install steps and auth flows change. When in doubt: [Claude Code docs](https://code.claude.com/docs/en/setup) and [Codex CLI docs](https://developers.openai.com/codex/cli).

The terminal is less intimidating than it looks. You now know how to open it, install a tool, sign in, and ask for something useful. That is the whole foundation. Everything else is just practice.

If something breaks or you get stuck, leave a comment below. The install steps are the most likely thing to drift as these tools evolve, and I try to keep an eye on it.
