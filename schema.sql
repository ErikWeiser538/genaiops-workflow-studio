-- ============================================================================
-- GenAIOps Workflow Studio — Supabase / PostgreSQL Schema
-- ----------------------------------------------------------------------------
-- Runtime data layer for a governed multi-agent orchestration system.
--
-- Design goals demonstrated here:
--   * Idempotent intake        (content-hash duplicate DETECTION, no double-processing)
--   * Explicit lifecycle       (a state machine, not a boolean, tracks each signal)
--   * No silent data loss       (failed side-effects go to a dead-letter queue)
--   * Append-only auditability   (immutable heartbeat + governance logs)
--   * Data integrity at the DB   (CHECK constraints enforce enums and ranges)
--   * Least-privilege access      (Row-Level Security enabled on every table)
--
-- All identifiers below are illustrative. Replace placeholders before use.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- signals_inbox
-- Intake queue for all external triggers and inter-agent messages.
-- The lifecycle_status column is a state machine — a signal is never simply
-- "done"; it moves through explicit, auditable states. content_hash enables
-- duplicate detection without being enforced UNIQUE, so the application layer
-- (not the database) owns dedup policy.
-- ----------------------------------------------------------------------------
CREATE TABLE signals_inbox (
    id               uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at       timestamptz  NOT NULL DEFAULT now(),
    received_at      timestamptz  DEFAULT now(),
    source           text,
    agent_target     text,
    signal_type      text,
    message          jsonb,
    payload_json     jsonb,
    priority         integer      DEFAULT 0,
    urgency          smallint     DEFAULT 1,

    -- Governance / risk classification
    risk_tier        text         DEFAULT 'R0'
                     CHECK (risk_tier IN ('R0','R1','R2','R3','R4')),
    override_flag    text         DEFAULT 'none'
                     CHECK (override_flag IN ('none','review','block')),
    override_reason  text,

    -- Idempotency + lifecycle
    content_hash     text,        -- md5(message::text); DETECTION only, not UNIQUE
    lifecycle_status text         DEFAULT 'received',
                     -- received -> parsed -> acted -> verified -> processed
                     -- terminal error states: dead_lettered | held_duplicate | partial_failure
    processed        boolean      DEFAULT false,
    held_reason      text,        -- human-readable reason a row is held/quarantined

    -- Lifecycle timestamps (set by the processing gate as side-effects complete)
    acted_at         timestamptz, -- writes (task/memory/etc.) completed
    verified_at      timestamptz, -- side-effects verified before processed = true
    processed_at     timestamptz
);

CREATE INDEX idx_signals_unprocessed ON signals_inbox (processed, agent_target);
CREATE INDEX idx_signals_content_hash ON signals_inbox (content_hash);


-- ----------------------------------------------------------------------------
-- dead_letter
-- Dead-letter queue. When a signal's side-effects fail or only partially
-- complete, the gate writes here INSTEAD of marking the signal processed=true.
-- This is the mechanism that guarantees no work is silently dropped.
-- Service-role only.
-- ----------------------------------------------------------------------------
CREATE TABLE dead_letter (
    id              uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    signal_id       uuid         REFERENCES signals_inbox (id),
    agent           text,
    failure_stage   text,        -- which step failed (parse | write | verify | ...)
    failure_reason  text,
    payload_json    jsonb,       -- full context captured for replay
    created_at      timestamptz  NOT NULL DEFAULT now(),
    resolved        boolean      DEFAULT false,
    resolved_at     timestamptz,
    resolution_note text
);


-- ----------------------------------------------------------------------------
-- agent_state
-- Singleton-per-agent operational state. Holds the current mode, risk posture,
-- and liveness heartbeat so the system's status is always queryable.
-- ----------------------------------------------------------------------------
CREATE TABLE agent_state (
    id                     uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    agent                  text         DEFAULT 'orchestrator',
    updated_at             timestamptz  NOT NULL DEFAULT now(),
    current_mode           text         DEFAULT 'learning'
                           CHECK (current_mode IN ('stable','learning','explore','lockdown')),
    current_risk_tier      text         DEFAULT 'R0',
    heartbeat_interval_sec integer      DEFAULT 600,
    last_heartbeat         timestamptz,
    last_run_at            timestamptz,
    is_online              boolean      DEFAULT true,
    status                 text         DEFAULT 'active',
    last_error             text,
    version                text         DEFAULT '1.0'
);


-- ----------------------------------------------------------------------------
-- heartbeat_log
-- Append-only record of every orchestration cycle. Immutable by convention —
-- one row per run. This is the operational audit trail and the source of the
-- system's health metrics.
-- ----------------------------------------------------------------------------
CREATE TABLE heartbeat_log (
    id                 uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    heartbeat_id       text,
    agent              text,
    run_at             timestamptz  DEFAULT now(),
    signals_seen       integer      DEFAULT 0,
    risk_tier          text,
    override_type      text,
    mode               text,
    reflection_summary text,
    actions_json       jsonb        -- structured record of everything the cycle did
);


-- ----------------------------------------------------------------------------
-- governance_violations
-- Constitutional / policy audit log. Every signal blocked by the governance
-- trigger and every drift flagged by the monitor trigger is recorded here.
-- ----------------------------------------------------------------------------
CREATE TABLE governance_violations (
    id              uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    signal_id       uuid         REFERENCES signals_inbox (id),
    agent_target    text,
    source          text,
    risk_tier       text,
    violation_type  text         NOT NULL,
    violation_layer text         NOT NULL,
    message_excerpt text,
    blocked_at      timestamptz  DEFAULT now(),
    resolved        boolean      DEFAULT false,
    resolved_at     timestamptz,
    resolution_notes text
);


-- ----------------------------------------------------------------------------
-- monitor_log + monitor_thresholds
-- Health-monitoring subsystem. One monitor_log row per health snapshot across
-- liveness, drift, latency, cost, and signal-flow. Thresholds live in a
-- separate table so bands can be tuned WITHOUT redeploying any workflow.
-- ----------------------------------------------------------------------------
CREATE TABLE monitor_log (
    id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    run_at                timestamptz DEFAULT now(),
    window_minutes        integer     NOT NULL,
    overall_status        text        NOT NULL
                          CHECK (overall_status IN ('GREEN','YELLOW','RED','BLACK')),
    liveness_findings     jsonb,
    drift_findings        jsonb,
    latency_findings      jsonb,
    cost_findings         jsonb,
    signal_flow_findings  jsonb,
    aggregate_score       numeric,
    alerts_sent           jsonb,
    recovery_actions      jsonb
);

CREATE TABLE monitor_thresholds (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    metric          text        UNIQUE NOT NULL,
    yellow_threshold numeric,
    red_threshold    numeric,
    black_threshold  numeric,
    unit            text,
    description     text,
    active          boolean     DEFAULT true,
    updated_at      timestamptz DEFAULT now()
);


-- ============================================================================
-- ROW-LEVEL SECURITY
-- RLS is enabled on every table. Runtime uses the service role; direct client
-- access is denied by default. Illustrative policy shown for one table.
-- ============================================================================
ALTER TABLE signals_inbox          ENABLE ROW LEVEL SECURITY;
ALTER TABLE dead_letter            ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_state            ENABLE ROW LEVEL SECURITY;
ALTER TABLE heartbeat_log          ENABLE ROW LEVEL SECURITY;
ALTER TABLE governance_violations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE monitor_log            ENABLE ROW LEVEL SECURITY;
ALTER TABLE monitor_thresholds     ENABLE ROW LEVEL SECURITY;

-- Example: allow authenticated reads, restrict writes to the service role.
CREATE POLICY "read_own_signals"
    ON signals_inbox FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "service_role_writes_signals"
    ON signals_inbox FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);


-- ============================================================================
-- GOVERNANCE TRIGGER (pattern)
-- A BEFORE-INSERT trigger enforces policy at the data layer: high-risk signals
-- can be flagged for review or blocked before they are ever acted on. This is
-- governance as an intrinsic property of the substrate, not an afterthought.
-- ============================================================================
CREATE OR REPLACE FUNCTION governance_check_signal()
RETURNS trigger AS $$
BEGIN
    -- Escalate high-risk inbound signals for human review.
    IF NEW.risk_tier IN ('R3','R4') AND NEW.override_flag = 'none' THEN
        NEW.override_flag := 'review';
        NEW.held_reason  := 'auto-escalated: risk_tier ' || NEW.risk_tier;
        INSERT INTO governance_violations
            (signal_id, agent_target, source, risk_tier, violation_type, violation_layer)
        VALUES
            (NEW.id, NEW.agent_target, NEW.source, NEW.risk_tier, 'risk_escalation', 'intake');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_governance_check
    BEFORE INSERT ON signals_inbox
    FOR EACH ROW EXECUTE FUNCTION governance_check_signal();
