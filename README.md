# GenAIOps Workflow Studio

> AI workflow orchestration with multi-agent coordination, constitutional governance, and persistent memory infrastructure.

## Overview

GenAIOps Workflow Studio is a production-grade AI workflow automation system built on **n8n, Supabase, and Claude**. It demonstrates multi-agent orchestration with domain-based reasoning roles, persistent memory across sessions, and a constitutional governance layer that bounds agent behavior at the data layer — not with rules bolted onto individual workflows.

The system runs an autonomous orchestration daemon on a fixed heartbeat, assembles context from multiple sources, reasons with Claude, and fans decisions out into persisted, audited side-effects. It is designed around one hard requirement: **no work is ever silently dropped.**

## Repository Contents

| File | What it shows |
| --- | --- |
| [`schema.sql`](schema.sql) | Production Postgres/Supabase schema — idempotent intake, lifecycle state machine, dead-letter queue, append-only audit logs, CHECK constraints, RLS on every table, and a governance trigger. |
| [`workflows/heartbeat-daemon.json`](workflows/heartbeat-daemon.json) | Importable n8n workflow — scheduled trigger → parallel context reads → merge → Claude reasoning → fault-tolerant JSON parse → fan-out to persistence with UUID validation. Secrets removed; reconnect credentials after import. |
| [`governance-policy.json`](governance-policy.json) | Declarative governance policy — risk tiers, decision tiers, agent roles, enforcement points, and OWASP LLM Top-10 alignment. Editing this file changes behavior without redeploying agents. |

## Architecture

```
Schedule / External Trigger
        │
        ▼
   Workflow Config (agent, endpoints)
        │
        ├──► Fetch Unprocessed Signals (Supabase)
        └──► Fetch Agent State        (Supabase)
        │
        ▼
   Merge Context ──► Build Prompt ──► Claude (reasoning)
        │
        ▼
   Parse Decisions  ◄── fault-tolerant: a bad model response
        │                cannot crash the cycle
        ├──► Write Heartbeat Log      (append-only audit)
        ├──► Update Agent State
        ├──► Split Tasks ─────────────► Create Task (Notion)
        └──► Split Signals ─► Filter Valid UUIDs ─► Mark Processed
```

## Key Engineering Decisions

**Idempotent intake.** Every signal carries a `content_hash` for duplicate detection and a `lifecycle_status` state machine (`received → parsed → acted → verified → processed`) rather than a naive boolean. Duplicates and partial failures land in explicit terminal states.

**No silent data loss.** When a signal's side-effects fail or only partially complete, the processing gate writes to a **dead-letter queue** instead of marking the signal processed. Failures are captured with enough context to replay.

**Fault-tolerant reasoning.** The parser wraps model output in `try/catch` and emits a valid, empty decision object on failure — the orchestration cycle continues and the error is logged rather than crashing the run.

**Governance at the substrate.** A `BEFORE INSERT` database trigger auto-escalates high-risk (R3/R4) signals to review and records a `governance_violations` row. Policy is declarative ([`governance-policy.json`](governance-policy.json)), so behavior changes without redeploying workflows.

**Least-privilege access.** Row-Level Security is enabled on every table; runtime uses the service role and direct client writes are denied by default.

**Observability.** An append-only `heartbeat_log` records every cycle; a health monitor scores liveness, drift, latency, and cost against tunable thresholds and escalates through GREEN/YELLOW/RED/BLACK bands.

## Tech Stack

| Layer | Technology |
| --- | --- |
| Orchestration | n8n (cloud + self-hostable) |
| Runtime state & audit | Supabase (PostgreSQL, RLS) |
| Reasoning | Claude (Anthropic) |
| Narrative memory | Notion (MCP-connected) |
| Local inference | Ollama (self-hosted model node) |

## Governance & Security

This system implements **constitutional governance** rather than purely rule-based governance:

- **Rule-based:** external rules constrain behavior; agents operate freely until a rule fires — and can optimize around the rules.
- **Constitutional:** the operating environment is constituted by the policy itself, enforced at intake (trigger), at runtime (dead-letter gate), and continuously (drift monitor). There is less gap between stated values and actual behavior for an agent to game.

Mapped to the **OWASP LLM Top 10**:
- **LLM01 (Prompt Injection):** declarative principles make injected instructions detectable by contrast with policy.
- **LLM07 (Insecure Plugin Design):** agent roles and decision tiers define exactly what each role may authorize.
- **LLM08 (Excessive Agency):** risk tiers map to decision tiers so no role acts above its authorized scope.

## Certifications & Background

- Oracle AI Foundations Associate
- Oracle Generative AI Professional
- Oracle Digital Assistant
- OCI Architect Associate (in progress)

## Status

Active development. Heartbeat daemon running on a 10-minute cycle with a multi-thousand-row operational history. Core architecture validated through sustained iteration.

## Note on This Repository

Identifiers, endpoints, and prompts in these files are sanitized for public release. Reconnect your own Supabase, Notion, and Anthropic credentials after importing the workflow.
