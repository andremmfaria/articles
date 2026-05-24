---
title: MCPs Are Eating Your Context Window (And What To Do About It)
description: 'How MCP tool schemas silently consume most of your AI agent context on every turn, what that costs at scale, and how lazy-loading skills solve the problem.'
published: false
cover_image: 'https://raw.githubusercontent.com/andremmfaria/articles/main/articles/MCPs%20Are%20Eating%20Your%20Context%20Window/cover-mcp-context-window.png'
tags:
  - ai
  - automation
  - agents
  - openclaw
date: '2026-05-24T00:00:00Z'
id: 3736745
---

I was looking at my [OpenClaw](https://openclaw.ai) token usage data when I noticed something odd. The numbers were dominated by cache reads, tens of millions of tokens per week, on a setup where the actual conversations were relatively short. The output tokens, the ones where the model is actually thinking, were a small fraction of the total.

The culprit turned out to be something I had not thought to question: MCP servers.

This article is about what MCP tool schemas actually cost, why most people do not notice, and how skills solve the problem by loading lazily instead of front-loading everything into every turn.

---

## 1. What MCP servers actually inject

[Model Context Protocol](https://modelcontextprotocol.io) is a standard for connecting AI agents to external services. The idea is straightforward: define a set of tools, and the model can call them. OPNsense integration? Here are 133 tools. TrueNAS SCALE? Here are 278. Playwright browser automation? Another 35.

The problem is how those tools are surfaced to the model. Every tool ships a JSON schema describing its name, description, parameters, types, enums, and constraints. When an MCP server is active, every single one of those schemas gets serialised and injected into the system prompt on every turn, whether you are going to use any of them or not.

Here is what that looks like in practice, measured from a real setup:

| Component | Tools | Estimated tokens |
|---|---|---|
| TrueNAS MCP | 278 | ~27,800 |
| OPNsense MCP | 133 | ~13,300 |
| Playwright MCP | 35 | ~3,500 |
| Native agent tools | 25 | ~2,500 |
| Workspace files (AGENTS.md, SOUL.md, etc.) | n/a | ~3,400 |

Total first-turn cache write: approximately **41,000 tokens**. Of that, workspace files account for just 8%. The other 92% is tool schemas.

Run 215 turns per day (a moderate multi-agent setup) and you are pushing roughly 9 million context tokens daily just to describe tools you rarely use. Over a month, that is around 270 million tokens of overhead.

---

## 2. Why most people do not notice

On flat-rate plans like GitHub Copilot Pro, cache reads do not cost extra. You are paying $39 per month regardless of how many tokens you burn. The overhead is invisible in the bill.

It becomes visible in three other ways:

**Context window fill rate.** A 1 million token context window sounds enormous until 41,000 tokens of it are consumed before the first message. In a long session, the transcript accumulates on top of that baseline. You hit context limits sooner than you should.

**Latency.** More tokens in context means more time for the model to process them. On every turn.

**When billing changes.** GitHub Copilot is transitioning to usage-based billing. Anthropic's API charges $3 per million input tokens for Claude Sonnet, with cache reads at $0.30 per million. At 270 million cache read tokens per month, that is $81 per month in cache overhead alone, before any actual conversation happens.

The flat-rate era made token obesity invisible. Usage-based billing will make it expensive very quickly.

---

## 3. The anatomy of an MCP tool schema

To understand why this happens, it helps to look at what a single MCP tool schema actually contains.

A simple tool like "list firewall rules" might look like this in the schema:

```json
{
  "name": "opnsense__list_firewall_rules",
  "description": "List all firewall rules on the OPNsense firewall. Returns rules with UUID, action, interface, protocol, source, destination, and enabled state.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "interface": {
        "type": "string",
        "description": "Filter by interface name (e.g. lan, wan, opt1). Optional."
      },
      "enabled_only": {
        "type": "boolean",
        "description": "When true, returns only enabled rules. Defaults to false."
      }
    }
  }
}
```

That is one tool. A 278-tool server like TrueNAS has that repeated 278 times, covering everything from pool management to certificate generation to VM lifecycle to cloud sync tasks. Most of it is irrelevant in any given conversation.

The model needs to parse all of it. And it does, on every single turn.

---

## 4. Skills: lazy loading as the fix

The alternative is skills. In OpenClaw (and in tools like [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) for OpenCode), a skill is a markdown file that tells the model how to use a tool, but only injects a name and a short description into the context. The full instructions are loaded lazily when the model actually needs them.

A skill entry in the context looks like this:

```
truenas: Manage TrueNAS SCALE — storage, sharing, services, VMs, alerts, replication.
```

That is roughly 24 tokens. Compare that to the ~27,800 tokens for the TrueNAS MCP schema.

The model still has full capability. When it needs to interact with TrueNAS, it reads the skill instructions and executes shell commands: `midclt` calls, `curl` against the REST API, or short Python scripts. The key difference is that those instructions only load when relevant, not on every turn by default.

The token savings:

| MCP | Tokens before | Tokens after | Saved per turn |
|---|---|---|---|
| TrueNAS | ~27,800 | ~24 | ~27,776 |
| OPNsense | ~13,300 | ~24 | ~13,276 |
| Playwright | ~3,500 | ~24 | ~3,476 |
| **Total** | **~44,600** | **~72** | **~44,528** |

First-turn context drops from ~41,000 tokens to roughly ~10,000. A 75% reduction in baseline overhead, before any conversation has happened.

---

## 5. What skills look like in practice

A skill for TrueNAS looks like this. The SKILL.md describes what it does (surfaced as context when needed) and how to use it:

```markdown
---
name: truenas
description: Manage TrueNAS SCALE — storage (pools, datasets, snapshots), sharing (SMB/NFS), services, VMs, apps, alerts, replication, users.
---

# TrueNAS Skill

## Primary: midclt (websocket API)

    midclt -u ws://preto.kantharos.srv:50443/api/current \
      --api-key "$TRUENAS_API_KEY" call pool.query

## Fallback: curl REST API

    curl -sk -H "Authorization: Bearer $TRUENAS_API_KEY" \
      "$TRUENAS_URL/api/v2.0/pool" | jq .
```

The model calls `midclt` or `curl` directly via the exec tool. No middleware. No schema. No per-turn injection.

For each skill, there is also a `check.sh` that verifies dependencies are installed when the skill loads:

```bash
#!/usr/bin/env bash
command -v midclt &>/dev/null && echo "[truenas] midclt: ok" || echo "[truenas] WARN: midclt not found"
python3 -c "import truenas_api_client" &>/dev/null && echo "[truenas] python module: ok"
```

This matters because skills shift responsibility from the framework to the agent. The framework was ensuring MCP tools were available by construction. With skills, you verify that the underlying CLI tools and libraries are installed, and you provide fallback paths when they are not.

---

## 6. The tradeoffs

Skills are not strictly better than MCPs. There are real tradeoffs worth naming.

**MCPs provide parameter validation.** When an MCP tool is called, the schema enforces types, required fields, and enum constraints before the request is sent. With skills, the model constructs shell commands or API calls directly. If it gets a parameter wrong, the error comes back from the CLI or the API, not from the framework. The feedback loop is one step longer.

**MCPs are more discoverable.** A model that has never seen your infrastructure can look at a tool schema and understand what operations are available. With skills, the model needs to read the SKILL.md. For well-written skills this is fine, but it puts more weight on the skill documentation.

**Skills require maintenance.** When the underlying API changes, you update the SKILL.md. When a CLI tool updates its interface, the skill may need updating. MCP servers abstract that maintenance away from you.

For a homelab with stable infrastructure and a single operator, these tradeoffs are easy. For a production system where multiple people are deploying agents against rapidly evolving APIs, MCPs may still be the right call.

The decision comes down to token budget and billing model. At flat rates, MCPs are convenient and cost nothing extra. Under usage-based billing, 44,000 tokens per turn adds up faster than most people expect.

---

## 7. What this looks like in a real audit

Before starting this work, I ran `openclaw doctor` to check the workspace bootstrap files. The output flagged AGENTS.md at 99% of the 12,000-character per-file limit, meaning it was being silently truncated on every turn. That was a separate problem (too much content in the wrong files), but it pointed at the same underlying issue: context is a finite resource and most setups do not track how it is being spent.

The tool audit came from a different angle. I was comparing model provider pricing when I pulled six days of session data and ran the numbers:

- 92 million cache read tokens in six days
- Average cost at Sonnet direct API rates: $15 per day
- Projected monthly: $285-390 per month

At $39 per month on a flat rate, none of that had mattered. But it would matter if the billing model changed, which it is currently in the process of doing.

The right time to fix token obesity is before you are paying per token, not after.

---

## 8. The replacement stack

For reference, this is what replaced the three MCP servers:

**TrueNAS:** `truenas_api_client` (official iXsystems Python library) and `midclt` CLI for websocket API access. REST API via `curl` as fallback. Install: `pip install 'truenas_api_client @ git+https://github.com/truenas/api_client.git' --break-system-packages`

**OPNsense:** `opn-cli` (community Python CLI) for firewall, HAProxy, routes, and DNS. Raw `curl` against the OPNsense REST API for NAT, VLANs, DHCP, and ACME. Install: `pip install opn-cli`

**Playwright:** `shot-scraper` (Simon Willison) for screenshots, JS eval, and HTML extraction. Python `playwright` library for full browser automation: form fills, login flows, file downloads. Install: `pip install shot-scraper playwright`

All three follow the same pattern: a primary path using a proper CLI or library, and a curl/Python fallback that covers the gaps. The skill documents both. The agent chooses based on what is available and what the task requires.

---

## 9. Summary

MCP servers are convenient. They give agents structured, validated access to external services, and for many use cases that is the right architecture. But they have a hidden cost: every tool schema they define gets injected into every turn, whether the agent needs those tools or not.

In a small setup with one or two MCP servers, this is negligible. In a homelab running multiple services simultaneously, it can consume most of your baseline context budget before the conversation starts.

Skills solve this by being lazy. A skill entry is a name and a description, a few dozen tokens. The instructions load when needed. The agent calls CLI tools and APIs directly. The model retains full capability with a fraction of the upfront cost.

The numbers from this setup: 44,500 tokens saved per turn, a 75% reduction in baseline context overhead, and a monthly saving of roughly $80 under direct API billing. Not relevant today on a flat rate. Very relevant when billing changes.

**Further reading:**

- [OpenClaw documentation](https://docs.openclaw.ai) - the gateway this setup runs on
- [Model Context Protocol](https://modelcontextprotocol.io) - the MCP specification
- [AgentSkills](https://agentskills.io) - the skill format OpenClaw uses
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) - skills for OpenCode, same pattern
- [truenas/api_client](https://github.com/truenas/api_client) - official TrueNAS Python client
- [opn-cli](https://github.com/andreas-stuerz/opn-cli) - community OPNsense CLI
- [shot-scraper](https://shot-scraper.datasette.io) - Simon Willison's browser scraping CLI
- [Artificial Analysis](https://artificialanalysis.ai) - model benchmarks and pricing comparisons
