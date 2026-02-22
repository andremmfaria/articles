---
title: When Chat Turns into Control - Security Lessons from Running a Local AI Agent
tags:
  - ai
  - security
  - openclaw
published: true
cover_image: 'https://bernardmarr.com/wp-content/uploads/2025/05/How-AI-Agents-Will-Revolutionize-Your-Day-To-Day-Life.jpg'
id: 3274210
---

Running large language models locally is easier than ever. With tools like Ollama and frameworks such as OpenClaw, it’s now trivial to deploy AI agents that reason, keep state, and execute actions on private hardware.

That convenience comes with a catch.

Once an LLM is wired to tools and exposed through a platform like Discord, it stops being “just a chatbot.” It becomes a control surface driven by natural language, where user input can directly influence system behaviour. In that context, traditional security assumptions like clear trust boundaries, strict input validation, predictable execution no longer hold ground.

This article is not an installation guide. It’s a security-focused reflection on running a local AI agent: where the real risks appear, why “self-hosted” does not automatically mean “safe,” and which design choices actually reduce the blast radius when things go wrong.

## 1. Context and setup

Running LLMs locally has become easy enough that many people now treat them like “just another service.” Tools like **[OpenClaw](https://openclaw.ai/)** push this further by turning an LLM into an *agent*: something that can reason, keep state, and execute actions.

In this setup, the agent is controlled through **[Discord](https://discord.com/)**, backed by a local **[Ollama](https://ollama.com/)** instance. The deployment looks like this:

* **Ollama** runs on a dedicated **TrueNAS host** with an **RTX 3070**, handling all LLM inference.
* **Model**: **Qwen3 8B**, chosen for being fast and efficient on consumer GPUs.
* **OpenClaw** runs on a separate **Linux VM**, acting as the agent control plane.
* The two hosts communicate over the local network.
* Discord is the primary user interface.

Everything is self-hosted and not directly exposed to the internet. At first glance, this feels “safe enough.” But once you let an agent *do things*, not just chat, you’re no longer dealing with a toy system. You’re running automation driven by natural language, which changes the security model completely.

---

## 2. Architecture and trust boundaries

At a high level, the system has three layers:

* **Discord** – where humans talk to the agent
* **OpenClaw** – where decisions, memory, and tool execution happen
* **Ollama + LLM** – where language is generated

Each layer crosses a trust boundary.

Discord is an **untrusted input surface**, even if the users themselves are trusted. Messages can include pasted text, links, logs, or content copied from elsewhere. Research on prompt injection shows that attackers don’t need direct access to the model—indirect injection through user-supplied content is often enough to override intended behaviour ([MDPI, 2024](https://www.mdpi.com/2078-2489/17/1/54)).

OpenClaw sits in the middle as a **control plane**. It turns text into actions. The problem is that LLMs don’t distinguish between “instructions” and “data.” Everything is just language. This is a known and well-documented weakness of LLM systems, and it’s why prompt injection keeps showing up as the dominant failure mode in agent-based designs ([arXiv:2601.09625](https://arxiv.org/abs/2601.09625)).

Finally, when the agent can execute tools (filesystem access, memory writes, or web fetches) the risk escalates. Academic and industry analyses consistently show that once an injected prompt can *chain actions*, the impact is no longer limited to bad answers; it can affect the system itself ([arXiv:2410.23308](https://arxiv.org/abs/2410.23308)).

One important takeaway: running Ollama and OpenClaw on separate hosts improves performance and resilience, but it does **not** automatically solve these security problems. The weakest link is still the language interface.

---

## 3. The security problem with small models

Qwen3 8B is a great fit for a home lab: it’s fast, it runs well on a consumer GPU (RTX 3070), and it’s cheap to keep online. The downside is that small-ish models are **easier to steer off course**.

That matters because agents don’t just “answer questions.” They can **call tools**, update memory, and sometimes fetch or interpret external content. Prompt injection is now widely treated as a top-tier LLM risk for exactly this reason: language is both *data* and *instructions*, and the model can be tricked into treating untrusted text as “policy.” OWASP calls this out directly as a primary risk category for LLM apps. ([OWASP](https://owasp.org/www-project-top-10-for-large-language-model-applications))

Where it gets nasty is **indirect prompt injection**: the attacker doesn’t need to DM your bot with an obviously malicious prompt. They just need your agent to *consume* content that contains hidden instructions (HTML, docs, logs, etc.). This has been demonstrated repeatedly for web agents, where malicious strings embedded in a page can hijack agent behaviour. ([arXiv:2507.14799](https://arxiv.org/abs/2507.14799))

So the core issue isn’t “Qwen is bad.” It’s:

* **Small model + tool access = higher chance of bad tool calls**
* **Small model + web/content ingestion = bigger prompt injection surface**
* Once it’s an agent, you have to assume the model will occasionally do the wrong thing

That’s why the security posture for small models tends to be: contain the blast radius (sandbox) and remove the easiest injection paths (web fetch / browser). ([OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html))

---

## 4. Discord as an attack surface

Discord feels like a friendly UI, but from a security perspective it’s an **untrusted command channel**. Anything users paste (logs, URLs, config snippets) can become “model input,” and that’s enough for prompt injection to show up.

The two main problems are:

* **Scope creep**: “it’s only our server” slowly becomes “it’s in more channels than intended”
* **Permission drift**: roles change, new channels get created, people invite the bot elsewhere

So the safe baseline is: deny by default, then allow only what you actually need.

In practice, that means:

* **Lock the bot to specific guild(s)** (server allowlisting)
* **Restrict usage to a specific role** (role gating)
* Decide whether normal messages must be mention-gated (reduce accidental triggers)
* Handle **slash commands** explicitly (they have their own permissions model in Discord)

Discord itself supports controlling who can use slash commands through its permissions system (and it’s worth doing that at the Discord layer, not just in the bot). ([Discord](https://discord.com/blog/slash-commands-permissions-discord-apps-bots))

This is the key mental shift: even if the model runs locally and the gateway isn’t public, Discord is still a big input funnel. Treat it like an API surface: least privilege, explicit allowlists, and “assume someone will paste something dumb eventually.” OWASP’s guidance maps well here: prompt injection is not rare, and the best defenses are limiting what the model can do when it gets it wrong. ([OWASP](https://owasp.org/www-project-top-10-for-large-language-model-applications))

---

## 5. Sandboxing and tool restriction

Once the agent was wired to Discord and running a small model, the real risk wasn’t wrong/bad answers. It was **uncontrolled side effects**. This is where sandboxing becomes essential.

In OpenClaw, sandboxing means **session-level isolation for tool execution**. Each conversation runs inside a constrained environment, with no access to the host filesystem or other sessions. If the model does something wrong, the impact is contained.

Enabling sandboxing globally is a single configuration change:

```bash
openclaw config set agents.defaults.sandbox.mode all
openclaw config set agents.defaults.sandbox.scope session
openclaw config set agents.defaults.sandbox.workspaceAccess none
```

This follows OpenClaw’s sandboxing model, which prioritizes containment over perfect prevention ([docs.openclaw.ai/sandbox](https://docs.openclaw.ai/sandbox)).

The second part of the fix was disabling web-based tools. Web access is the most common prompt-injection vector in agent systems: arbitrary, attacker-controlled text gets fed directly into the model. This has been repeatedly demonstrated in both academic work and industry analyses of indirect prompt injection ([arXiv:2507.14799](https://arxiv.org/abs/2507.14799)).

In practice, this meant explicitly turning off web fetch and denying the entire web tool group:

```bash
openclaw config set tools.web.fetch.enabled false
openclaw config set tools.deny '["group:web","browser"]'
```

The last item to complete the fix was to add a rate limiting on the auth attempts on the gateway

```bash
openclaw config set gateway.auth.rateLimit '{ "maxAttempts": 10, "windowMs": 60000, "lockoutMs": 300000 }'
```

This means that there are a max of 10 failed attempts per minute and it locks out for 5 minutes after that.

After these changes:

* Tool execution became more predictable
* Web-based injection paths were removed
* OpenClaw’s built-in security audit reported **zero critical or warning findings**

This matches OWASP’s guidance for LLM applications: assume prompt injection will eventually happen, and focus on **reducing blast radius** instead of relying on model behaviour alone ([OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)).

---

## 6. Takeaways

A few clear lessons came out of this setup:

* Local LLMs are not automatically safe just because they are self-hosted
* Discord is an attack surface, not just a chat UI
* Small models like Qwen3 8B are efficient, but need **more** guardrails
* Sandboxing matters more than model choice
* Removing web access dramatically reduces risk
* Separating Ollama and OpenClaw hosts improves resilience, not security

Most of these conclusions line up with existing research and security guidance. Prompt injection, permission drift, and over-trusted tools are **expected failure modes**, not edge cases ([OWASP Prompt Injection Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)), ([arXiv:2410.23308](https://arxiv.org/abs/2410.23308)).

The takeaway is simple: once an LLM can act, it must be treated like infrastructure. With sandboxing, explicit allowlists, and tool restrictions, a local agent can be both powerful and reasonably safe — but only if security is part of the design from the start.
