---
title: Running a Local AI Agent Securely: Discord + Ollama + OpenClaw
tags:
  - ai
  - security
  - openclaw
published: false
cover_image: 'https://bernardmarr.com/wp-content/uploads/2025/05/How-AI-Agents-Will-Revolutionize-Your-Day-To-Day-Life.jpg'
---

## 1. Context and setup

* Goal: run a local AI agent controlled via Discord, without cloud dependencies
* Stack:

  * **OpenClaw 2026.2.21-2** running on **Home Assistant OS (HAOS)**
  * **Ollama** as the LLM backend
  * **Model: Qwen3 8B**
* Deployment:

  * Ollama running on a **separate TrueNAS host**
  * GPU-accelerated inference using an **RTX 3070**
  * OpenClaw running on a different HAOS machine
  * Communication happens over the local network
* Integration reference:

  * Home Assistant OpenClaw add-on / guide:
    [https://community.home-assistant.io/t/openclaw-clawdbot-on-home-assistant/981467](https://community.home-assistant.io/t/openclaw-clawdbot-on-home-assistant/981467)
* Key point:

  * “Local” and “self-hosted” does **not** mean “safe by default”

---

## 2. Architecture and trust boundaries

* Discord is the **primary input surface**
* OpenClaw acts as an **agent control plane**
* Ollama is a **remote execution backend** (LLM inference only)
* Trust boundaries:

  * Discord → untrusted user input
  * LLM → probabilistic executor
  * Agent tools → real side effects
* Separating Ollama and OpenClaw improves performance and resilience, **but not security by itself**

---

## 3. The security problem with small models

* Qwen3 8B is:

  * fast and efficient on a local RTX 3070
  * well suited for homelabs
  * **more vulnerable to prompt injection**
* Small models:

  * follow recent instructions more eagerly
  * struggle to consistently enforce system constraints
* Risk compounds when combined with:

  * tool execution
  * persistent memory
  * external content ingestion
* Key insight:

  * smaller models require **stronger guardrails**, not fewer

---

## 4. Discord as an attack surface

* Discord integrations are permissive by default
* Risks:

  * open channels
  * unrestricted slash commands
  * role changes over time
* Hardening steps:

  * switch OpenClaw to an allowlist policy
  * restrict to a specific guild
  * enforce role-based access
* Practical lesson:

  * incorrect or misquoted IDs silently break security
  * runtime validation matters more than config intent

---

## 5. Sandboxing and tool restriction

* The critical fix:

  * enable **session-level sandboxing** in OpenClaw
* What sandboxing provides:

  * per-session isolation
  * constrained tool execution
  * reduced blast radius
* Web tools disabled:

  * no `web_fetch`
  * no browser access
* Result:

  * prompt injection impact is contained
  * OpenClaw security audit reports **zero critical or warning findings**

---

## 6. Takeaways

* AI agents should be treated as **infrastructure**
* Discord + tools turns LLMs into control systems
* GPU-accelerated local inference does not reduce security risk
* Network isolation helps, but **behavioral isolation matters more**
* With sandboxing and proper gating, local agents can be both powerful and safe
