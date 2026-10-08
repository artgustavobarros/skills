## ADDED Requirements

### Requirement: Explicit model dispatch
The skill SHALL instruct the orchestrator to dispatch the router, every lens, and any escalation as separate Agent invocations with an explicit `model` parameter, and SHALL NOT allow the orchestrator to perform those reviews inline on the session model.

#### Scenario: Router dispatched as an agent
- **WHEN** the review panel starts
- **THEN** the orchestrator spawns one router Agent with `model: sonnet` and passes it the diff, changed-file list, commit log, PR title/body and project context

#### Scenario: Harness rejects a model alias
- **WHEN** the harness does not accept the requested model alias
- **THEN** the orchestrator maps the role to the nearest accepted tier (entry reviewer at the bottom, escalation at the top), records the substitution in the summary, and never falls back to `haiku` for the router

### Requirement: Model ladder
The router and lenses SHALL run on `sonnet` and escalation SHALL run on `opus`. The skill SHALL NOT assign the router to `haiku`.

#### Scenario: Escalation on conflict
- **WHEN** two lenses disagree on a CRITICAL or HIGH finding, or high-risk auth/concurrency logic lacks consensus
- **THEN** the orchestrator dispatches one escalation Agent on `opus` scoped to the disputed finding and adopts its determination

### Requirement: Objective delegation triggers
The router SHALL delegate to at least one lens whenever the diff exceeds 150 changed lines or touches auth, authorization, sessions, secrets, database schema or migrations, destructive writes, concurrency, payments/billing, or deploy/release configuration, regardless of the danger grade it assigned itself. Below these triggers the router MAY close the review alone.

#### Scenario: Small low-risk diff
- **WHEN** the diff is 80 lines and touches only UI components
- **THEN** the router may return an empty delegation plan and its findings are the review

#### Scenario: Sensitive diff graded LOW
- **WHEN** the router grades a 60-line diff touching a migration as LOW danger
- **THEN** the router still emits a delegation to at least the `security` lens scoped to the migration hunks

#### Scenario: Mid-size diff
- **WHEN** the diff is 170 changed lines with no sensitive paths
- **THEN** the router delegates at least one lens (no size band is left without a rule)

### Requirement: Lenses do not spawn agents
Lens and escalation agents SHALL NOT spawn sub-agents; only the orchestrator dispatches agents.

#### Scenario: Lens prompt
- **WHEN** a lens agent is dispatched
- **THEN** its prompt states that it is the sole reviewer for its scope and must not launch further agents

### Requirement: Two-pass categorisation without gating
Every finding SHALL be tagged `pass: 1` (security, reliability, correctness, LLM boundaries) or `pass: 2` (maintainability, consistency, performance, tests, complexity). All selected lenses SHALL run in the same round regardless of Pass 1 results. Pass 1 findings SHALL be processed first by triage and auto-fix.

#### Scenario: Router finds a blocker
- **WHEN** the router reports a CRITICAL Pass 1 finding
- **THEN** delegated lenses (including `security`) still run in that round

#### Scenario: Pass 2 auto-fix withheld
- **WHEN** a Pass 1 CRITICAL or HIGH finding remains unresolved after the auto-fix step
- **THEN** no Pass 2 finding is auto-fixed in that round and Pass 2 findings are reported only

### Requirement: Single severity scale
Findings SHALL use exactly CRITICAL, HIGH, MEDIUM, LOW, or NIT. The skill SHALL document the mapping: MUST FIX = CRITICAL or HIGH; SHOULD FIX = MEDIUM; NIT = LOW or NIT.

#### Scenario: Lens returns Yooh vocabulary
- **WHEN** a lens labels a finding "MUST FIX"
- **THEN** the orchestrator normalises it to HIGH (or CRITICAL if it is a security/data-loss issue) before triage

### Requirement: SIZE-1..6 rubric matches the source
The size rubric SHALL use Yooh's numbering and thresholds: SIZE-1 function length (WARN ≥40, BLOCK ≥80 lines), SIZE-2 file length (WARN ≥351, BLOCK ≥500), SIZE-3 nesting (WARN ≥4 levels), SIZE-4 parameters (WARN >3), SIZE-5 flag arguments (BLOCK), SIZE-6 God class (INFO >10 public or >20 total methods). BLOCK SHALL map to HIGH, WARN to MEDIUM, INFO to LOW. SIZE findings SHALL apply only to code changed in the PR.

#### Scenario: Long function
- **WHEN** a changed function has 85 non-blank, non-comment lines
- **THEN** a `SIZE-1 (BLOCK)` finding with severity HIGH and `pass: 2` is emitted citing `file:line`

#### Scenario: Unchanged legacy file
- **WHEN** a 900-line file is touched by a one-line change
- **THEN** SIZE-2 is reported at most as LOW with a note that the file predates the PR

### Requirement: Project context and API verification
The orchestrator SHALL pass the repository's AGENTS.md and/or CLAUDE.md (if present) and the dependency manifest to every reviewer. Reviewers SHALL verify uses of framework APIs against the installed version (e.g. bundled docs under `node_modules/<pkg>/`, type definitions) before flagging or accepting them.

#### Scenario: Project declares non-standard framework version
- **WHEN** AGENTS.md says the framework has breaking changes and points to bundled docs
- **THEN** the LLM-boundaries check consults those docs before reporting a hallucinated or deprecated API

### Requirement: Stack lens detects the stack
The `stack` lens SHALL derive its checklist from the detected stack (manifests, config files). The React/Next.js checklist (useEffect necessity, server/client boundary, serialization, hydration) SHALL apply only when React/Next.js is detected.

#### Scenario: Non-React repository
- **WHEN** the repository has no React dependency
- **THEN** the stack lens does not emit React-specific findings

### Requirement: Structured findings format
Every reviewer SHALL end with a `STRUCTURED_FINDINGS` block where each entry has `file`, `line` (number or `general`), `severity`, `pass`, `category`, `rule` (optional, e.g. `SIZE-1`), `reviewer`, and `body` (issue, evidence, suggested fix, why), followed by `OVERALL_SUMMARY`; or `(none)` when empty. Each finding SHALL satisfy the constructive-friction checks (concrete, actionable, evidence at `file:line`, false-positive check).

#### Scenario: Deduplication
- **WHEN** two reviewers report the same concern within 5 lines of the same file
- **THEN** the orchestrator merges them into one finding marked `convergent` with the higher severity
