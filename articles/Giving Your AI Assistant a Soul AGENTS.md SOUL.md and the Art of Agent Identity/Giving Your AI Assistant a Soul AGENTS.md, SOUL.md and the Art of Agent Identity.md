---
title: 'Giving Your AI Assistant a Soul: AGENTS.md, SOUL.md and the Art of Agent Identity'
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

## 1. The Problem with Generic Assistants

Every AI assistant starts the same way: a powerful model with no memory, no personality, and no idea who you are or what you're building. You get capable but characterless. You ask it something, it helps, and tomorrow it's a stranger again. You find yourself re-explaining your stack, your preferences, your context every single session.

I wanted something different. Not a smarter search engine but a collaborator. One that knows I run a homelab on HAOS, that I think in infrastructure, that I care about elegance as much as correctness, and that I don't need things explained twice. The answer turned out to be surprisingly low-tech: a handful of markdown files injected into the model's context at the start of every session.

For context: at work I'm a heavy user of [OpenCode](https://opencode.ai), which has its own take on this through plugins like [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent). The homelab setup I'm describing here is inspired by that, but it's not the same thing. OpenCode is a coding-focused harness that runs locally against your codebase. What I built at home is a general-purpose assistant layer on top of a smart home and homelab, where the "codebase" is infrastructure, services, and daily life. Same underlying idea (give agents identity and purpose), different domain.

The mechanism is almost embarrassingly simple. At session start, [OpenClaw](https://openclaw.ai) reads a set of files from the agent's workspace directory and prepends them to the system prompt. Markdown in, context out. That's it. But what you put in those files determines fundamentally how the model behaves, not just what it knows, but how it thinks, when it pushes back, and what it notices without being asked.

A quick note on security before going further, because it's worth being direct about this. OpenClaw is genuinely powerful: it can control smart home devices, manage network infrastructure, read and write files, execute shell commands, and interact with external services. That power is exactly what makes it useful, and exactly what makes careless deployment dangerous. As Uncle Ben put it: with great power comes great responsibility.

The OpenClaw gateway runs exclusively on my local network and is not exposed to the internet. Remote access, when I need it, goes through Tailscale on trusted devices only. This matters because the agents have access to real infrastructure: smart home controls, network management, DNS, file systems. Giving a publicly accessible endpoint that level of access would be reckless. The [OpenClaw security documentation](https://docs.openclaw.ai/gateway/security) covers the threat model in detail and is worth reading before you give any agent access to anything you'd regret. If you're setting up something similar, treat the gateway like you'd treat SSH access to your homelab: local by default, VPN for remote, no public exposure.

---

## 2. The Files and How They Work

The workspace for the main agent lives at `~/.openclaw/workspace/` and contains:

```shell
├── AGENTS.md       # Operational rules: boot sequence, delegation, red lines
├── SOUL.md         # Character: who you are, not just what you do
├── IDENTITY.md     # Name, role, capabilities — routing metadata
├── USER.md         # About the human: persisted context across sessions
├── TOOLS.md        # Environment specifics: IPs, hostnames, credentials
├── MEMORY.md       # Long-term curated memory
├── HEARTBEAT.md    # Periodic background task checklist
└── memory/
    └── YYYY-MM-DD.md   # Raw daily session notes
```

Each of these files is injected verbatim into the system prompt before the model sees any user message. The injection order matters: `SOUL.md` → `IDENTITY.md` → `USER.md` → `AGENTS.md` → `TOOLS.md` → `MEMORY.md`. SOUL.md gets the model's highest attention — it sets the register for everything that follows.

The total bootstrap budget is capped at 60,000 characters across all files combined, with a per-file default of 12,000. Larger files get truncated silently. The practical implication: every character in these files is a character you're paying for on every single turn. A 12,000-character AGENTS.md injected 1,000 times a month is 12 million characters of context overhead. Discipline about what goes in these files is not just good practice; it's cost management.

There are also some important rules about what goes *where*:

- **SOUL.md** owns character and tone. Not procedures, not rules — just who the agent is.
- **AGENTS.md** owns procedures. Boot sequence, delegation tables, operational red lines.
- **IDENTITY.md** owns the routing card. Name, agent ID, capabilities list. Short by design.
- **TOOLS.md** owns local environment specifics — hostnames, credentials, known issues. Nothing that's the same across deployments.
- **MEMORY.md** should only be loaded in private main sessions — never in group chats or subagent contexts.

The last point is easy to miss and consequential. Without an explicit gate in AGENTS.md, a subagent spawned to handle a group chat message will load your private long-term memory and potentially surface it where it shouldn't be. The correct pattern is explicit:

```markdown
## Boot Sequence
...
5. **Main session only:** Read `MEMORY.md` — curated long-term memory
```

One thing worth knowing upfront: each agent in a multi-agent setup gets its own workspace directory. Non-default agents get `~/.openclaw/agents/<agentId>/agent/`. Getting this wrong means editing files the agent never reads, which I did for longer than I'd like to admit.

---

## 3. SOUL.md: Why Character is Load-Bearing

The first instinct is to treat `SOUL.md` as cosmetic. A personality sprinkle on top of the real work. It isn't, and Anthropic's own writing on [Claude's character](https://www.anthropic.com/research/claude-character) makes the argument clearly:

> *"The traits and dispositions of AI models have wide-ranging effects on how they act in the world. They determine how models react to new and difficult situations."*

Character is what fills the gaps when there's no explicit rule. A model without defined character defaults to the path of least resistance, which is usually some form of helpful corporate blandness that hedges everything, agrees with the user, and never pushes back. Technically present, practically useless.

My `SOUL.md` defines the agent as decisive (one recommendation with a reason, not three options with caveats), as having a spine (disagree when the premise is wrong, once, clearly, without lecturing), and as genuinely curious about the specific context it operates in. It also defines the relationship to me: it knows I appreciate elegance, that I'll notice bad writing, that a historical analogy lands as well as a technical explanation. That specificity is what separates a collaborator from a generic assistant.

There are a few lessons I've learned about writing effective SOUL.md files:

**Specific beats abstract.** "Be safe with commands" does nothing. "Never execute `rm -rf` without explicit confirmation — even if it seems obviously intended" changes behaviour immediately. Models follow concrete rules far more consistently than high-level principles.

**Show, don't tell.** Write the file in the voice you want the model to adopt. If you want decisive, write decisively. If you want dry wit, use it. The model will mirror the register of its own system prompt more reliably than it will follow an instruction to "be funny".

**Keep it lean.** The research-validated sweet spot is 200-500 words. More words don't improve adherence — brevity often improves it, because the model isn't parsing through competing signals. My SOUL.md is around 600 words and could still be trimmed.

**Hard rules need specificity.** Aspirational guidelines ("respect privacy") belong in the philosophy section. Actionable prohibitions ("never send external messages without explicit instruction for that specific message") belong in a Hard Rules section. Both are useful; only one changes what the model actually does under pressure.

If you want inspiration, the [dontriskit/awesome-ai-system-prompts](https://github.com/dontriskit/awesome-ai-system-prompts) repository has leaked and reverse-engineered prompts from Manus, Perplexity, Claude, GPT-4o, and others. It's a good way to see how production systems handle tone, refusals, and persona before writing your own.

---

## 4. AGENTS.md, USER.md and Memory: The Operational Layer

Where `SOUL.md` answers *who*, `AGENTS.md` answers *how*. It defines the session startup sequence, the gates on external actions that require confirmation, and for a multi-agent setup, the delegation rules.

The most important thing AGENTS.md needs that mine was missing for a long time: an explicit boot sequence at the top. OpenClaw doesn't auto-load everything — the agent follows the instructions in AGENTS.md. Without numbered steps telling it to read SOUL.md, then IDENTITY.md, then MEMORY.md, the loading order is undefined and context gets missed.

```markdown
## Boot Sequence

1. Read `SOUL.md` — who you are
2. Read `IDENTITY.md` — your name and capabilities
3. Read `USER.md` — who your human is
4. Read `TOOLS.md` — local environment specifics
5. **Main session only:** Read `MEMORY.md` — curated long-term memory
6. **Main session only:** Read today's and yesterday's `memory/YYYY-MM-DD*.md`
```

The most consequential part of the operational content is the delegation table: which task types route to which specialist. When I ask the main agent to look something up, it doesn't do it itself. It spawns the right sub-agent, waits for the result, and synthesises the response. AGENTS.md is where that behaviour lives.

`USER.md` is the file most people skip and shouldn't. It's a persisted description of who you are and how you work: timezone, interests, communication style, what gets results and what wastes time. Without it, the agent rediscovers you every session.

The memory system runs in two layers. Daily session notes go into `memory/YYYY-MM-DD.md`, raw logs of decisions made, things discovered, work done. Periodically the agent reviews those and distils them into `MEMORY.md`, removing stale entries and keeping what's worth carrying forward. It's the same pattern a human uses: take notes during the day, review and update your mental model later. Files do what neurons can't across session restarts.

One practical gotcha: these daily files get injected too, and they accumulate. I've seen the session-memory hook write multiple files for the same day on different session resets, all of which get picked up. Check `memory/` periodically and consolidate duplicates. Each injected file is tokens on every turn.

---

## 5. Building a Specialist Team

The workspace file approach scales naturally to multiple agents. Each specialist gets its own workspace directory with its own `SOUL.md` and `AGENTS.md`, defining a narrower identity and a more focused operational loop. The main agent handles conversation. The orchestrator breaks complex work into parallel workstreams. The specialists execute.

When I first built this, I named the agents after Greek mythology following oh-my-openagent's convention: Sisyphus, Atlas, Oracle, Hephaestus, Prometheus. It worked fine, but I recently went through a naming revision and switched to Tolkien — specifically figures from the Silmarillion, Unfinished Tales, and the broader legendarium. Not Tolkien in the sense of the Peter Jackson films or even The Lord of the Rings as most people know it, but the Professor's deeper world-building work: the Valar, the Maiar, the Noldorin Elves, the Ainulindalë. That material has been the subject of serious academic lore analysis, and it turns out the mythological roles map to agent functions with unusual precision.

The reason I made this choice is personal: I'm a genuine admirer of Tolkien's scholarly and world-building work, not just the popular adaptations. Reading the Silmarillion properly — not as backstory for LOTR but as its own mythology — reveals an extraordinarily structured pantheon where each figure has a specific domain, specific limits, and a specific relationship to action and knowledge. That structure is exactly what you want in an agent roster.

Here's the current team:

| Agent | Name | Origin | Model | Role |
|---|---|---|---|---|
| `main` | Olórin | Maia (Gandalf's true name) | claude-sonnet-4.6 | Primary assistant — routes, synthesises, interfaces |
| `orchestrator` | Aulë | Vala — the Smith | claude-sonnet-4.6 | Multi-step coordination, parallel delegation |
| `researcher` | Rúmil | Noldorin Elf — first loremaster of Arda | claude-sonnet-4.6 | Web research, multi-source verification |
| `thinker` | Námo | Vala — the Doomsman | gpt-5.4 | Reasoning, tradeoffs, advisory. Read-only. |
| `craftsman` | Celebrimbor | Noldorin Elf — maker of the Rings | gpt-5.3-codex | Code, debugging, implementation |
| `planner` | Finrod | Noldorin Elf — Felagund | claude-sonnet-4.6 | Requirements interviews, planning |
| `librarian` | Pengolodh | Noldorin Elf — Loremaster of Gondolin | gpt-4.1 | Fast docs and API lookups |
| `writer` | Maglor | Noldorin Elf — greatest singer in Arda | gpt-5.4 | Long-form writing, reports |
| `scout` | Legolas | Sindar Elf | gpt-5.4-nano | Quick recon, cheap background sweeps |
| `metis` | Melian | Maia — the Girdle | claude-sonnet-4.6 | Pre-planning: intent classification, hidden requirements |
| `momus` | Eönwë | Maia — Herald of Manwë | gpt-5.4 | Plan reviewer: OKAY or REJECT, max 3 blockers |

A few names worth unpacking for anyone who knows the source material:

**Olórin** is Gandalf's name in Valinor. In the Valaquenta, he walked unseen among the Elves and understood their sorrows. He was sent to Middle-earth precisely because he could work *with* others rather than dominate them — a counselor who interfaces between realms. That's a better fit for a primary assistant than "Gandalf," which carries too much of the heroic journey archetype.

**Námo** (Mandos) is the Doomsman — he pronounces fate laid out before him, never acts directly, and his verdicts are final. He's the read-only advisory agent by nature. The Doom of the Noldor was spoken once, clearly, and with devastating accuracy. For a high-reasoning model whose job is to analyse tradeoffs and never execute — perfect.

**Eönwë** is the Herald of Manwë who pronounced the final verdict of the War of Wrath. His job was to deliver judgment, not deliberate it. Binary, final, without editorializing. OKAY or REJECT with max 3 blockers — that's Eönwë.

**Melian**'s Girdle was a perimeter of perception that revealed the hidden nature of things before they arrived. Beren walked through it because Melian had already classified his intent. The pre-planning function, exactly.

The model choices are deliberate and benchmark-driven. The thinker uses `gpt-5.4` because it has the strongest reasoning benchmarks in that tier per [Artificial Analysis](https://artificialanalysis.ai). The craftsman gets `gpt-5.3-codex`, a Codex-tuned variant specifically optimised for code diffs and the search/replace block format that agentic editing depends on. Scout uses `gpt-5.4-nano` because recon tasks are high-volume and fast-enough beats perfect.

A mistake I made early: giving the orchestrator `claude-opus-4.7` because it felt like the "best" model. The right model for each agent depends on what it actually does, not on name recognition.

---

## 6. Workspace File Hygiene in Practice

Once the setup is running, the biggest ongoing maintenance problem isn't writing the files — it's keeping them honest as they drift. A few practical things I've learned:

**Watch the bootstrap budget.** Running `openclaw doctor` shows raw vs injected character counts per file, truncation percentage, and total vs budget. My AGENTS.md was at 99% of the 12,000-character per-file limit before I audited it. A file at 99% of cap is silently losing its tail on every turn.

**Separate procedures from character.** The single biggest source of AGENTS.md bloat is personality notes creeping in from SOUL.md, and the biggest source of SOUL.md bloat is procedural instructions that belong in AGENTS.md. A clear separation keeps both files lean and both behaviours consistent.

**TOOLS.md is not a general reference manual.** It should contain only local environment specifics — hostnames, credentials, known quirks of this particular deployment. Anything that would be the same across different installations doesn't belong there. If a section grows past ~3,000 characters, audit it.

**Prune memory files.** The daily `memory/YYYY-MM-DD.md` files accumulate over months and get injected into every session. Older daily files should be reviewed, and anything worth keeping permanently should be promoted to MEMORY.md. The rest can be archived. Keep MEMORY.md under 10,000 characters — if it grows past that, some content has become stable enough for a skill's documentation instead.

**IDENTITY.md earns its place in multi-agent setups.** In a single-agent setup it's mostly display metadata. In a multi-agent setup, explicit capability declarations in IDENTITY.md help the orchestrator route tasks correctly. "Cannot do without delegation: production code → Celebrimbor, deep research → Rúmil" is more reliable than hoping the orchestrator infers it from context.

---

## 7. What This Actually Gets You

Five markdown files are the difference between a stateless AI tool and something that genuinely feels like a collaborator. `SOUL.md` gives the model a character that holds under pressure. `AGENTS.md` gives it operational discipline and a reliable boot sequence. `IDENTITY.md` gives it a routing card. `USER.md` gives it a relationship. `MEMORY.md` gives it continuity. Together they turn a session into something cumulative rather than disposable.

The thing I didn't expect is how much the specificity matters. A `SOUL.md` that says "be helpful and direct" does almost nothing. A `SOUL.md` that says "this person thinks in infrastructure, appreciates elegance, will notice bad writing, and doesn't need things explained twice" changes the model's behaviour in ways that are immediately obvious in conversation.

None of this requires anything exotic. Just markdown, deliberate thought about who each agent is, and the discipline to keep those files honest as you learn what actually works.

**Further reading:**

- [Anthropic: Claude's Character](https://www.anthropic.com/research/claude-character) — the philosophical grounding for why persona design matters
- [dontriskit/awesome-ai-system-prompts](https://github.com/dontriskit/awesome-ai-system-prompts) — production system prompts from Claude, GPT-4o, Manus, Perplexity and others
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) — multi-agent orchestration for OpenCode, good reference for agent role design
- [OpenCode](https://opencode.ai) — the coding harness this setup draws inspiration from
- [LangGraph](https://github.com/langchain-ai/langgraph) — programmatic approach to the same multi-agent patterns
- [OpenClaw documentation](https://docs.openclaw.ai) — the gateway this setup runs on
- [GitHub Copilot model multipliers](https://docs.github.com/en/copilot/concepts/billing/copilot-requests#model-multipliers) — if you're using Copilot and care about cost per request

If you're running a similar setup and want to compare notes, leave a comment below.
