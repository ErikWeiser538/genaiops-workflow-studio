## Status

**Ready to copy-paste into GitHub.** Create repo named `genaiops-workflow-studio`, paste this as [README.md](http://README.md), make first commit.

---

# GenAIOps Workflow Studio

> AI workflow orchestration with multi-agent coordination, constitutional governance, and persistent memory infrastructure.
> 

## Overview

GenAIOps Workflow Studio is a production-grade AI workflow automation system built on n8n, Supabase, and Notion. It demonstrates multi-agent orchestration with domain-based reasoning roles, persistent memory across sessions, and a constitutional governance layer that governs agent behavior without external enforcement.

This system was built as a portfolio asset demonstrating the architecture patterns behind enterprise-ready AI automation — specifically the gap between rule-based AI governance (what most enterprises build) and constitutional AI governance (what actually holds under pressure).

## Architecture

```
User / External Trigger
        ↓
   n8n Webhook Layer
   (Orchestration Bus)
        ↓
┌───────────────────────────────┐
│     Agent Routing Layer       │
│  Intent → Domain → Persona   │
└──────────┬────────────────────┘
           ↓
┌──────────────────────────────────────┐
│         Persona Domains              │
│  Compliance · Finance · Operations   │
│  Research  · Security · Synthesis   │
└──────────┬───────────────────────────┘
           ↓
┌──────────────────────────────────────┐
│         Persistent Memory Layer      │
│   Supabase (runtime state)           │
│   Notion (narrative / canonical)     │
└──────────────────────────────────────┘
```

## Key Features

**Multi-Agent Orchestration**

- Domain-based persona routing — each agent has a defined scope, authority level, and escalation path
- Intent classification and entity extraction before routing
- Cross-agent coordination for decisions requiring multiple domain inputs

**Constitutional Governance Layer**

- Agent behavior governed by policy JSON, not hardcoded rules
- Five decision tiers: autonomous, advisory, approval-required, council, human-only
- Treaty-aligned operation: agents cannot exceed their authorized scope without explicit escalation
- Drift detection: behavioral baseline monitoring flags agents operating outside established patterns

**Persistent Memory Architecture**

- `daemon_state`: singleton table holding system-wide operational state
- `heartbeat_log`: immutable append-only record of every agent cycle
- `signals_inbox`: queue for external triggers and inter-agent communication
- `persona_memories`: narrative memory in Notion, operational state in Supabase — separate concerns, connected architecture

**PIOS Daemon**

- 10-minute heartbeat cycle
- Reads daemon state → generates contextual response via LLM → writes heartbeat log
- Provides continuous system health visibility without human intervention
- First successful loop: March 15, 2026

## Tech Stack

| Layer | Technology |
| --- | --- |
| Orchestration | n8n (cloud + self-hostable) |
| Runtime State | Supabase (PostgreSQL) |
| Narrative Memory | Notion (MCP-connected) |
| LLM — Primary | Claude (Anthropic) |
| LLM — Daemon | Groq llama-3.3-70b-versatile (free tier) |
| Local LLM | Ollama / Llama 3.1 (Echo node) |

## Workflow Structure

### WF_001 — PIOS Daemon Heartbeat Monitor

Clean 4-node workflow: Webhook → Read daemon_state (Supabase) → Generate heartbeat (Groq) → Write heartbeat_log (Supabase)

Demonstrates: persistent AI state, continuous operation, free-tier LLM integration

### WF_002 — Glitch Console (Direct Agent Interface)

Direct communication interface between human operator and AI agent. Webhook → Merge context → Claude agent → Log interaction → Return response

Demonstrates: human-in-the-loop design, context merging, audit trail

### WF_003 — GenAIOps Data Layer

Google Sheets as workflow data layer with three interconnected tabs: workflow_log / optimization_log / document_index

Demonstrates: lightweight data layer for AI workflow tracking, no database required for portfolio demos

## Governance Architecture

This system implements what I call constitutional AI governance — the distinction from standard rule-based governance is:

**Rule-based:** External rules constrain agent behavior. Agents operate freely until a rule fires.

**Constitutional:** The agent's operating environment is constituted by the values. There is no gap between stated values and actual behavior for rules to live in.

Practical difference: a rule-based system can be gamed by an agent that optimizes around the rules. A constitutional system has no gap to game — the values are the ground, not the ceiling.

This maps directly to the OWASP LLM Top 10:

- **LLM01 (Prompt Injection):** Constitutional ground makes injection detectable by contrast — a transparent system has no shadows
- **LLM07 (Insecure Plugin Design):** Authority matrix defines exactly what each agent can authorize
- **LLM08 (Excessive Agency):** Five decision tiers prevent autonomous action above scope

## Certifications & Background

- Oracle AI Foundations Associate ✅
- Oracle Generative AI Professional ✅
- Oracle Digital Assistant ✅
- OCI Architect Associate (in progress)

The Oracle Digital Assistant certification provided direct architectural insight that informed this system's design — specifically that ODA's multi-skill routing architecture (master routing layer → isolated skill environments → shared NLP engine) maps directly onto multi-agent persona orchestration. One LLM as the shared engine. Isolated system prompts and memory contexts as functionally independent persona environments.

## Status

Active development. PIOS daemon running. Glitch Console operational. Core architecture validated through 18 months of iteration.

**Current focus:** OCI Architect Associate certification → enterprise deployment patterns → Dice MCP integration for AI-assisted job search.

## Contact

Building toward AI Workflow Automation Engineer / AI Orchestration Engineer roles.

Portfolio: [this repo]

LinkedIn: [erik.weisersd]

Oracle: [erik.weisersd account]

---

*Built by one person, mobile-first, on a gas station night shift, with a clear picture of where this is going.*
