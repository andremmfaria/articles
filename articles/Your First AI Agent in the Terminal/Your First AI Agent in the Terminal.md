---
title: 'Your First AI Agent in the Terminal: A Guide for People Who Have Never Touched One'
description: 'You do not need to be a developer to run a real AI agent. This is the practical guide for getting from zero to a working agent in your terminal, on macOS or Windows, without assuming any prior experience.'
published: false
cover_image: 'https://raw.githubusercontent.com/andremmfaria/articles/main/articles/Your%20First%20AI%20Agent%20in%20the%20Terminal/cover-terminal-ai-agent.png'
tags:
  - ai
  - agents
  - beginners
  - cli
id: 3979399
---

I have written two articles in this series for people who already use a terminal. One was about [giving an AI assistant a durable identity](https://dev.to/andremmfaria/giving-your-ai-assistant-a-soul-agentsmd-soulmd-and-the-art-of-agent-identity-52dn). The other was about [hardening agents against prompt injection](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb).

After both of those went out, several friends asked the same question in slightly different words. *"This sounds interesting. But I don't use the command line. Where do I even start?"*

This one is for them. And if you are reading this and you have never typed a command in your life, that is fine. You are exactly who this is written for.

## 1. Before we talk about the terminal, should you even bother?

Fair question. There are perfectly good ways to use AI without ever opening a terminal. I use the web version of Claude and ChatGPT regularly. They work. They are the right tool for a quick question, a draft email, or a brainstorming session. I am not going to pretend that typing commands is obviously superior.

Here is the honest tradeoff. Web interfaces are easier to start. You go to a website, you type, you get an answer. No setup, no installation, and friendly guardrails. Terminal agents do things web interfaces cannot. They can read and write files on your actual computer, run real commands, automate work across folders, and act on your machine rather than just talking to you about it.

The web interface is the easier on-ramp. The terminal is where the interesting control lives. You do not have to choose permanently. Plenty of people use both, depending on the job.

If you are reading this, you are probably curious enough to try the terminal. So let's go.

## 2. What the terminal actually is

The **terminal** (also called the **command line** or **shell**) is a window where you type instructions and the computer executes them. That is genuinely all it is. There is no mouse, no icons. You type a command, you press Enter, something happens.

On macOS, open Spotlight by pressing `Command + Space`, type `Terminal`, and press Enter. A plain window with a cursor will appear. That blinking cursor is waiting for you to type something.

On Windows, press the Windows key, type `PowerShell`, and click **Windows PowerShell**. A blue window opens. That is your terminal.

> **Linux users** already know how to open a terminal. The install commands shown here are for macOS and Windows. Linux is fully supported by both tools. Check each tool's official docs for the one-liner.

The thing you will see in the terminal is called a **prompt**. On macOS it often looks like `yourname@MacBook ~ %`. On Windows it looks like `PS C:\Users\yourname>`. The prompt is just the terminal saying *"I'm ready. What do you want to do?"*

You type a command. You press Enter. The terminal does it.

That is the whole model. You will use about five commands total in this guide.

## 3. Choosing your agent

There are two well-supported terminal AI agents worth knowing about. This guide covers both so you can choose based on what you already pay for.

**Claude Code**, made by Anthropic, the same company behind Claude. Requires a paid Claude plan (Pro or Max) or Anthropic API credits. The free Claude.ai plan does not work with Claude Code. This is a hard requirement, not a warning to ignore.

**OpenAI Codex CLI**, made by OpenAI. Works with a ChatGPT Plus, Pro, or Business subscription, or an OpenAI API key.

Pick the one that matches an account you already have. Both work well. Both do essentially the same thing at this level.

One more thing before we move on. Claude Code and Codex are not the only choices. Other terminal agents work the same way, including [OpenCode](https://opencode.ai/docs), [OpenClaw](https://docs.openclaw.ai), and [Ollama](https://docs.ollama.com), which runs models locally on your own machine. I am using Claude Code and Codex as the examples in this guide to keep things simple, but the steps translate directly.

## 4. Installing your agent

You only need to do this once. Paste the command for your system, press Enter, and let it run. These commands reach out to the official servers and install the tool automatically.

### Claude Code

#### Claude Code on macOS

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

If you prefer using Homebrew, use this:

```bash
brew install --cask claude-code
```

#### Claude Code on Windows

```powershell
irm https://claude.ai/install.ps1 | iex
```

Or, if you have the Windows Package Manager (winget) installed:

```powershell
winget install Anthropic.ClaudeCode
```

Official docs [code.claude.com/docs/en/setup](https://code.claude.com/docs/en/setup)

### OpenAI Codex CLI

#### Codex CLI on macOS

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Or with Homebrew:

```bash
brew install --cask codex
```

#### Codex CLI on Windows

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Official docs [developers.openai.com/codex/cli](https://developers.openai.com/codex/cli)

> **A note on Windows**. PowerShell has a security feature called execution policy that can block scripts from running. The Codex command above already handles this with `-ExecutionPolicy ByPass`. Claude Code's installer handles it automatically too. Both native installers will also set up your system PATH, the list of places Windows looks for commands. If something does not work, the official docs are the first place to check.
>
> **A note on Node.js for Codex**. Codex CLI works best with Node.js version 22 or later. On most modern systems it will either be present already or the installer will prompt you. You do not need to understand what Node.js is. If the installer asks about it, follow the prompt.

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

Type `codex` and press Enter. Your browser opens to OpenAI's login page. Sign in with your ChatGPT account, authorize the tool, and come back to the terminal.

If you are using an API key:

- **macOS:** `export OPENAI_API_KEY=your-key-here`
- **Windows:** `$env:OPENAI_API_KEY="your-key-here"` <!-- pragma: allowlist secret -->

Once you are logged in, the agent is ready. You will see something like a prompt or a greeting in the terminal. At this point, you can start talking to it in plain English.

## 6. Four things to try first

Here are four tasks that work well for beginners. None of them require coding knowledge.

### 1. Summarize a folder of files

Say you have a folder of meeting notes, project documents, or downloaded articles you have been meaning to read. Ask the agent to summarize them all at once.

In the terminal, navigate to the folder first (type `cd ~/Documents` to go to your Documents folder, for example), then ask:

```text
Summarize every text file in this folder and give me a one-paragraph overview of each.
```

The agent will read each file and give you a digest. This alone is worth the install.

You do not actually have to move into the folder first. Instead of using `cd`, you can tell the agent which folder to look in by handing it the **path**, which is the address of a folder on your computer. A path comes in two flavors:

- A **full path** spells out the complete address from the top of your drive, like `/Users/yourname/Documents/notes` on macOS or `C:\Users\yourname\Documents\notes` on Windows.
- A **relative path** is read from wherever you currently are in the terminal. If you are already in Documents, `./notes` points at the `notes` subfolder and `../taxes` points one level up.

So instead of changing folders, you can simply ask:

```text
Summarize every text file in /Users/yourname/Documents/notes and give me a one-paragraph overview of each.
```

Make sure the path is correct. The agent looks exactly where you point it.

### 2. Find and fix a recurring typo

If you have a folder of documents and you notice you always spelled someone's name wrong, or a product name changed, the agent can find every occurrence and fix it.

```text
Find every document in this folder that contains the word "Accme" and replace it with "Acme".
```

The agent will tell you what it found, what it changed, and ask for confirmation before writing anything.

### 3. Ask it to explain something step by step

This is the simplest use and often the most useful. Drop any text into the conversation and ask:

```text
Explain this to me like I've never worked in finance: [paste the text here]
```

The agent has the same language model under the hood as the web version, but now it can also reach local files if you point it at them. Same brains, more reach.

### 4. Fetch a web page, summarize it and write the result on disk

The agent is not limited to files on your computer. Give it a web address (a URL) and it can fetch the page and summarize it for you, which is handy for a long article, a documentation page, or release notes you do not feel like reading in full.

```text
Fetch https://en.wikipedia.org/wiki/Transmission_Control_Protocol, give me a summary of it I can understand it without a networking background, and write it to my downloads folder.
```

The agent reads the live page, hands back the digest, and writes it to the Downloads folder in your home folder, such as `C:/Users/yourname/Downloads` or `/Users/yourname/Downloads`. A web page is content you did not write, so treat anything it tells the agent to do with healthy suspicion.

## 7. A few words about staying safe

Here is something worth understanding before you go further. **A terminal agent can take real actions on your computer**. It can create files, delete them, rename things, and run programs. That power is what makes it useful. It is also why you should not blindly click "yes" to everything it asks.

Most agents will pause and ask for your approval before doing anything consequential. Read what it says it is about to do. If you are not sure, say no and ask it to explain first.

A few simple habits go a long way:

- **Work in a test folder first.** Create a new folder with some copies of files you do not care about. Try things there before pointing the agent at anything important.
- **Read before you approve.** If the agent asks "Can I delete these 12 files?", read the list. Make sure they are what you expected.
- **You can always say no.** Declining an action never breaks anything. The agent will wait for a revised instruction.

For a deeper look at this, including why the file and memory structure of these agents matters for security, see my [hardening article](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb).

## 8. A few useful commands

Once the agent is running interactively, you control it through conversation. A couple of extra terminal commands are worth knowing:

Run a single task without starting a session:

```bash
claude "summarize the file report.txt"
```

Pick up where you left off in the last session with Claude Code:

```bash
claude -c
```

**Quit the agent**. Press `Ctrl + C` on both macOS and Windows, or type `/exit` if the tool supports it. The terminal does not break if you just close the window.

## 9. Where to go next

If this worked and you are curious about going further:

- The first article in this series explains agent identity, memory files, character files, and why persistence matters. [Giving Your AI Assistant a Soul](https://dev.to/andremmfaria/giving-your-ai-assistant-a-soul-agentsmd-soulmd-and-the-art-of-agent-identity-52dn)
- The second article covers hardening agents against malicious content that tries to manipulate them. [Hardening AI Agents Against Prompt Injection with Boring Markdown](https://dev.to/andremmfaria/hardening-ai-agents-against-prompt-injection-with-boring-markdown-3jb)
- Official documentation is always more current than any article. Install steps and auth flows change. [Claude Code docs](https://code.claude.com/docs/en/setup) and [Codex CLI docs](https://developers.openai.com/codex/cli)

There is one more step where these agents really earn their keep. Once you have other command-line tools installed, the agent can drive them for you. Tools like the GitHub CLI (`gh`), the AWS CLI (`aws`), or an issue-tracker CLI such as `acli` are themselves just programs you run in the terminal, and the agent can run them on your behalf. You can say "open a pull request with my changes and a sensible description" and the agent translates that into the right `gh` commands.

That is genuinely powerful, and it is also where the safety habits above matter most, because now the agent can act on your code, your cloud account, and your tickets. That deserves its own follow-up article. For this guide, it is enough to know the door exists.

The terminal is less intimidating than it looks. You now know how to open it, install a tool, sign in, and ask for something useful. That is the whole foundation. Everything else is just practice.

If something breaks or you get stuck, leave a comment below. Install steps are the most likely thing to drift as these tools evolve, and I try to keep an eye on them.
