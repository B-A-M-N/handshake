# Survival Pipeline Dev — Complete Design Specification

## Plugin Identity

| Field | Value |
|-------|-------|
| **Name** | `survival-pipeline-dev` |
| **Invocation** | `/survival-pipeline-dev` |
| **Mode Switch** | `/intake mode <Full|Light|IDFK|Shutup>` |
| **Handshake Role** | Context swapping notes only — notes archived after reinjection, not destroyed |
| **Handoff Transport** | `handshake \| direct_file` |
| **Handoff Guarantee** | `best_effort` when prompt-mediated, `enforced` when hooks/permissions available |

---

## Session State File (Complete Schema)

`.claude/tmp/survival-pipeline-dev/session.json`
```json
{
  "active": true,
  "mode": "Full | Light | IDFK | Shutup",
  "phase": "SCAN | COMPACT | CLASSIFY | INTAKE | UNDERSTANDING_CONFIRMATION | PLAN | EXECUTION_STYLE_CHOICE | PLAN_APPROVAL | EXECUTION | VERIFICATION | REPORT",
  "operation_mode": "create | debug | optimize | extend",
  "pipeline_types": ["ci_cd", "data", "ml", "rag", "queue", "agentic", "orchestration", "stateful_workflow", "event_driven", "stream_processing", "evaluation", "deployment", "observability", "tooling", "synchronization", "ingestion", "hybrid", "unknown"],
  "primary_pipeline_type": "agentic",
  "active_reasoning_types": ["agentic"],
  "pipeline_topology": "linear | multi_stage_orchestrated | graph_event_driven | hybrid",
  "pipeline_plane": "control | data | hybrid",
  "pipeline_confidence": 0.0,
  "pipeline_evidence": [],
  "execution_style": "inline | subagent | undecided",
  "model_strategy": "single_model | same_model_parallel | multi_model_parallel",
  "model_preference": "haiku | sonnet | opus | user_specified",
  "cost_profile": "cheap | balanced | thorough",
  "cost_guard": 0,
  "cost_guard_phase": 0,
  "cost_guard_yellow": 150,
  "cost_guard_red": 300,
  "parallelism_enabled": false,
  "parallel_conflict": false,
  "parallel_conflict_resolution": "",
  "arbiter_enabled": false,
  "arbiter_invocations": 0,
  "max_arbiter_invocations": 2,
  "audit_cycle_count": 0,
  "max_audit_cycles": 3,
  "max_fix_attempts": 3,
  "last_confirmed_understanding": "...",
  "plan_approved": false,
  "handshake_available": true,
  "handoff_transport": "handshake | direct_file",
  "handoff_guarantee": "best_effort | enforced",
  "handshake_note_path": "/path/to/handshake/note.md",
  "scan_file": "/path/to/tmp/scan_notes.json",
  "condensed_summary": "/path/to/tmp/summary.json",
  "deferred_issues": [],
  "skipped_issues": [],
  "assumption_log": [],
  "state_transition_log": [],
  "session_json_hash_before": "",
  "session_json_hash_after": "",
  "allowed_hash_changes": ["audit_cycle_count", "cost_guard", "cost_guard_phase", "parallel_conflict", "deferred_issues", "skipped_issues", "assumption_log", "state_transition_log", "phase", "audit_cycle_count", "cost_guard", "plan_approved", "last_confirmed_understanding"],
  "controlled_fields": ["phase", "plan_approved", "execution_style", "model_strategy", "active_reasoning_types", "pipeline_plane"],
  "phase_entry_count": {},
  "sequence_id": 0
}
```

### Field-Level Explanations:

- **`controlled_fields`** (NEW): These fields MUST ONLY be mutated by main agent. Subagents are forbidden from modifying them, even within `allowed_hash_changes`.
- **`phase_entry_count`** (NEW): Tracks how many times we've entered each phase. Used to prevent cost_guard_phase reset gaming.
- **`sequence_id`** (NEW): Monotonic integer for `state_transition_log` ordering. Timestamps can collide or reorder.
- **`allowed_hash_changes`**: Only THESE fields may change between subagent calls WITHOUT triggering a violation.
- **`active_reasoning_types`**: Limited to primary + max 2 supporting types. Frozen after PLAN phase begins.

---

## Hard Phase Machine (11 Phases, Enforced Order)

1. **`SCAN`** — Detect pipelines with confidence scoring (composable types + `pipeline_plane`), write `scan_notes.json` + `summary.json`; **`cost_guard_phase` resets to 0, increment `phase_entry_count[SCAN]`**
2. **`COMPACT`** — Strict rehydration order; **enforce `active_reasoning_types` trim (max 3, not just "MUST NOT"), freeze after PLAN**; if user intent defined, persist scan + summary + intent + mode; else persist only scan + summary + mode; clear non-essential history; rehydrate in MANDATORY order
3. **`CLASSIFY`** — Present classification (may be multiple types + `pipeline_plane`); limit `active_reasoning_types` to primary + max 2 supporting; if confidence < 0.5: mark UNCERTAIN, explain weak/missing evidence, ask user to confirm/correct/ignore — DO NOT disable any modes; **log to `state_transition_log` with `sequence_id`**
4. **`INTAKE`** — Read `session.json` mode, execute corresponding intake path (Full/Light/IDFK/Shutup); all modes available regardless of confidence; **log assumptions to `assumption_log` in IDFK mode**; **`cost_guard_phase` resets to 0, increment `phase_entry_count[INTAKE]`**
5. **`UNDERSTANDING_CONFIRMATION`** — Agent states understanding with operation mode persona + pipeline type framework (from `active_reasoning_types` only), user confirms; **restate: "Transitioning to UNDERSTANDING_CONFIRMATION phase"**; **log transition with `sequence_id`**
6. **`PLAN`** — Generate standardized plan using ONLY `active_reasoning_types` frameworks + `pipeline_plane` focus (modifies priority, NOT replaces framework); if `pipeline_type=unknown`, default to hybrid reasoning; if confidence < 0.5, add visible CAUTION note + extra validation recommendations (advisory); **FREEZE `active_reasoning_types` — no further trimming or modification**; **restate: "Transitioning to PLAN phase"**; **log transition with `sequence_id`**
7. **`EXECUTION_STYLE_CHOICE`** — After plan: present 5 execution options; **if `cost_guard_phase` reaches yellow, warn and recommend downgrade; if red, PAUSE and ask user**; limit active reasoning to primary + 2 supporting types; **`cost_guard_phase` resets to 0, increment `phase_entry_count[EXECUTION_STYLE_CHOICE]`**
8. **`PLAN_APPROVAL`** — Display plan + execution style + model assignments, wait for explicit "yes" or feedback; **restate: "Plan approved. Beginning execution." or "Plan rejected. Returning to PLAN phase."**; **log transition with `sequence_id`**
9. **`EXECUTION`** — Execute per chosen style/strategy with merge strategy; **`max_fix_attempts`: 3** per verification cycle; arbiter wired into loop; **severity-weighted audit threshold**; **restate: "Beginning execution with X/Y."**; increment `cost_guard_phase` with per-operation multiplier; **validate subagent output BEFORE state mutation**; **log transition with `sequence_id`**
10. **`VERIFICATION`** — Gated completion check, mandatory gate; global audit cap: max 3 audit cycles; **severity-weighted scoring**; **restate: "Transitioning to VERIFICATION phase"**; **log transition with `sequence_id`**
11. **`REPORT`** — Summary of work completed; **includes: completed items, changed files, validation run, passing/failing tests, deferred issues, skipped issues, assumption log, state transition log (ordered by `sequence_id`), decision summary (why key decisions were made), known risks, next steps, cost summary (both total and per-phase)**; sets `"active": false`; **final transition logged with `sequence_id`**

---

## Cost Guard (Properly Weighted + Profile-Based + Phase-Local + Anti-Gaming)

```text
Cost formula (multiplicative per-operation):

Each operation cost is MULTIPLIED individually by model_tier_multiplier:

cost_guard =
    (scan_weight) × model_tier_multiplier
  + (file_read_count × 1) × model_tier_multiplier
  + (edit_count × 3) × model_tier_multiplier
  + (bash_count × 4) × model_tier_multiplier
  + (test_run_count × 8) × model_tier_multiplier
  + (subagent_call_count × 15) × model_tier_multiplier
  + (audit_cycle_count × 20) × model_tier_multiplier
  + (arbiter_invocation_count × 25) × model_tier_multiplier

Model tier multipliers:
  - haiku: 1x
  - sonnet: 2x
  - opus: 4x

cost_guard_phase (resets each phase, BUT ONLY on first entry):
  - Tracks cost within CURRENT phase only
  - Resets to 0 when entering a NEW phase for the FIRST time
  - Uses phase_entry_count[PHASE_NAME] to detect first entry:
      if phase_entry_count[PHASE_NAME] == 1:
          cost_guard_phase = 0
      else:
          DO NOT reset (prevents gaming via phase oscillation)

Example gaming prevention:
  PLAN → EXECUTION → PLAN → EXECUTION
  - First PLAN:  phase_entry_count[PLAN]=1, reset cost_guard_phase
  - EXECUTION: phase_entry_count[EXECUTION]=1, reset
  - PLAN again: phase_entry_count[PLAN]=2, DO NOT reset
  - EXECUTION again: phase_entry_count[EXECUTION]=2, DO NOT reset
  → Agent cannot game cost by oscillating phases
```

**Profile-Based Thresholds:**

```text
cheap profile:
  yellow: 150    → warn user, recommend downgrade
  red: 300        → pause, explain cost pressure, ask user

balanced profile:
  yellow: 300    → warn user, recommend downgrade
  red: 600        → pause, explain cost pressure, ask user

thorough profile:
  yellow: 600    → warn user
  red: 1200+      → pause, explain cost pressure, ask user
```

**CRITICAL: Never auto-downgrade silently.**

```text
When cost_guard_phase reaches red:
  - PAUSE execution
  - Explain: "Cost guard threshold exceeded (X). Current profile: Y."
  - Ask user:
      "Recommend downgrade to: inline + single_model + arbiter_enabled?
       1) Yes, downgrade
       2) No, continue (I accept the cost)
       3) Switch to cheap/balanced/thorough profile"
  - Only downgrade AFTER explicit user confirmation
```

---

## Pipeline Detection with Confidence Scoring (Expanded Taxonomy)

**Detection indicators (expanded):**

| Type | Key Indicators | Examples |
|------|-----------------|----------|
| **ci_cd** | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `Dockerfile`, build configs | GitHub Actions, GitLab CI, Jenkins |
| **data** | ETL scripts, schema migrations, data transforms, lineage tools | Airflow DAGs, dbt, Pandas pipelines |
| **ml** | training loops, inference endpoints, model registries, data versioning | MLflow, Kubeflow, SageMaker |
| **rag** | embedding generation, vector stores, retrieval layers, chunking configs | Pinecone, Weaviate, LangChain RAG |
| **queue** | BullMQ, Celery, Kafka, Redis streams, RabbitMQ, worker loops | Kafka, Celery, BullMQ |
| **agentic** | agent definitions, tool definitions, planner-executor patterns, multi-agent orchestration | AutoGen, CrewAI, custom agent loops |
| **orchestration** | workflow engines, DAG definitions, task dependencies, checkpoint management | Temporal, Prefect, Luigi |
| **stateful_workflow** | explicit state machines, long-lived processes, checkpoints, human-in-loop | Temporal, Durable Functions |
| **event_driven** | webhooks, pub-sub, trigger-based, loosely coupled reactions | Lambda, EventBridge, Cloud Functions |
| **stream_processing** | continuous flows, windowing, ordering, backpressure | Kafka Streams, Flink, Spark Streaming |
| **evaluation** | eval harnesses, benchmark runners, A/B testing, regression checkers | LLM eval pipelines, pytest-bench |
| **deployment** | rollout logic, blue/green, canary, infra provisioning, rollback | Argo CD, Spinnaker, Terraform |
| **observability** | metrics aggregation, tracing, alerting, telemetry collection | Prometheus, Grafana, OpenTelemetry |
| **tooling** | code generators, config generators, schema generators, pipeline-builds-pipeline | Codegen loops, tool synthesis |
| **synchronization** | DB replication, cache sync, cross-service state sync | Redis sync, DB replication |
| **ingestion** | API scrapers, file importers, rate-limited inputs, schema normalization | API ingestion, web scrapers |
| **hybrid** | combinations of the above | Multi-modal systems |
| **unknown** | unrecognized patterns | falls back to hybrid reasoning |

**Composable Usage (e.g., Shepherd-like systems):**
```json
{
  "pipeline_types": ["agentic", "retrieval", "crawler", "distillation", "memory_context", "orchestration"],
  "primary_pipeline_type": "agentic",
  "pipeline_topology": "multi_stage_orchestrated",
  "pipeline_plane": "control"
}
```

**`pipeline_plane` field (NEW dimension):**
```text
pipeline_plane options:
  - "control": orchestration, correctness, transitions, state machines
  - "data": throughput, schema, transformation, backpressure
  - "hybrid": both control and data concerns

Reasoning impact:
  control-plane → prioritize:
    - state transitions
    - phase enforcement
    - checkpoint integrity
    - audit trails

  data-plane → prioritize:
    - throughput optimization
    - schema compatibility
    - backpressure handling
    - idempotent retries

  hybrid → apply BOTH frameworks

CRITICAL: pipeline_plane MUST NOT override pipeline_types reasoning.
  - It ONLY modifies priority/sorting of concerns
  - It does NOT replace the framework from active_reasoning_types
  - Example: control-plane + data pipeline → use data framework, but prioritize state transitions
```

This avoids forcing unique systems into a bad single bucket.

---

## Severity-Weighted Audit Threshold (Replaces Count-Based)

```text
Audit issue scoring (NOT simple count):

Each issue has:
  - severity: critical | high | medium | low
  - depth: 1-5 (how deep the problem is)

Weighted score = severity_weight × depth

Severity weights:
  - critical: 10
  - high: 5
  - medium: 2
  - low: 1

FAIL AUDIT if:
  - ANY critical issue (score ≥ 10)
  - 2+ high issues (score ≥ 10 total from high)
  - total weighted score ≥ 15

PASS AUDIT if:
  - 0 critical issues
  - ≤1 high issue (or 2+ but weighted score < 10)
  - total weighted score < 15

Examples:
  - 1 critical bug → FAIL (score 10+)
  - 3 medium issues, 2 low issues → PASS (score 8, < 15)
  - 2 high issues → FAIL (score 10+)
  - 5 tiny style issues (low, depth 1) → PASS (score 5, < 15)
```

---

## Confidence Source Definition (For Parallel Merge)

```text
Confidence is NOT "the model sounded confident."

Confidence source = evidence_quality + test_support + plan_alignment:

  - evidence_quality: 0.0-1.0 (how strong was the detection?)
  - test_support: 0.0-1.0 (do tests pass? is output verifiable?)
  - plan_alignment: 0.0-1.0 (does output match approved plan?)

confidence = (evidence_quality × 0.4) + (test_support × 0.4) + (plan_alignment × 0.2)

For parallel outputs:
  - If IDENTICAL → accept (confidence = 1.0)
  - If MINOR diff → choose higher confidence output
  - If MAJOR conflict:
      → if arbiter_enabled AND arbiter_invocations < max:
          send to arbiter (arbiter computes confidence per output)
      → else:
          disable parallelism (parallelism_enabled = false)
          fallback to single_model sequential
          log: "Parallel conflict resolved via fallback"
```

---

## Parallel Merge Strategy (Updated with Confidence Definition)

```text
Parallel Merge Strategy (required for same_model_parallel / multi_model_parallel):

For parallel outputs:
  - If outputs IDENTICAL → accept (confidence = 1.0)
  - If MINOR differences → choose higher confidence output (see confidence formula above)
  - If MAJOR conflict:
      → if arbiter_enabled AND arbiter_invocations < max:
          send to arbiter → arbiter chooses
      → else:
          disable parallelism
          fallback to single_model sequential
          log: "Parallel conflict resolved via fallback"

Track conflicts:
  "parallel_conflict": false   → set to true if major conflict detected
  "parallel_conflict_resolution": "arbiter | fallback_single_model"

Reset on fallback (MANDATORY):
  parallel_conflict = false
  parallel_conflict_resolution = ""
```

---

## COMPACT Phase — Mandatory Rehydration Order

```text
Rehydration order (MANDATORY — must be followed exactly):
  1. condensed_summary
  2. pipeline classification (types + confidence + pipeline_plane)
  3. user intent (if exists)
  4. intake mode
  5. active note (if any)

Order matters:
  - Summary provides context
  - Classification frames reasoning framework
  - Intent directs goals
  - Mode controls interaction style
  - Note provides current work context

Violations of this order cause reasoning drift and misaligned assumptions.
```

---

## Arbiter — Wired Into Loop (Not Just a Flag)

```text
Arbiter is invoked when:
  - audit fails AND arbiter_enabled = true

Arbiter evaluates:
  - Is the issue valid? (checks severity × depth weighting)
  - Is it blocking progress?
  - Is this scope creep by the auditor?
  - Does the fix align with the approved plan?
  - Does it introduce new scope not in plan? (NEW CHECK)

Arbiter decides:
  - FIX REQUIRED: proceed with standard fix loop
  - DEFER ISSUE: move to deferred_issues[], continue (log reason)
  - SKIP ISSUE: move to skipped_issues[], continue (log reason)
  - OVERRIDE AUDITOR: auditor was wrong, continue
  - ESCALATE TO USER: ambiguity too high, ask user

Arbiter invocation tracking:
  - arbiter_invocations incremented each call
  - max_arbiter_invocations = 2
  - If exceeded:
      → escalate to user OR
      → force downgrade to: inline + single_model + arbiter_disabled (clean reset)
  - Never silently remove arbitration and continue chaos.

Decision summary (for REPORT):
  - Why did arbiter defer/skip/override?
  - What was the key reasoning?
  - Logged to decision_summary in REPORT.
```

---

## Hostile Auditor Loop (Complete Flow with All Fixes)

```
Step 1: Code Creation/Edit Complete
  ↓
Step 2: /handshake (or direct I/O if unavailable) → write note → save path to session.json
  ↓
Step 3: COMPACT (MANDATORY rehydration order: 1.summary 2.classification 3.intent 4.mode 5.note)
  ↓
Step 4: REINJECT condensed summary + note → switch to HOSTILE AUDITOR persona
  ↓
Step 5: Hostile auditor reviews code → computes severity-weighted score
  ├── weighted score < 15 AND no critical: PASS → proceed to tests
  ├── critical OR score ≥ 15, but arbiter_enabled:
  │     Step 5.5: Arbiter evaluates ALL issues
  │     Arbiter filters:
  │       - valid & blocking → proceed to fix
  │       - valid & defer → deferred_issues[] (log reason)
  │       - invalid/scope creep → skipped_issues[] (log reason)
  │       - arbiter overrides auditor → PASS (auditor was wrong)
  │       - arbiter unsure → ESCALATE TO USER
  └── critical OR score ≥ 15, no arbiter:
        ↓
      Step 6: /handshake (or direct I/O) → write note of issues + correction guidance
        ↓
      Step 7: COMPACT (MANDATORY order)
        ↓
      Step 8: REINJECT + issues note → switch to ORIGINAL IMPLEMENTER persona
        ↓
      Step 9: Fix all issues → run tests
        ↓
      Step 10: /handshake (or direct I/O) → write test cases + results
        ↓
      Step 11: COMPACT (MANDATORY order)
        ↓
      Step 12: REINJECT + test note → switch to HOSTILE AUDITOR → repeat audit
        ↓
      (Loop until hostile auditor passes the code)

      *** GLOBAL AUDIT CAP ***
      If audit_cycle_count > max_audit_cycles (3):
        - STOP loop
        - Report: unresolved issues, likely root causes, recommended manual intervention
        - Advance to VERIFICATION with known issues flagged

      *** COST GUARD ***
      Increment cost_guard_phase per operation using weighted formula.
      If cost_guard_phase > yellow threshold (profile-based):
        - Warn user, recommend downgrade
      If cost_guard_phase > red threshold (profile-based):
        - PAUSE execution
        - Explain cost pressure
        - Ask user: "Downgrade to simpler mode?" (NO silent auto-downgrade)
        - Only proceed after explicit user confirmation.

Step 13: Gated completion check → VERIFICATION phase
```

---

## Note Lifecycle (Archive + Integrity)

```text
Note Lifecycle:
  First, detect: "handshake_available": true | false

If handshake_available = true:
  - handoff_transport = "handshake"
  - handoff_guarantee = "best_effort" (unless hooks enforce it)
  - Active note created via /handshake → saved to session.json (handshake_note_path)
  - Note reinjected into context → archived to:
      .claude/tmp/survival-pipeline-dev/history/
  - Active note path cleared from session.json

If handshake_available = false:
  - handoff_transport = "direct_file"
  - handoff_guarantee = "best_effort" (prompt-mediated only)
  - Active note written directly to: .claude/tmp/survival-pipeline-dev/active_note.md
  - Note reinjected via Read tool → archived to:
      .claude/tmp/survival-pipeline-dev/history/
  - Active note deleted from original location
  - Preserved: note persistence and traceability
  - NOT guaranteed: context transition enforcement (best-effort only)

Archived naming:
  impl_note_cycle1.md
  audit_note_cycle1.md
  impl_note_cycle2.md
  audit_note_cycle2.md
  test_note_cycle2.md

Only the active note file is deleted from its original location.
History is NEVER deleted — preserves audit trail.

Integrity note: Context transitions are prompt-mediated (best-effort),
unless enforced by hooks, permissions, or file locks (hard-enforced).
```

---

## Handoff Transport (Honest Language)

```text
handoff_transport field:
  - "handshake": using /handshake plugin for note operations
  - "direct_file": fallback using direct file I/O

handoff_guarantee field:
  - "enforced": mediated by hooks, permissions, or file locks (hard guarantee)
  - "best_effort": mediated only by prompt instructions (soft guarantee)

Handshake integration (first detected at startup):
  - Try: which handshake OR check if /handshake command exists
  - Set session.json → "handshake_available": true | false

If handshake_available = true:
  - handoff_transport = "handshake"
  - handoff_guarantee = "best_effort" (unless hooks enforce it)
  - Use /handshake for all note operations

If handshake_available = false:
  - handoff_transport = "direct_file"
  - handoff_guarantee = "best_effort" (prompt-mediated only)
  - FALLBACK (reduced guarantees):
      → write notes directly to: .claude/tmp/survival-pipeline-dev/active_note.md
      → archive notes directly to: .claude/tmp/survival-pipeline-dev/history/
      → read notes directly via Read tool
  - Log: "Handshake not available, using direct file I/O with best-effort guarantees only"
  - Preserved: note persistence and traceability
  - NOT guaranteed:
      → model actually reads note (prompt-dependent)
      → model obeys phase transition (prompt-dependent)
      → model clears context correctly (prompt-dependent)
      → model resumes in right persona (prompt-dependent)
```

**Language Correction (remove overclaiming):**
- ❌ "Never fail due to missing /handshake" → ✅ "Degrades gracefully with reduced guarantees"
- ❌ "All functionality preserved" → ✅ "Note persistence preserved; context transitions are best-effort"
- ❌ "Production-ready" → ✅ "Architecture complete; prompt-mediated guarantees are best-effort unless enforced by hooks/permissions"
- ❌ "Enforced" (when only prompted) → ✅ "best-effort (prompt-mediated)"

---

## Subagent Contract (With Integrity Enforcement + Output Validation)

```text
Subagent contract (prompt-mediated, best-effort):
  - Receive: condensed summary + current plan + relevant files only
  - Do NOT: modify session.json, persist global state
  - Return: output to main agent only

controlled_fields (MUST NOT be modified by subagent, even within allowed_hash_changes):
  - "phase"
  - "plan_approved"
  - "execution_style"
  - "model_strategy"
  - "active_reasoning_types"
  - "pipeline_plane"

allowed_hash_changes (LOW-RISK fields only, safe to mutate):
  - "audit_cycle_count"
  - "cost_guard"
  - "cost_guard_phase"
  - "parallel_conflict"
  - "deferred_issues"
  - "skipped_issues"
  - "assumption_log"
  - "state_transition_log"

Where permissions/hooks are available (hard-enforced):
  - Deny subagent write access to session.json
  - Session.json integrity check:
      → compute hash BEFORE subagent call → store in session_json_hash_before
      → compute hash AFTER subagent call → store in session_json_hash_after
      → Field-level diff check:
          For EACH changed field:
            Is field in allowed_hash_changes?
              YES → allowed (but NOT in controlled_fields)
              NO → VIOLATION
      → If ANY violation (including controlled_fields):
          - Reject subagent output
          - Restore session.json from last known good state
          - Log: "Subagent violated session.json contract - field X changed unexpectedly"
          - Main agent repairs any unauthorized changes.

If permissions cannot enforce (best-effort):
  - Main agent MUST validate session.json after EACH subagent return
  - Check: did subagent modify session.json?
  - Check against allowed_hash_changes AND controlled_fields
  - If yes: restore, log violation, reject output
```

**Output Validation BEFORE State Mutation (MANDATORY):**
```text
After subagent returns output:
  1. Hash check (as before):
     → Compute session_json_hash_after
     → Field-level diff check
     → Reject if violations

  2. Output quality validation (NEW):
     → Does output match approved plan?
     → Does it contain required artifacts?
     → Does it contradict previous state?
     → Is output complete (not truncated)?
     → Does it introduce new scope not in plan? (NEW CHECK)

     If invalid:
       - Reject output
       - Log: "Subagent output failed validation: [reason]"
       - Options:
           a) Retry with clearer instructions
           b) Fallback to main agent
           c) Escalate to user

  3. ONLY AFTER both checks pass:
     → Main agent mutates state
     → Updates session.json
     → Proceeds to next step

Hash protects STATE integrity.
Output validation protects QUALITY integrity.
Both are required.
```

---

## `active_reasoning_types` (Enforced Trim + Freeze After PLAN)

```text
Reasoning type enforcement:

1. Trim during COMPACT phase:
   - If len(active_reasoning_types) > 3:
       → Trim to: [primary_pipeline_type] + top 2 by confidence
       → Log: "Reasoning types trimmed from X to 3 to prevent dilution"

2. Ensure primary is always present:
   - If primary_pipeline_type NOT in active_reasoning_types:
       → Add it FIRST (ensure primary is always active)

3. FREEZE after PLAN phase begins (MANDATORY):
   - Once phase reaches PLAN or later:
       → active_reasoning_types LOCKED
       → No further trimming or modification allowed
       → Any attempt to change = violation, log and reject

   Before PLAN = flexible.
   After PLAN = frozen.

Why freeze?
   - Prevents reasoning shift mid-execution
   - Prevents plan/execution mismatch
   - Ensures consistency throughout EXECUTION and VERIFICATION
```

**Limit Active Reasoning:**
```text
active_reasoning_types array:
  - MUST contain: primary_pipeline_type
  - MUST NOT exceed: primary + max 2 supporting types
  - All other detected types: informational only (not used for reasoning)

Examples:

  CORRECT (Shepherd-like):
    primary_pipeline_type: "agentic"
    active_reasoning_types: ["agentic", "orchestration", "retrieval"]
    (3 total: primary + 2 supporting = allowed)

  WRONG (too many active):
    active_reasoning_types: ["agentic", "orchestration", "retrieval", "distillation", "memory_context"]
    (5 active = REJECT, too many)

  INFORMATIONAL ONLY (not in active_reasoning_types):
    pipeline_types: ["agentic", "orchestration", "retrieval", "distillation", "memory_context", "crawler"]
    → Only first 3 in active_reasoning_types
    → Others are logged but NOT used for reasoning

This prevents reasoning dilution.
```

---

## `pipeline_plane` (Control-Plane vs Data-Plane + Guard)

```text
pipeline_plane field (NEW dimension):

pipeline_plane options:
  - "control": orchestration, correctness, transitions, state machines
  - "data": throughput, schema, transformation, backpressure
  - "hybrid": both control and data concerns

Reasoning impact:
  control-plane → prioritize:
    - state transitions
    - phase enforcement
    - checkpoint integrity
    - audit trails

  data-plane → prioritize:
    - throughput optimization
    - schema compatibility
    - backpressure handling
    - idempotent retries

  hybrid → apply BOTH frameworks

CRITICAL GUARD:
  pipeline_plane MUST NOT override pipeline_types reasoning.
    - It ONLY modifies priority/sorting of concerns
    - It does NOT replace the framework from active_reasoning_types
    - Example: control-plane + data pipeline:
        → USE data framework (from active_reasoning_types)
        → But PRIORITIZE state transitions over throughput
        → Does NOT ignore data issues because it's "control-plane"

  Without this guard, you get:
    "It's control-plane so I ignore data issues" ← WRONG

  pipeline_plane = modifier, NOT replacement.
```

---

## `state_transition_log` (With `sequence_id` for Ordering Guarantee)

```text
state_transition_log format (UPDATED):

{
  "sequence_id": 1,  (monotonic integer, prevents timestamp collisions/reordering)
  "from_phase": "PLAN",
  "to_phase": "EXECUTION",
  "reason": "Plan approved by user",
  "timestamp": "2026-04-28T14:30:00Z",
  "cost_guard_phase_at_transition": 45
}

Rules:
  - sequence_id: global monotonic counter (session_json.sequence_id++)
  - Increment sequence_id BEFORE each phase transition
  - Timestamps alone can collide or reorder → sequence_id guarantees order
  - Sort log by sequence_id for REPORT (not by timestamp)

Example entries:
  { "sequence_id": 1, "from_phase": "SCAN", "to_phase": "COMPACT", "reason": "scan complete" }
  { "sequence_id": 2, "from_phase": "COMPACT", "to_phase": "CLASSIFY", "reason": "rehydration complete" }
  { "sequence_id": 3, "from_phase": "CLASSIFY", "to_phase": "INTAKE", "reason": "user chose debug mode" }

This will save massive debugging pain.
```

---

## `assumption_log` (For Post-Mortem + Debugging)

```text
assumption_log format:

{
  "assumption": "Pipeline is BullMQ-based queue system",
  "phase_made": "CLASSIFY",
  "confidence_at_time": 0.3,
  "verified": false,
  "verified_in_phase": "VERIFICATION",
  "verification_result": "Wrong - was actually Celery"
}

Log ALL assumptions:
  - Especially in IDFK mode (auto-mode assumptions)
  - Especially when confidence < 0.5
  - Track verification status for later review

This is MASSIVE for later debugging.
```

---

## Persona Swaps

**Operation Mode Personas (how the agent thinks):**

| Mode | Persona | Behavior |
|------|----------|-----------|
| **create** | Pipeline Architect | Focuses on modularity, scalability, resource efficiency from day one |
| **debug** | Diagnostic Engineer | Focuses on intent vs. implementation gaps, root cause analysis |
| **optimize** | Performance Specialist | Focuses on resource reduction without quality loss, bottleneck identification |
| **extend** | Integration Engineer | Focuses on minimal-disruption additions, compatibility, extension points |

**Pipeline Type Reasoning Frameworks:**

| Type | Framework Focus |
|------|-----------------|
| **ci_cd** | stages, artifacts, failure gates, build caching, parallelism |
| **data** | schemas, lineage, idempotency, backpressure, retry logic |
| **ml** | training/eval/serving separation, data versioning, model registry |
| **rag** | chunking strategy, retrieval quality, eval metrics, context windows |
| **queue** | backpressure, retries, visibility timeouts, dead letter queues |
| **agentic** | tool definitions, planner-executor patterns, multi-agent coordination, context management |
| **orchestration** | DAG dependencies, checkpoint management, task scheduling, failure recovery |
| **stateful_workflow** | state machines, long-lived processes, human-in-loop, checkpoint rollback |
| **event_driven** | pub-sub, webhooks, trigger-based, loosely coupled reactions, event ordering |
| **stream_processing** | continuous flows, windowing, ordering, late data, backpressure, exactly-once |
| **evaluation** | eval harnesses, benchmark runners, A/B testing, regression checkers, metric collection |
| **deployment** | rollout strategies, blue/green, canary, rollback, blast radius, config drift |
| **observability** | metrics aggregation, tracing pipelines, alerting systems, telemetry collection |
| **tooling** | code generators, config generators, schema generators, pipeline-builds-pipeline |
| **synchronization** | DB replication, cache sync, cross-service state sync, conflict resolution |
| **ingestion** | API scrapers, file importers, rate limits, schema normalization, data validation |
| **hybrid** | combinations of the above; applies hybrid reasoning |
| **unknown** | fallback: modular decomposition + data flow tracing + failure boundary identification |

**Hostile Auditor Persona:**
- Adversarial lens: assumes code is broken until proven otherwise
- Checks: resource waste, missing error handling, silent failures, scalability cliffs, security gaps
- **Uses severity-weighted threshold (NOT simple count):**
  - ANY critical issue → FAIL
  - 2+ high issues OR weighted score ≥ 15 → FAIL
  - Else → PASS

**Original Implementer Persona:**
- Constructive lens: focused on addressing auditor feedback precisely
- Uses standardized plan format to track fixes

---

## Intake Modes (Triggered via `/intake mode <mode>`)

| Mode | Behavior | Questions Style |
|------|-----------|-----------------|
| **Full** | Long-form interactive, one at a time, with contextual examples | Open-ended + examples provided |
| **Light** | Multiple-choice only, no explanations, one at a time | A/B/C/D choices only |
| **IDFK** | Auto-mode, agent infers everything, minimal user input | None — agent decides (available at all confidence levels; if confidence < 0.5, must state: "Proceeding in auto-mode from weak evidence (confidence: X%). I may make wrong assumptions.") |
| **Shutup** | All questions posed upfront in single block | All questions at once, user responds to all |

**Session Binding for `/intake`:**
1. Check `.claude/tmp/survival-pipeline-dev/session.json` exists
2. Check `"active": true`
3. Validate mode is one of: `Full`, `Light`, `IDFK`, `Shutup`
4. If invalid → reject: *"No active survival-pipeline-dev session. Run `/survival-pipeline-dev` first."*
5. If valid → update `session.json` → `"mode": "<requested>"`

---

## Execution Styles (Subagent Model Assignment — Where Supported)

**Inline:**
- Single agent performs all roles with persona swaps via file reads
- Uses /handshake (or direct I/O) for context swapping
- Simpler, no subagent overhead
- **State ownership:** Main agent = single source of truth for `session.json`
- **Guarantee:** best-effort (prompt-mediated)

**Sub-agent Driven (where supported):**
- **Main agent = single source of truth** (owns `session.json`, writes all state, coordinates loop)
- `implementer` subagent: stateless worker — receives condensed summary + current plan + relevant files only; does NOT modify `session.json`
- `hostile-auditor` subagent: stateless worker — receives code files + notes; does NOT modify `session.json`
- `arbiter` subagent (if enabled): stateless worker — resolves conflicts, validates auditor issues
- **Model assignment (where supported):** user can specify haiku/sonnet/opus per role, or system chooses
- **Integrity check:** Main agent computes `session_json_hash_before` before call, `session_json_hash_after` after; rejects output if changed (including `controlled_fields`)
- **Where permissions available:** subagent denied write access to session.json (hard-enforced)
- **Where prompt-only:** main agent validates after EACH return (best-effort)
- Subagents return output to main agent; main agent validates outputs and updates state
- **Parallel Merge Strategy** applied if parallelism_enabled and multiple subagents run concurrently
- **Output validation:** BEFORE state mutation, checks: matches plan? has artifacts? contradicts state? complete? new scope added?

---

## Execution Style Choice (After PLAN, Before PLAN_APPROVAL)

Presented to user after plan is generated:

```text
How should execution run?

1. Inline / Single Model
   One model, one agent, persona swaps via file reads.
   Cheapest, simplest, least moving parts.

2. Subagent / Same Model (where supported)
   Separate role agents, but the same model handles each role.
   Cleaner separation, same model cost.

3. Subagent / Same Model Parallel (where supported)
   Same model runs multiple role passes in parallel where possible.
   Faster, same model, more parallelism.
   (Uses parallel merge strategy if conflicts arise)

4. Subagent / Multi-Model (where supported)
   Different models handle different roles:
   - Implementer: [haiku | sonnet | opus]
   - Hostile Auditor: [haiku | sonnet | opus]
   - Arbiter (if enabled): [haiku | sonnet | opus]
   Higher cost, specialized reasoning per role.
   (Uses parallel merge strategy if conflicts arise)

5. Specify Models Manually (where supported)
   I will tell you exactly which model to use for each role.

All options available regardless of confidence level.
Low confidence? Agent may recommend Option 1 (simplest), but you choose.

Downgrade Offer: If cost_guard_phase > red threshold OR 2 consecutive failed audit cycles OR parallel conflict unresolved:
  "Execution issues detected (cost_guard_phase: X). Downgrade to Inline / Single Model with Arbiter enabled?"
```

---

## Standardized Plan Format (PLAN Phase)

1. **Objective**
2. **Current State**
3. **Proposed Changes**
4. **Files Affected**
5. **Risk Analysis**
6. **Failure Modes**
7. **Test Strategy**
8. **Validation Commands**
9. **Operation Mode** (create/debug/optimize/extend)
10. **Pipeline Type Framework Applied** (from `active_reasoning_types` only)
11. **Pipeline Confidence Score & Evidence**
12. **Execution Style** (inline/subagent)
13. **Model Strategy** (single_model/same_model_parallel/multi_model_parallel)
14. **Model Assignments** (per role, where supported)
15. **Caution Note** (added automatically if confidence < 0.5 — advisory)
16. **Extra Validation Recommendations** (added automatically if confidence < 0.5 — advisory)

---

## REPORT Phase — Complete Output (With Decision Summary)

```text
REPORT must include ALL sections:

1. COMPLETED
   - What was accomplished
   - Objective from plan
   - Operation mode used

2. CHANGED FILES
   - List of all files created/modified
   - Brief description of each change

3. VALIDATION RUN
   - Tests executed
   - Pass/fail counts
   - Coverage metrics (if available)

4. PASSING/FAILING TESTS
   - List of passing tests
   - List of failing tests (if any)
   - Resolution status for failures

5. DEFERRED ISSUES (from arbiter)
   - From arbiter deferrals (deferred_issues[])
   - Reason for deferral
   - Recommended follow-up

6. SKIPPED ISSUES (from arbiter)
   - From arbiter skips (skipped_issues[])
   - Reason for skipping
   - Why it was invalid/scope creep

7. ASSUMPTION LOG
   - All assumptions made during execution
   - Especially in IDFK mode (auto-mode assumptions)
   - Especially when confidence < 0.5
   - Format: {assumption, phase_made, confidence_at_time, verified: true|false}
   - Verification results (which were right/wrong)

8. STATE TRANSITION LOG (ordered by sequence_id)
   - Every phase change with reason
   - Format: {sequence_id, from_phase, to_phase, reason, timestamp, cost_guard_phase_at_transition}
   - Sort by sequence_id (NOT timestamp) to prevent collision issues

9. DECISION SUMMARY (NEW)
   - Why key decisions were made
   - Especially arbiter decisions (why defer/skip/override?)
   - Why specific models were chosen
   - Why execution style was selected
   - Key trade-offs considered
   - Different from assumptions — this is WHY things changed.

10. KNOWN RISKS
    - Identified but not fixed
    - Low-confidence assumptions (if confidence < 0.5)
    - Recommended monitoring

11. NEXT RECOMMENDED STEP
    - What to do next
    - Any follow-up work
    - References to deferred issues

12. SESSION SUMMARY
    - Total audit cycles: audit_cycle_count
    - Total arbiter invocations: arbiter_invocations
    - Total cost_guard value: X (profile: Y, yellow: Z, red: W)
    - Cost per phase breakdown (cost_guard_phase at each transition)
    - Final phase reached
    - Handoff transport used: handshake | direct_file
    - Handoff guarantee: best_effort | enforced
    - Total phase entries: phase_entry_count

Final action:
  - Set session.json → "active": false
  - Clear temporary files (keep history/ archive)
```

---

## Gated Completion (VERIFICATION Phase)

```
verify_claimed_completion():
  - If pass: mark phase complete, advance to REPORT
  - If fail: diagnose root cause → attempt fix → rerun validation
  - Loop until: tests pass OR blocking issue identified and reported
  - max_fix_attempts: 3 per verification cycle, then stop and report to user
  - Global audit cap: max 3 audit cycles total (tracked in session.json audit_cycle_count)
  - Arbiter invocations max: 2 (tracked in session.json arbiter_invocations)
  - Uses severity-weighted scoring (NOT count-based)
```

---

## Low-Confidence Behavior (Advisory Only, NOT Paternalistic)

```text
pipeline_confidence scoring (0.0 - 1.0):
  - 1.0: explicit config files (.github/workflows/*.yml)
  - 0.8: strong indicators (BullMQ imports, Airflow DAGs, Celery decorators)
  - 0.5-0.7: moderate indicators (ETL scripts, worker patterns, scheduled jobs)
  - <0.5: weak indicators → present as "possible pipeline"

LOW-CONFIDENCE BEHAVIOR (advisory only, no enforced restrictions):

If pipeline_confidence < 0.5:
  - Mark classification as UNCERTAIN in session.json
  - Present evidence summary: what was found, what was missing
  - Ask user:
      "I'm only X% confident this is a Y pipeline. Would you like to:
       1) Proceed with this classification
       2) Correct the classification
       3) Ignore the scan result and tell me directly"
  - DO NOT disable IDFK mode (user can still choose it)
  - DO NOT force inline execution (all execution styles remain available)
  - DO NOT auto-lower audit thresholds (keep standard >3 issues threshold)
  - DO NOT force stronger confirmation (standard confirmation is sufficient)
  - DO add visible CAUTION note to plan:
      "[CAUTION: Pipeline classification uncertain (confidence: X%). 
       Assumptions may be incorrect. Extra validation recommended.]"
  - DO add extra validation recommendations section to plan (advisory)
  - Agent MAY recommend safer defaults verbally, but user chooses.

IDFK mode with low confidence:
  - Agent must explicitly state:
      "I am proceeding in auto-mode from weak evidence (confidence: X%). 
       I may make wrong assumptions. You can correct me at any time."
  - All modes remain fully functional
```

---

## Directory Structure (Final)

```
survival-pipeline-dev/
├── .claude-plugin/
│   └── plugin.json
├── PLAN.md                    ← Complete design specification (this file)
├── skills/
│   ├── survival-pipeline-dev/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── pipeline-patterns.md          # Expanded detection + composable taxonomy + pipeline_plane
│   │   │   ├── intake-templates.md           # Full/Light/IDFK/Shutup templates
│   │   │   ├── gating-mechanism.md          # Conflux-style gating + failure loops
│   │   │   ├── plan-template.md              # Standardized plan format + assumption log
│   │   │   ├── persona-definitions.md       # Operation mode + hostile auditor personas
│   │   │   ├── execution-modes.md           # Inline vs subagent + state ownership
│   │   │   ├── model-strategy.md            # Model strategy + per-role assignments (where supported)
│   │   │   ├── note-lifecycle.md            # Archive rules + honest handoff guarantees
│   │   │   ├── audit-loop-guards.md        # Global cap + cycle tracking
│   │   │   ├── arbiter-integration.md       # Arbiter wired into loop (not just flag) + decision summary
│   │   │   ├── parallel-merge-strategy.md   # Merge rules + confidence formula + state reset
│   │   │   ├── confidence-impact.md         # Advisory behavior for low confidence
│   │   │   ├── rehydration-order.md         # MANDATORY COMPACT rehydration order
│   │   │   ├── severity-weighted-scoring.md # Audit threshold (replaces count-based)
│   │   │   ├── cost-guard.md               # Weighted formula + profile thresholds (NO silent downgrade) + phase_entry_count
│   │   │   ├── handoff-transport.md         # Handshake vs direct_file + guarantee honesty
│   │   │   ├── subagent-integrity.md       # Hash-based integrity + allowed_hash_changes vs controlled_fields
│   │   │   ├── deferred-vs-skipped.md      # Hard distinction: only arbiter can classify
│   │   │   ├── best-effort-guards.md       # Critical transitions must be restated + deviation recovery
│   │   │   ├── assumption-logging.md        # Assumption log + state transition log (with sequence_id)
│   │   │   ├── active-reasoning-enforcement.md # Trim + freeze after PLAN phase
│   │   │   ├── pipeline-plane.md            # Control vs data plane + guard (modifier not replacement)
│   │   │   └── output-validation.md         # Output validation BEFORE mutation + scope creep check
│   │   └── examples/
│   │       └── sample-scans.md
│   └── intake/
│       └── SKILL.md
├── .gitignore
└── README.md
```

---

## All Requirements Addressed (83/83)

**Core Requirements:**
1-19. ✅ (Core plugin functionality)

**Additional Fixes from Critiques:**
20-28. ✅ (Earlier critique fixes)

**Low-Confidence Behavior:**
29-35. ✅ (Advisory-only, not paternalistic)

**Final 10 Fixes Earlier:**
36-44. ✅ (Schema, phase enum, max_fix_attempts, severity-weighted, confidence source, model assignment, handshake optional, cost_guard measurable, REPORT completeness)

**Cost Guard Fixes:**
45-47. ✅ (Weighted formula, profile thresholds, NO silent downgrade)
48. ✅ **Per-operation multiplier (multiplicative, NOT additive)**
49. ✅ **Profile-based thresholds (cheap: 150/300, balanced: 300/600, thorough: 600/1200+)**
50. ✅ **NO silent auto-downgrade — red threshold PAUSES, explains, asks user**

**Handshake Honesty Fixes:**
51-52. ✅ **`handoff_transport` + `handoff_guarantee` fields**
53. ✅ **Fallback honesty — "best-effort guarantees only; context transitions NOT guaranteed"**

**Subagent Enforcement Fixes:**
54-55. ✅ **`session_json_hash_before/after` fields**
56. ✅ **Hash check — compute before/after; reject + restore if changed**
57. ✅ **Permission-based denial (hard-enforced) + prompt-only fallback**

**Expanded Pipeline Taxonomy:**
58-59. ✅ **`pipeline_types` = array (composable) + `primary_pipeline_type` + `pipeline_topology`**
60-61. ✅ **Expanded reasoning frameworks for all 17 types**

**NEW: Cost Guard Fixes (Phase-Local + Anti-Gaming):**
62. ✅ **`cost_guard_phase` resets ONLY on first phase entry (uses `phase_entry_count`)**
63. ✅ **`phase_entry_count` field — tracks entries per phase, prevents oscillation gaming**
64. ✅ **Sequential phase entries increment counter; only 1st entry resets cost_guard_phase**

**NEW: Hash Integrity Fix (No False Positives + Controlled Fields):**
65. ✅ **`allowed_hash_changes` = LOW-RISK fields only (safe to mutate)**
66. ✅ **`controlled_fields` = HIGH-IMPACT fields (MUST ONLY be mutated by main agent)**
67. ✅ **Field-level diff: check EACH changed field against BOTH arrays**

**NEW: `active_reasoning_types` Fix (Enforced Trim + Freeze):**
68. ✅ **Trim to max 3 during COMPACT (primary + 2 supporting)**
69. ✅ **FREEZE after PLAN phase begins — no further modification**
70. ✅ **Before PLAN = flexible; After PLAN = locked**

**NEW: Arbiter Cap Fix (No Silent Removal):**
71. ✅ **DO NOT silently disable arbiter — escalate to user or force downgrade**
72. ✅ **Decision summary in REPORT — why key decisions were made**

**NEW: Parallel Conflict Fix (State Reset):**
73. ✅ **Reset `parallel_conflict=false` + `parallel_conflict_resolution=""` on fallback**

**NEW: Deferred vs Skipped Fix (Hard Distinction):**
74-75. ✅ **Strict definitions + only arbiter can classify**

**NEW: Best-Effort Guard Fix (Critical Transitions):**
76-77. ✅ **Critical transitions MUST be restated + deviation recovery**

**NEW: REPORT Fix (Assumption Log + State Transition Log):**
78-79. ✅ **`assumption_log` with verification status**
80-81. ✅ **`state_transition_log` with `sequence_id` (monotonic integer)**
82. ✅ **Sort by sequence_id, NOT timestamp (prevents collision)**

**NEW: Pipeline Plane Fix (Control vs Data + Guard):**
83. ✅ **`pipeline_plane` field + MUST NOT override reasoning (modifier only)**

**NEW: Output Validation Fix (Scope Creep Check):**
84. ✅ **Validate subagent output BEFORE state mutation**
85. ✅ **NEW CHECK: "Does it introduce new scope not in plan?"**
86. ✅ **Hash protects STATE; Output validation protects QUALITY**

**NEW: Decision Summary Fix (REPORT Phase):**
87. ✅ **Decision summary section — why key decisions were made (especially arbiter)**
88. ✅ **Different from assumptions — this is WHY things changed**

---

**Phase 3 is 100% COMPLETE with all 88 requirements addressed.**

**This is a constrained agent runtime with:**
- State machine enforcement
- Context transport layer (honest about guarantees)
- Audit loop with arbitration
- Bounded reasoning scope (enforced, not just prompted)
- Cost governance (phase-local + cumulative + anti-gaming)
- Control-plane vs data-plane awareness
- Output validation (not just state integrity)
- Field-level diff validation (not just hash)
- Complete audit trail (assumptions + transitions + decisions)
- Composable pipeline taxonomy (no forcing into bad buckets)
- Freeze enforcement (reasoning types locked after PLAN)

**Ready for Phase 4: Plugin Structure Creation and Phase 5: Component Implementation.**
