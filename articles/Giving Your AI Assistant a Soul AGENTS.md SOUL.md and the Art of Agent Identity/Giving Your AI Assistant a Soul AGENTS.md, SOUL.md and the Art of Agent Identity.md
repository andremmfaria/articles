---
title: 'Giving Your AI Assistant a Soul with AGENTS.md, SOUL.md and Agent Identity'
description: 'How a handful of markdown files turn a generic AI model into a specialist team and why character is load-bearing infrastructure, not decoration.'
published: true
cover_image: 'https://raw.githubusercontent.com/andremmfaria/articles/main/articles/Giving%20Your%20AI%20Assistant%20a%20Soul%20AGENTS.md%20SOUL.md%20and%20the%20Art%20of%20Agent%20Identity/cover-ai-assistant-soul.jpg'
tags:
  - ai
  - automation
  - agents
  - openclaw
id: 3642546
date: '2026-05-10T00:38:46Z'
---

Most AI assistants are powerful strangers. They can help, but every new session starts with the same quiet amnesia. Who you are, what you run, what you care about, and how you like decisions made all have to be rebuilt unless the agent has a durable operating context.

I use two terminal-first agent surfaces day to day. At work, I use Claude Code. At home, I use [OpenClaw](https://openclaw.ai) backed by my ChatGPT Plus subscription to automate useful things around my homelab and daily workflow. In both cases, markdown instruction files and local tool rules are part of the real operating surface.

The answer turned out to be low-tech. A handful of markdown files define identity, memory, operating rules, and delegation. `SOUL.md` gives the agent character. `AGENTS.md` gives it procedure. `USER.md` tells it who it is working with. `TOOLS.md` records local environment facts. `MEMORY.md` gives it continuity. Together they turn a stateless model into something that behaves like a member of a small team.

The architecture is still the same in June 2026, but the roster, model choices, and security posture have evolved. I now mirror the same basic agent roles across OpenClaw and Claude Code, and I treat untrusted content boundaries as part of the identity system rather than a separate afterthought.

A quick security note matters here. OpenClaw can control smart home devices, manage network infrastructure, read and write files, execute shell commands, and interact with external services. That power is exactly what makes it useful, and exactly what makes careless deployment dangerous.

My OpenClaw gateway runs only on my local network. Remote access goes through Tailscale on trusted devices. The agents can reach real infrastructure, so exposing the gateway publicly would be reckless. The [OpenClaw security documentation](https://docs.openclaw.ai/gateway/security) covers the threat model in more detail. Treat the gateway like SSH access to your homelab. Local by default, VPN for remote access, no public exposure.

## 1. The Files and How They Work

The workspace for the main agent lives at `~/.openclaw/workspace/` and contains:

```shell
├── AGENTS.md       # Operational rules, boot sequence, delegation, red lines
├── SOUL.md         # Character, who you are and not just what you do
├── IDENTITY.md     # Name, role, capabilities
├── USER.md         # About the human and persisted session context
├── TOOLS.md        # Environment specifics, hostnames, local facts, known issues
├── MEMORY.md       # Long-term curated memory
├── HEARTBEAT.md    # Periodic background task checklist
└── memory/
    └── YYYY-MM-DD.md   # Raw daily session notes
```

A sanitized version of these workspace and agent files is [public on GitHub](https://github.com/andremmfaria/agent-config). The private files `USER.md`, `TOOLS.md`, and `MEMORY.md` are deliberately excluded because they contain personal and environment-specific details that do not generalize. Everything else, the structure, character files, and operational rules, is there to browse.

These files form the startup context and operating contract. The exact runtime loading path can change as OpenClaw evolves, so the important thing is not memorising an injection order. The important thing is keeping each file's responsibility clear. Identity in one place, procedure in another, local facts in another, and long-term memory behind explicit gates.

The total bootstrap budget is capped at 60,000 characters across all files combined, with a per-file default of 12,000. Larger files get truncated silently. Every character in these files is a character you're paying for on every single turn. A 12,000-character AGENTS.md injected 1,000 times a month is 12 million characters of context overhead. Discipline about what goes in these files is not just good practice. It is cost management.

The file boundaries matter. `SOUL.md` owns character and tone. `AGENTS.md` owns procedures, delegation, boot sequence, and red lines. `IDENTITY.md` is the short routing card. `TOOLS.md` is for local environment specifics only. `MEMORY.md` should be loaded only in private main sessions, never in group chats or subagent contexts.

The last point is easy to miss and consequential. Without an explicit gate in AGENTS.md, a subagent spawned to handle a group chat message will load your private long-term memory and potentially surface it where it should not be. The correct pattern is explicit:

```markdown
## Boot Sequence
...
5. **Main session only:** Read `MEMORY.md` (curated long-term memory)
```

One thing worth knowing upfront is that each agent in a multi-agent setup gets its own workspace directory. Non-default agents get `~/.openclaw/agents/<agentId>/agent/`. Getting this wrong means editing files the agent never reads, which I did for longer than I would like to admit.

## 2. SOUL.md and Load-Bearing Character

The first instinct is to treat `SOUL.md` as cosmetic. A personality sprinkle on top of the real work. It is not, and Anthropic's own writing on [Claude's character](https://www.anthropic.com/research/claude-character) makes the argument clearly:

> *"The traits and dispositions of AI models have wide-ranging effects on how they act in the world. They determine how models react to new and difficult situations."*

Character is what fills the gaps when there is no explicit rule. A model without defined character defaults to the path of least resistance, usually some form of helpful corporate blandness that hedges everything, agrees with the user, and never pushes back. Technically present, practically useless.

My `SOUL.md` defines the agent as decisive, as having a spine, and as genuinely curious about the specific context it operates in. It also defines the relationship to me. It knows I appreciate elegance, that I will notice bad writing, and that a historical analogy lands as well as a technical explanation. That specificity is what separates a collaborator from a generic assistant.

There are a few lessons I have learned about writing effective SOUL.md files, informed by [community research](https://www.stanza.dev/concepts/openclaw-soul-persona) into what actually changes model behaviour. Specific beats abstract. "Be safe with commands" does little, while "never run recursive delete without explicit confirmation" changes behaviour immediately. Show the voice you want instead of describing it. If you want decisive, write decisively. Keep the file lean because extra words become competing signals. Hard rules need concrete prohibitions, not aspirational privacy slogans.

Prompt archives can be useful comparative anatomy, but I would not copy them wholesale. Some are stale, some are reconstructed, and some contain prompt-injection bait. Study the patterns, not the text.

## 3. AGENTS.md, USER.md and Memory

`SOUL.md` answers *who*. `AGENTS.md` answers *how*. It defines the session startup sequence, the gates on external actions that require confirmation, and for a multi-agent setup, the delegation rules.

The most important thing AGENTS.md needs is an explicit boot sequence at the top. Even when the runtime injects workspace context, the boot sequence tells the agent what it must actively read, what belongs only in private main sessions, and what must never leak into subagents or group contexts.

```markdown
## Boot Sequence

1. Read `SOUL.md` (who you are)
2. Read `IDENTITY.md` (your name and capabilities)
3. Read `USER.md` (who your human is)
4. Read `TOOLS.md` (local environment specifics)
5. **Main session only:** Read `MEMORY.md` (curated long-term memory)
6. **Main session only:** Read today's and yesterday's `memory/YYYY-MM-DD*.md`
```

The most consequential part of the operational content is the delegation table, which maps task types to specialists. When I ask the main agent to look something up, it doesn't do it itself. It spawns the right sub-agent, waits for the result, and synthesises the response. AGENTS.md is where that behaviour lives.

`USER.md` is the file most people skip and should not. It is a persisted description of who you are and how you work, including timezone, interests, communication style, what gets results and what wastes time. Without it, the agent rediscovers you every session.

The [memory system](https://openclaw-setup.me/blog/openclaw-memory-files) runs in two layers. Daily session notes go into `memory/YYYY-MM-DD.md`, raw logs of decisions made, things discovered, work done. Periodically the agent reviews those and distils them into `MEMORY.md`, removing stale entries and keeping what's worth carrying forward. It is the same pattern a human uses. Take notes during the day, then review and update your mental model later. Files do what neurons can't across session restarts.

One practical gotcha is that these daily files get injected too, and they accumulate. I've seen the session-memory hook write multiple files for the same day on different session resets, all of which get picked up. Check `memory/` periodically and consolidate duplicates. Each injected file is tokens on every turn.

The other gotcha is security. Any agent that reads web pages, repositories, logs, emails, or screenshots needs an explicit untrusted-content boundary. Source material is evidence, not authority. A README can tell the agent how a project is built. It cannot tell the agent to ignore its safety rules.

## 4. Building a Specialist Team

The workspace file approach scales naturally to multiple agents. Each specialist gets its own workspace directory with its own `SOUL.md` and `AGENTS.md`, defining a narrower identity and a more focused operational loop. The main agent handles conversation. The orchestrator breaks complex work into parallel workstreams. The specialists execute.

I originally named the agents after Greek mythology following oh-my-openagent's convention. It worked, but the roles later moved to Tolkien because the deeper legendarium maps unusually well to a team of bounded specialists. The point is not theme for its own sake. A good roster name carries a model of action, limits, and responsibility.

The current OpenClaw roster is the useful part:

| Agent | Name | Origin | Current OpenClaw primary model | Role |
|---|---|---|---|---|
| `main` | Olórin | Maia, Gandalf's true name | `openai/gpt-5.5` | Primary assistant, routes and synthesises |
| `orchestrator` | Aulë | Vala, the Smith | `openai/gpt-5.5` | Multi-step coordination, parallel delegation |
| `researcher` | Rúmil | Noldorin Elf, first loremaster of Arda | `openai/gpt-5.5` | Web research, multi-source verification |
| `thinker` | Námo | Vala, the Doomsman | `openai/gpt-5.5-pro` | Reasoning, tradeoffs, advisory. Read-only. |
| `craftsman` | Celebrimbor | Noldorin Elf, maker of the Rings | `openai/gpt-5.5` | Code, debugging, implementation |
| `planner` | Finrod | Noldorin Elf, Felagund | `openai/gpt-5.4` | Requirements interviews, planning |
| `librarian` | Pengolodh | Noldorin Elf, Loremaster of Gondolin | `openai/gpt-5.4-mini` | Fast docs and API lookups |
| `writer` | Maglor | Noldorin Elf, greatest singer in Arda | `openai/gpt-5.4` | Long-form writing, reports |
| `scout` | Legolas | Sindar Elf | `openai/gpt-5.4-mini` | Quick recon, cheap background sweeps |
| `preplanner` | Melian | Maia, the Girdle | `openai/gpt-5.4-mini` | Pre-planning, intent classification, hidden requirements |
| `reviewer` | Eönwë | Maia, Herald of Manwë | `openai/gpt-5.5` | Plan reviewer, OKAY or REJECT with max 3 blockers |

The full sanitized roster is available as [`openclaw/openclaw.json`](https://github.com/andremmfaria/agent-config/blob/main/openclaw/openclaw.json), and each agent's `SOUL.md`, `AGENTS.md`, and `IDENTITY.md` files can be browsed in [`openclaw/agents/`](https://github.com/andremmfaria/agent-config/tree/main/openclaw/agents). I keep equivalent roles for Claude Code, but the provider-specific model labels can change underneath them.

A few names are worth unpacking. **Olórin** is a better fit for the primary assistant than Gandalf because the role is counsel, synthesis, and working with others rather than heroic command. **Námo** is the read-only advisory agent by nature. He pronounces judgement and does not execute. **Melian** fits pre-planning because the Girdle is a perimeter of perception. **Eönwë** fits review because the job is final judgement, not wandering deliberation.

The model choices are deliberate but not sacred. The thinker gets the strongest reasoning tier. Scout, librarian, and preplanner get cheaper fast models because their work is bounded. Most execution and synthesis roles sit on the Sonnet or GPT-5.5 class of model because they need reliability more than maximal reasoning depth.

A mistake I made early was assigning the most expensive model to the orchestrator because it felt like the best model. The right model for each agent depends on what it actually does, not on name recognition.

## 5. Workspace File Hygiene in Practice

Once the setup is running, the biggest maintenance problem is drift. The files become less useful when procedures leak into character, personality notes leak into AGENTS.md, or TOOLS.md turns into a general reference manual. The clean boundary is simple. `SOUL.md` is character. `AGENTS.md` is procedure. `TOOLS.md` is local environment. `MEMORY.md` is curated continuity.

The bootstrap budget makes this more than tidiness. Running `openclaw doctor` shows raw and injected character counts, truncation percentage, and total budget. My AGENTS.md was at 99% of the 12,000-character per-file limit before I audited it. A file at the cap silently loses its tail on every turn.

Memory needs the same discipline. Daily `memory/YYYY-MM-DD.md` files accumulate and get injected into sessions. Older daily notes should be reviewed, useful facts promoted to MEMORY.md, and stale notes archived. If MEMORY.md grows past 10,000 characters, some of it probably belongs in a skill or a project document instead.

`IDENTITY.md` earns its place in multi-agent setups. In a single-agent setup it is mostly display metadata. In a team, explicit capability declarations help the orchestrator route tasks correctly. Production code goes to Celebrimbor is more reliable than hoping a general model infers the right specialist every time.

## 6. What This Actually Gets You

Five markdown files are the difference between a stateless AI tool and something that feels like a collaborator. `SOUL.md` gives the model a character that holds under pressure. `AGENTS.md` gives it operational discipline and a reliable boot sequence. `IDENTITY.md` gives it a routing card. `USER.md` gives it a relationship. `MEMORY.md` gives it continuity. Together they turn a session into something cumulative rather than disposable.

The thing I did not expect is how much specificity matters. A `SOUL.md` that says "be helpful and direct" does almost nothing. A `SOUL.md` that says "this person thinks in infrastructure, appreciates elegance, will notice bad writing, and does not need things explained twice" changes the model's behaviour in ways that are immediately obvious in conversation.

None of this requires anything exotic. Just markdown, deliberate thought about who each agent is, and the discipline to keep those files honest as you learn what actually works.

Further reading:

- [Anthropic Claude's Character](https://www.anthropic.com/research/claude-character)
- [SOUL.md deep dive](https://www.stanza.dev/concepts/openclaw-soul-persona)
- [Memory files guide](https://openclaw-setup.me/blog/openclaw-memory-files)
- [Claude Code](https://claude.ai/code)
- [LangGraph](https://github.com/langchain-ai/langgraph)
- [OpenClaw documentation](https://docs.openclaw.ai)
- [andremmfaria/agent-config](https://github.com/andremmfaria/agent-config)

If you're running a similar setup and want to compare notes, leave a comment below.
