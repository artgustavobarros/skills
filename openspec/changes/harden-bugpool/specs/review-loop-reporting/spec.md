## ADDED Requirements

### Requirement: Bounded review rounds
After a round that pushed at least one fix, the skill SHALL start another round that reviews only the diff between the round's starting SHA and the new HEAD, and re-triages threads. The skill SHALL stop when a round produces no new ACTIONABLE/PROMOTED item, when the round cap (3) is reached, when the PR is MERGED or CLOSED, or when the run is review-only.

#### Scenario: Fix introduces a new issue
- **WHEN** round 1's fix commit introduces a HIGH finding
- **THEN** round 2 reviews only that fix's diff and handles the finding

#### Scenario: Cap reached
- **WHEN** three rounds have run and actionable items remain
- **THEN** the skill stops and reports the remaining items as AMBIGUOUS

### Requirement: Idempotent state
The sticky summary SHALL embed a hidden machine-readable state marker containing the round number, the reviewed HEAD SHA, and fingerprints (file + rule/category + normalised body hash) of findings already posted. On start, if HEAD equals the recorded SHA and there are no new unresolved threads, the skill SHALL report "nothing to do" and exit without posting. The skill SHALL NOT post a finding whose fingerprint is already recorded.

#### Scenario: Re-run on same HEAD
- **WHEN** `/bugpool` is run twice with no new commits or threads
- **THEN** the second run posts nothing and says there is nothing to do

#### Scenario: Re-run after push
- **WHEN** the author pushes new commits and runs `/bugpool` again
- **THEN** the round number increments and previously posted ambiguous findings are not duplicated

### Requirement: Sticky summary
The skill SHALL maintain exactly one top-level PR comment marked `<!-- bugpool-summary -->`, updated in place (PATCH) or created when absent. It SHALL show verdict, quality score and grade, one row per reviewer that actually ran in the round (omitting the rest), any scope drift warning, actions taken (auto-fixed with SHAs, nits, human threads untouched, ambiguous pending), the NIT list, and a collapsed history whose lines are derived from the previous summary's header and history.

#### Scenario: Router-only round
- **WHEN** the router delegated no lens
- **THEN** the reviewer table contains only the router row

### Requirement: Reproducible quality score
The quality score SHALL be computed per dimension using Yooh's eight dimensions and weights (Security 20, Correctness 18, Reliability 14, Tests 14, Complexity & Size 10, Consistency 8, Comprehension 8, Performance 8). Each dimension starts at 100 and loses CRITICAL −35, HIGH −25, MEDIUM −15, LOW −5, NIT −1 (floor 0) for findings still open at the reviewed HEAD. Overall = Σ(score × weight) / 100, rounded. Grades SHALL be A 90–100, B 75–89, C 60–74, D 40–59, F 0–39.

#### Scenario: One open HIGH security finding
- **WHEN** the only open finding is a HIGH security finding
- **THEN** Security scores 75 and the overall score is 95

### Requirement: Verdict rule
The verdict SHALL be REQUEST CHANGES if any CRITICAL/HIGH finding remains open, the overall score is below 70, or any dimension is below 50; APPROVE WITH NITS if only MEDIUM/LOW/NIT findings remain; otherwise APPROVE. The skill SHALL post verdicts only as comments, never as GitHub approving or blocking review events.

#### Scenario: Only nits remain
- **WHEN** all remaining findings are NIT
- **THEN** the verdict is APPROVE WITH NITS and the review event is `COMMENT`

### Requirement: Scope drift
The skill SHALL compare changed files and commits with the PR title and body and SHALL include a scope-drift warning in the summary when files unrelated to the stated goal are modified.

#### Scenario: Drive-by refactor
- **WHEN** a PR titled "fix login redirect" also rewrites an unrelated reports module
- **THEN** the summary shows a scope-drift warning naming the unrelated files

### Requirement: Terminal report
The skill SHALL end with a terminal report in the user's language listing PR, score and grade, counts (auto-fixed, nits, human deferred, ambiguous), the counts reconciling with every unresolved thread fetched, and an itemised list of human and ambiguous items with `file:line` and a one-line reason.

#### Scenario: Reconciliation
- **WHEN** 7 unresolved threads were fetched
- **THEN** the report's resolved + actioned + deferred counts sum to 7

### Requirement: Progress narration
The skill SHALL emit one short `[bugpool] <step> — <what>` line before each step and before any action expected to take more than a few seconds.

#### Scenario: Lens dispatch
- **WHEN** lenses are dispatched
- **THEN** a line such as `[bugpool] review — dispatching security + qa lenses on 3 files` is printed first
