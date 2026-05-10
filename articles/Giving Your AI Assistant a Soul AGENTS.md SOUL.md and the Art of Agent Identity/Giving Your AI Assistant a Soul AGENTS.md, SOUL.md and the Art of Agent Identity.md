---
title: 'Giving Your AI Assistant a Soul: AGENTS.md, SOUL.md and the Art of Agent Identity'
description: 'How a handful of markdown files turn a generic AI model into a specialist team and why character is load-bearing infrastructure, not decoration.'
published: true
tags:
  - ai
  - automation
  - agents
  - openclaw
id: 3642546
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

The workspace for the main agent lives at `/config/clawd/main/` and contains:

```shell
├── AGENTS.md       # Operational rules: how to behave, when to delegate
├── SOUL.md         # Character: who you are, not just what you do
├── USER.md         # About the human: persisted context across sessions
├── TOOLS.md        # Environment specifics: IPs, hostnames, preferences
├── MEMORY.md       # Long-term curated memory
├── HEARTBEAT.md    # Periodic background task checklist
└── memory/
    └── YYYY-MM-DD.md   # Raw daily session notes
```

Each of these files is injected verbatim into the system prompt before the model sees any user message. The model's first act in every conversation is to read its own identity, its operational rules, and its accumulated knowledge about you. This matters more than it sounds. Large language models are stateless functions over token sequences. The only continuity that exists is what you inject. These files are that continuity, and every decision about what to put in them is a decision about who the agent is and what it remembers across sessions.

One thing worth knowing upfront: each agent in a multi-agent setup gets its own workspace directory. The default agent gets the workspace root directly. Non-default agents get `root + agentId`, so the main agent lands at `/config/clawd/main/`, the researcher at `/config/clawd/agents/researcher/`, and so on. Getting this wrong means editing files the agent never reads, which I did for longer than I'd like to admit.

Beyond the workspace files, agents also have access to a set of tools and data sources that let them act on the world rather than just talk about it. In my setup this includes Home Assistant (to control smart home devices), UniFi (network topology and connected clients), AdGuard (DNS filtering), Cloudflare (DNS and domain management), OPNsense and TrueNAS via MCP servers, GitHub for code and issues, and live weather data. The orchestrator has the broadest access. Specialist agents get only what they need: the craftsman has GitHub and DevOps tools, the researcher has web fetch and weather, the librarian has nothing beyond web access. Limiting tool access per agent isn't just security hygiene, it also keeps each agent's decision space narrower and its behaviour more predictable.

---

## 3. SOUL.md: Why Character is Load-Bearing

The first instinct is to treat `SOUL.md` as cosmetic. A personality sprinkle on top of the real work. It isn't, and Anthropic's own writing on [Claude's character](https://www.anthropic.com/research/claude-character) makes the argument clearly:

> *"The traits and dispositions of AI models have wide-ranging effects on how they act in the world. They determine how models react to new and difficult situations."*

Character is what fills the gaps when there's no explicit rule. A model without defined character defaults to the path of least resistance, which is usually some form of helpful corporate blandness that hedges everything, agrees with the user, and never pushes back. Technically present, practically useless.

My `SOUL.md` defines the agent as decisive (one recommendation with a reason, not three options with caveats), as having a spine (disagree when the premise is wrong, once, clearly, without lecturing), and as genuinely curious about the specific context it operates in. It also defines the relationship to me: it knows I appreciate elegance, that I'll notice bad writing, that a historical analogy lands as well as a technical explanation. That specificity is what separates a collaborator from a generic assistant.

Writing a good `SOUL.md` is less about listing personality traits and more about writing the prompt in the voice you want the model to adopt. If you want decisive, write decisively. If you want dry wit, use it. The model will mirror the register of its own system prompt more than it will follow explicit instructions to "be funny" or "be direct". Show, don't tell. If you want inspiration, the [dontriskit/awesome-ai-system-prompts](https://github.com/dontriskit/awesome-ai-system-prompts) repository has leaked and reverse-engineered prompts from Manus, Perplexity, Claude, GPT-4o, and others. It's a good way to see how production systems handle tone, refusals, and persona before writing your own.

---

## 4. AGENTS.md, USER.md and Memory: The Operational Layer

Where `SOUL.md` answers *who*, `AGENTS.md` answers *how*. It defines the session startup sequence, the gates on external actions that require confirmation, and for a multi-agent setup, the delegation rules. The most consequential part of mine is a simple table mapping task types to the right specialist: research goes to the researcher, hard reasoning goes to the thinker, code goes to the craftsman. When I ask the main agent to look something up, it doesn't do it itself. It spawns the right sub-agent, waits for the result, and synthesises the response. `AGENTS.md` is where that behaviour lives. The pattern is similar to what [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) implements for OpenCode, where agents like Sisyphus, Prometheus and Hephaestus each have defined roles and delegation rules. The difference is that here everything is portable markdown rather than tied to a specific coding harness.

`USER.md` is the file most people skip and shouldn't. It's a persisted description of who you are and how you work: timezone, interests, communication style, what gets results and what wastes time. Without it, the agent rediscovers you every session. With it, it starts already knowing you. Mine is three sections: what I care about technically, what I care about outside of tech (literature, history, scenic arts), and my communication preferences. The model reads this before it reads anything I type, which means it already has context on who it's talking to before the conversation begins.

The memory system runs alongside this in two layers. Daily session notes go into `memory/YYYY-MM-DD.md`, raw logs of decisions made, things discovered, work done. Periodically, the agent reviews those and distils them into `MEMORY.md`, removing stale entries and keeping what's worth carrying forward. It's the same pattern a human uses: take notes during the day, review and update your mental model later. Files do what neurons can't across session restarts.

---

## 5. Building a Specialist Team

The workspace file approach scales naturally to multiple agents. Each specialist gets its own workspace directory with its own `SOUL.md` and `AGENTS.md`, defining a narrower identity and a more focused operational loop. The main agent handles conversation. The orchestrator breaks complex work into parallel workstreams. The specialists execute. This is the same model that agentic frameworks like [LangGraph](https://github.com/langchain-ai/langgraph) and [AutoGen](https://github.com/microsoft/autogen) implement programmatically, except here the "agent definition" is just a markdown file rather than a class or graph node.

I'm running this on GitHub Copilot because it happens to be what I have access to, but none of what follows is Copilot-specific. OpenClaw supports any AI provider out of the box, including Amazon Bedrock, Anthropic Claude directly, Google Gemini, OpenAI, local models via Ollama, and others. The workspace file pattern works the same regardless of what's underneath. Swap the provider, keep the markdown.

I named the agents after Greek mythology following oh-my-openagent's convention, mostly because it makes the team feel less like a config file and more like something you'd actually want to work with.

| Agent | Name | Model | Cost (GH Copilot) | Role |
|---|---|---|---|---|
| `orchestrator` | Sisyphus | claude-sonnet-4.6 | 1x | Multi-step coordination, delegation |
| `researcher` | Atlas | gpt-5.4-mini | 0.33x | Web research, multi-source verification |
| `thinker` | Oracle | gpt-5.4 | 1x | Reasoning, tradeoffs, critique |
| `craftsman` | Hephaestus | gpt-5.3-codex | 1x | Code, debugging, implementation |
| `planner` | Prometheus | claude-sonnet-4.6 | 1x | Requirements interviews, planning |
| `librarian` | Librarian | gpt-4.1 | 0x (free) | Fast docs and API lookups |
| `writer` | Writer | gpt-5.4 | 1x | Long-form writing, reports |
| `scout` | Scout | gpt-5.4-nano | 0.25x | Quick recon, cheap background sweeps |

The model choices are deliberate and benchmark-driven. The researcher uses `gpt-5.4-mini` at 0.33x because research is iterative, many web fetches, synthesise, repeat, and running a 1x model through a dozen tool calls adds up fast with no quality gain. The thinker uses `gpt-5.4` because it has the strongest reasoning benchmarks available at under 1x on GitHub Copilot: 96.7% on τ2-bench, 80% fewer factual errors than o3, per [Artificial Analysis](https://artificialanalysis.ai). The craftsman gets `gpt-5.3-codex`, a Codex-tuned variant specifically optimised for code diffs, repository understanding, and the search/replace block format that agentic code editing depends on. If you're on a different provider, the same logic applies: match the model's documented strengths to the task, not just its headline benchmark score.

A mistake I made early: I gave the orchestrator `claude-opus-4.7` because it felt like the "best" model. It's also 15x the cost multiplier of sonnet on Copilot. The right model for each agent depends on what it actually does and how it benchmarks on that task, not on name recognition. Similarly, I initially made the orchestrator the default agent. That's backwards. The orchestrator is a workhorse, not a receptionist. The main agent should be the stable conversational interface, and the orchestrator is something it calls when the work genuinely needs coordination.

The `SOUL.md` and `AGENTS.md` for each specialist are written to fit the model underneath. The craftsman's `SOUL.md` emphasises exploring before coding, running before reporting success, logging technical gotchas. The thinker's `SOUL.md` emphasises restating problems, listing assumptions, steelmanning opposing views. Each file shapes the model's behaviour in ways that fit what that model is actually good at, which means the team's parts are genuinely differentiated rather than just renamed copies of each other.

---

## 6. What This Actually Gets You

Five markdown files are the difference between a stateless AI tool and something that genuinely feels like a collaborator. `SOUL.md` gives the model a character that holds under pressure. `AGENTS.md` gives it operational discipline. `USER.md` gives it a relationship. `MEMORY.md` gives it continuity. Together they turn a session into something cumulative rather than disposable.

The thing I didn't expect is how much the specificity matters. A `SOUL.md` that says "be helpful and direct" does almost nothing. A `SOUL.md` that says "this person thinks in infrastructure, appreciates elegance, will notice bad writing, and doesn't need things explained twice" changes the model's behaviour in ways that are immediately obvious in conversation. The model is working with the context you gave it, and the more precisely you describe your actual situation, the more precisely it can calibrate.

None of this requires anything exotic. Just markdown, deliberate thought about who each agent is, and the discipline to keep those files honest as you learn what actually works.

**Further reading:**

- [Anthropic: Claude's Character](https://www.anthropic.com/research/claude-character) - the philosophical grounding for why persona design matters
- [dontriskit/awesome-ai-system-prompts](https://github.com/dontriskit/awesome-ai-system-prompts) - production system prompts from Claude, GPT-4o, Manus, Perplexity and others
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) - multi-agent orchestration for OpenCode, good reference for agent role design
- [OpenCode](https://opencode.ai) - the coding harness this setup draws inspiration from
- [LangGraph](https://github.com/langchain-ai/langgraph) - programmatic approach to the same multi-agent patterns
- [OpenClaw documentation](https://docs.openclaw.ai) - the gateway this setup runs on
- [GitHub Copilot model multipliers](https://docs.github.com/en/copilot/concepts/billing/copilot-requests#model-multipliers) - if you're using Copilot and care about cost per request

If you're running a similar setup and want to compare notes, leave a comment below.
