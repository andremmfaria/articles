---
title: MCPs Are Eating Your Context Window (And What To Do About It)
description: 'How MCP tool schemas silently consume most of your AI agent context on every turn, what that costs across Anthropic, OpenAI, Google, and Bedrock, and how lazy-loading skills fix the problem.'
published: true
cover_image: 'https://raw.githubusercontent.com/andremmfaria/articles/main/articles/MCPs%20Are%20Eating%20Your%20Context%20Window/cover-mcp-context-window.png'
tags:
  - ai
  - automation
  - agents
  - openclaw
id: 3737058
date: '2026-05-24T02:53:21Z'
---

I was looking at my [OpenClaw](https://openclaw.ai) token usage data when I noticed something odd. The numbers were dominated by cache reads, tens of millions of tokens per week, on a setup where the actual conversations were relatively short. The output tokens, the ones where the model is actually thinking, were a small fraction of the total.

The culprit turned out to be something I had not thought to question: MCP servers.

This article is about what MCP tool schemas actually cost, why most people miss it, and how skills solve the problem by loading lazily instead of front-loading everything into every turn. The numbers are real, measured from a real setup, priced against real provider rates.

---

## 1. What MCP servers actually inject

[Model Context Protocol](https://modelcontextprotocol.io) is a standard for connecting AI agents to external services. The idea is straightforward: define a set of tools, and the model can call them. OPNsense integration? Here are 133 tools. TrueNAS SCALE? Here are 278. GitHub? Here are 101.

The problem is how those tools reach the model. Every tool ships a JSON schema describing its name, description, parameters, types, enums, and constraints. When an MCP server is active, [every single one of those schemas gets serialised and injected with every API call](https://www.mindstudio.ai/blog/claude-code-mcp-server-token-overhead), whether you are going to use any of them or not. This is not a quirk of any particular client. It is how the MCP spec works. The tools array goes with every request.

Here is what that looks like in practice, measured from my homelab setup:

| Component | Tools | Estimated tokens |
|---|---|---|
| TrueNAS MCP | 278 | ~27,800 |
| OPNsense MCP | 133 | ~13,300 |
| Playwright MCP | 35 | ~3,500 |
| Native agent tools | 25 | ~2,500 |
| Workspace files (AGENTS.md, SOUL.md, etc.) | n/a | ~3,400 |

Total first-turn context: approximately **41,000 tokens**. Workspace files account for 8% of that. The other 92% is tool schemas.

Run 215 turns per day (a moderate multi-agent setup) and you are pushing roughly 9 million context tokens daily just to describe tools you rarely use.

---

## 2. This is not a homelab problem

A few well-known MCP servers to put scale in perspective:

| MCP Server | Total tools | Default/active | Tokens (full) | Source |
|---|---|---|---|---|
| [GitHub MCP](https://github.com/github/github-mcp-server) | 101 | 52 | ~64,600 / ~30,300 | [Official discussion #1182](https://github.com/github/github-mcp-server/discussions/1182) |
| [TrueNAS MCP](https://github.com/truenas/api_client) | 278 | All | ~27,800 | Measured |
| [OPNsense MCP](https://github.com/yourusername/opnsense-mcp-server) | 133 | All | ~13,300 | Measured |
| [Datadog MCP](https://docs.datadoghq.com/bits_ai/mcp_server) | 40+ (16 core) | 16 core | ~4,000+ | Datadog docs |
| [AWS MCP suite](https://github.com/awslabs/mcp) | 50+ across 20 servers | Per server (5-15) | ~1,500-3,000 each | AWS Labs repo |
| [Atlassian Rovo MCP](https://github.com/atlassian/atlassian-mcp-server) | ~12-20 | All | ~3,000-5,000 | Estimated |
| [Stripe MCP](https://docs.stripe.com/mcp) | ~20 official | All | ~5,000 | Stripe docs |
| [Slack MCP](https://api.slack.com/mcp) | 13 | All | ~3,250 | [Speakeasy catalog](https://www.speakeasy.com/product/mcp-gateway/catalog/slack) |
| [Notion MCP](https://github.com/makenotion/notion-mcp-server) | ~14 | All | ~3,500 | Docker MCP catalog |
| [Sentry MCP](https://github.com/getsentry/sentry-mcp) | ~10-15 | All | ~2,500-3,750 | Estimated |
| [PostgreSQL MCP](https://github.com/modelcontextprotocol/servers/tree/main/src/postgres) | ~5-12 | All | ~1,250-3,000 | MCP reference server |
| [Kubernetes MCP](https://github.com/strowk/mcp-k8s-go) | ~15-25 | All | ~3,750-6,250 | Community |

A developer running GitHub MCP, Slack MCP, and a Postgres MCP alongside their native tools is starting every single message with roughly **40,000 tokens** of context overhead before they have typed a word. GitHub MCP alone at full capacity burns **64,600 tokens**, consuming 32% of Claude Sonnet's 200K context window before the conversation starts.

---

## 3. This affects every tool that uses MCP

This is not an OpenClaw issue. It is a consequence of how MCP works architecturally, and it affects every AI tool that integrates with MCP servers:

| Tool | MCP support | Injection pattern | Notes |
|---|---|---|---|
| [Claude Code](https://claude.ai/code) | Full native | Eager, every API call | [Issue #44536](https://github.com/anthropics/claude-code/issues/44536): ToolSearch experiment, 85% reduction when enabled |
| [Codex CLI](https://github.com/openai/codex) | Full | Eager, per turn | Used in [Datadog + Codex integration examples](https://techcommunity.microsoft.com/blog/appsonazureblog/get-started-with-datadog-mcp-server-in-azure-sre-agent/4497123) |
| [OpenCode](https://opencode.ai) | Full | Eager by default; lazy via [opencode-mcp-tool-search plugin](https://lobehub.com/mcp/francisco-m001-opencode-mcp-tool-search) | Same underlying problem; community plugin fixes it |
| OpenClaw | Full | Eager, per turn | What this article is about |

The MCP spec itself requires the tools array to be sent with each API call. The only documented escape valve is "ToolSearch", a meta-tool that lets the model search for tools by name rather than receiving all schemas upfront. Claude Code introduced this experimentally, with a [reported 85% token reduction](https://github.com/anthropics/claude-code/issues/44536). GitHub MCP reduced its default toolset from 101 to 52 tools specifically in response to [user complaints about context overhead](https://github.com/github/github-mcp-server/discussions/1182).

---

## 4. What it costs per provider

On a flat-rate plan like GitHub Copilot, this overhead is invisible. You pay a fixed monthly fee regardless of token volume. But most serious usage of Claude, GPT, or Gemini goes through the API, where every token has a price.

| Provider | Model | Input $/M | Cached input $/M | Output $/M | Context window |
|---|---|---|---|---|---|
| [Anthropic](https://www.anthropic.com/pricing) | Claude Sonnet 4.6 | $3.00 | $0.30 | $15.00 | 1M tokens |
| [Anthropic](https://www.anthropic.com/pricing) | Claude Haiku 4.5 | $1.00 | $0.10 | $5.00 | 200K tokens |
| [OpenAI](https://openai.com/api/pricing/) | GPT-5 | $1.25 | ~$0.31 | $10.00 | 272K tokens |
| [OpenAI](https://openai.com/api/pricing/) | GPT-4.1 | $2.00 | $0.50 | $8.00 | 1M tokens |
| [Google](https://ai.google.dev/pricing) | Gemini 2.5 Pro | $1.25 | ~$0.25 | $10.00 | 1M tokens |
| [Google](https://ai.google.dev/pricing) | Gemini 2.5 Flash | $0.30 | — | $2.50 | 1M tokens |
| [AWS Bedrock](https://aws.amazon.com/bedrock/pricing/) | Claude Sonnet 4.6 | $3.00 | ~$0.30 | $15.00 | 1M tokens |
| [AWS Bedrock](https://aws.amazon.com/bedrock/pricing/) | Amazon Nova Pro | $0.96 | $0.20 | $3.84 | 300K tokens |
| [Azure OpenAI](https://azure.microsoft.com/en-us/pricing/details/cognitive-services/openai-service/) | GPT-4.1 | ~$2.00 | ~$0.50 | ~$8.00 | 1M tokens |
| [OpenRouter](https://openrouter.ai/pricing) | (aggregator) | pass-through | model-dependent | pass-through | varies |

What 44,500 tokens of MCP overhead costs per message at different providers, assuming prompt caching is active (best case):

| Provider + Model | Per message (cached) | Per message (uncached) | Monthly (215 turns/day, 22 days) |
|---|---|---|---|
| Anthropic Claude Sonnet 4.6 | $0.013 | $0.134 | $62 (cached) / $622 (uncached) |
| OpenAI GPT-4.1 | $0.022 | $0.089 | $104 (cached) / $416 (uncached) |
| OpenAI GPT-5 | $0.014 | $0.056 | $65 (cached) / $260 (uncached) |
| Google Gemini 2.5 Flash | $0.013 | $0.013 | $62 (no caching) |
| AWS Bedrock Nova Pro | $0.009 | $0.043 | $42 (cached) / $200 (uncached) |

These are costs from overhead alone, before any actual work is done. On Sonnet without prompt caching, 44,500 tokens per message at 215 turns/day adds up to over $600/month in context overhead.

Prompt caching helps significantly for repeated context (the tool schemas do not change turn-to-turn, so they cache well). But even at the cached rate, the overhead is material at scale.

---

## 5. Skills: lazy loading as the fix

The alternative is skills. In OpenClaw and in tools like [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) for OpenCode, a skill is a markdown file that tells the model how to use a capability. Only a name and a short description enter the context upfront. The full instructions are loaded when the model actually needs them.

A skill entry in the context looks like this:

```text
truenas: Manage TrueNAS SCALE: storage, sharing, services, VMs, alerts, replication.
```

That is roughly 24 tokens. Compare that to the ~27,800 tokens for the TrueNAS MCP schema.

The model retains full capability. When it needs to interact with TrueNAS, it reads the skill and executes shell commands: `midclt` websocket calls, `curl` against the REST API, or short Python scripts. The capability is the same. The context cost is not.

The token savings from replacing three MCP servers:

| Replaced | Tokens before | Tokens after | Saved per turn |
|---|---|---|---|
| TrueNAS MCP | ~27,800 | ~24 | ~27,776 |
| OPNsense MCP | ~13,300 | ~24 | ~13,276 |
| Playwright MCP | ~3,500 | ~24 | ~3,476 |
| **Total** | **~44,600** | **~72** | **~44,528** |

First-turn context drops from ~41,000 tokens to roughly ~10,000. A 75% reduction in baseline overhead per turn.

---

## 6. What skills look like in practice

A skill is a SKILL.md file with a short frontmatter description and usage instructions. The model reads it when needed. The skill documents three things: how to authenticate, what the primary command pattern is, and what the fallback is when the primary does not cover the full surface.

Credentials live in the environment, not in the skill file. In OpenClaw, env vars are declared in `openclaw.json` and injected into every agent turn. Other frameworks use `.env` files, secrets stores, or per-agent config blocks. The skill does not care how the variables arrive, only that they exist at runtime.

```json
{ "env": { "TRUENAS_URL": "https://truenas.host:50443", "TRUENAS_API_KEY": "..." } }
```

For API key auth, that is all the setup needed. For OAuth-based services, the approach shifts to pre-authenticated CLI state: `gh auth login` stores credentials in `~/.config/gh/hosts.yml`; `jira init` writes an API token to `~/.config/.jira/.config.yml`. After that one-time setup, skill calls carry no credentials in the command itself.

Each skill documents a primary path and a fallback. For TrueNAS that is `midclt` (websocket) with `curl` as fallback:

```bash
# Primary: dedicated CLI
midclt -u ws://truenas.host:50443/api/current --api-key "$TRUENAS_API_KEY" call pool.query

# Fallback: curl REST
curl -sk -H "Authorization: Bearer $TRUENAS_API_KEY" "$TRUENAS_URL/api/v2.0/pool" | jq .
```

For more complex operations (bulk queries, job polling, conditional logic), a short Python script is cleaner than chained shell commands:

```python
import os, sys
sys.path.insert(0, '/home/user/.local/lib/python3.14/site-packages')
from truenas_api_client import Client

with Client(os.environ['TRUENAS_WS_URL'], api_key=os.environ['TRUENAS_API_KEY']) as c:
    for ds in c.call('zfs.dataset.query', [], {'select': ['name', 'used']}):
        print(ds['name'], ds['used'])
```

Each skill also ships a `check.sh` that verifies the CLI is installed, env vars are set, and the host is reachable before the agent tries to use it. Validation moves from MCP schema enforcement (happens automatically before every call) to `check.sh` (happens at load time, once). For stable infrastructure with a single operator that is a reasonable trade. For production systems with many contributors and rapidly evolving APIs, MCPs may still be the right call.

---

## 7. Real audit numbers

Before starting this work I pulled six days of session data from my setup:

- 92 million cache read tokens in six days
- Average daily cost at Sonnet direct API rates: $15/day
- Projected monthly: $285-390/month

This was on a flat-rate plan where none of it showed up in the bill. But GitHub Copilot is [actively transitioning to usage-based billing](https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing). When that change completes, token volume will directly translate to cost for the first time.

The right time to fix token obesity is before you are paying per token, not after.

I also found a secondary problem during the audit: AGENTS.md had grown to 99% of the 12,000-character per-file bootstrap limit, meaning it was being silently truncated on every turn. The workspace files, which everyone assumes are the main context cost, were actually only 8% of the total. The other 92% was tool schemas that nobody had looked at.

---

## 8. The replacement stack

For reference, this is what replaced the three MCP servers in my setup:

**TrueNAS:** [`truenas_api_client`](https://github.com/truenas/api_client) (official iXsystems library) and `midclt` CLI for websocket API access. REST API via `curl` as fallback. Full coverage of the 278-tool surface.

**OPNsense:** [`opn-cli`](https://github.com/andreas-stuerz/opn-cli) (community Python CLI) for firewall, HAProxy, routes, and DNS. Raw `curl` against the OPNsense REST API for NAT, VLANs, DHCP, and ACME, which opn-cli does not cover.

**Playwright:** [`shot-scraper`](https://shot-scraper.datasette.io) for screenshots, JS eval, and HTML extraction. Python `playwright` library for full browser automation: form fills, login flows, file downloads.

All three follow the same pattern: a primary CLI or library path with documented fallback commands for anything the primary does not cover. The skill documents both paths. The model chooses based on what the task requires.

---

## 9. Conclusion

MCP servers are a reasonable architecture for giving agents access to external services. The problem is the cost model: every tool schema defined by an active MCP server gets injected with every API call, whether those tools are relevant to the current task or not. As the ecosystem adds more MCP servers (GitHub, Datadog, Atlassian, Stripe, Slack, Sentry, AWS, Kubernetes), the baseline context overhead per message compounds.

On flat-rate plans, this is invisible. Under per-token billing, it is a significant and growing cost that starts before any work has been done.

Skills sidestep this by being lazy. A skill entry is a name and a description, a few dozen tokens. Full instructions load when needed. The model calls CLIs and APIs directly. The capability is the same; the upfront cost is not.

The numbers from this setup: 44,500 tokens saved per turn, a 75% reduction in baseline context overhead, and a monthly saving of roughly $62 under Sonnet cached pricing, or $622 at uncached rates. On a flat rate today, not relevant. On usage-based billing, very much so.

---

> **A note on GitHub Copilot:** Copilot Pro+ at $39/month is a flat rate that absorbs all token volume. If you stay within the request limits, this overhead is financially invisible. The analysis in this article applies to direct API usage with Anthropic, OpenAI, Google, AWS Bedrock, or any other pay-per-token provider. If you are on Copilot and not planning to switch, the context window fill rate argument still applies: you hit context limits sooner. But the cost argument does not, until Copilot's usage-based transition completes.

---

**Further reading:**

- [Model Context Protocol specification](https://modelcontextprotocol.io) - the MCP protocol standard
- [GitHub MCP tool count and token overhead discussion](https://github.com/github/github-mcp-server/discussions/1182) - confirmed 64.6K / 30.3K token numbers
- [Claude Code ToolSearch lazy loading issue](https://github.com/anthropics/claude-code/issues/44536) - 85% token reduction experiment
- [MindStudio: Claude Code MCP token overhead analysis](https://www.mindstudio.ai/blog/claude-code-mcp-server-token-overhead) - tool injection mechanism explained
- [Cursor 40-tool limit discussion](https://forum.cursor.com/t/tools-limited-to-40-total/67976) - context pressure forcing hard limits
- [OpenCode MCP tool search plugin](https://lobehub.com/mcp/francisco-m001-opencode-mcp-tool-search) - lazy loading for OpenCode
- [Datadog MCP server](https://docs.datadoghq.com/bits_ai/mcp_server) - 16+ core tools, additional toolsets
- [Atlassian MCP server](https://github.com/atlassian/atlassian-mcp-server) - Jira, Confluence, Compass
- [AWS MCP suite](https://github.com/awslabs/mcp) - 20+ individual servers
- [Sentry MCP](https://github.com/getsentry/sentry-mcp) - official debugging MCP
- [AgentSkills specification](https://agentskills.io) - the skill format used by OpenClaw and oh-my-openagent
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) - skills for OpenCode, same lazy-loading pattern
- [truenas/api_client](https://github.com/truenas/api_client) - official TrueNAS Python client used in replacement
- [opn-cli](https://github.com/andreas-stuerz/opn-cli) - community OPNsense CLI
- [shot-scraper](https://shot-scraper.datasette.io) - Simon Willison's browser scraping CLI
- [Anthropic pricing](https://www.anthropic.com/pricing) - Claude API rates
- [OpenAI pricing](https://openai.com/api/pricing/) - GPT API rates
- [Google AI pricing](https://ai.google.dev/pricing) - Gemini API rates
- [AWS Bedrock pricing](https://aws.amazon.com/bedrock/pricing/) - Bedrock rates
- [pricepertoken.com](https://pricepertoken.com) - cross-provider pricing comparisons
