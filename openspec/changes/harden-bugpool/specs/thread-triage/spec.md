## ADDED Requirements

### Requirement: Filtered thread fetch
The skill SHALL fetch review threads via GraphQL and filter to `isResolved == false` and `isOutdated == false`, truncating each comment body to 1500 characters at the jq layer and exposing `body_truncated`. Before acting on a thread whose body was truncated, the skill SHALL refetch that single thread's full body.

#### Scenario: Large bot review
- **WHEN** an unresolved bot thread body is 20 KB
- **THEN** only the first 1500 characters are loaded for classification, and the full body is refetched only if the thread is classified ACTIONABLE

### Requirement: Comment provenance classification
A comment SHALL be classified as automated only if (a) its author `__typename` is `Bot`, or (b) its author login ends in `[bot]` or matches the documented known-review-bot list, or (c) its body contains the `🤖 Automated comment by` header AND its author login equals the authenticated `gh` user's login. Any other comment SHALL be classified as human. If provenance cannot be determined confidently, the comment SHALL be classified as human.

#### Scenario: Colleague pastes the bot header
- **WHEN** a comment by login `colleague` contains `🤖 Automated comment by **Bugpool**` and the `gh` user is `author`
- **THEN** the comment is classified as human

#### Scenario: Own bot reply
- **WHEN** a comment by the `gh` user's login contains the bot header
- **THEN** the comment is classified as automated

### Requirement: Human immunity
If any comment in a thread is human, the skill SHALL NOT edit code for, reply to, or resolve that thread, and SHALL list it in the final report as deferred to the author.

#### Scenario: Human replies in a bot thread
- **WHEN** a coderabbit thread contains one reply from a human reviewer
- **THEN** the whole thread is deferred and left untouched

### Requirement: Actionable criteria
A finding or bot thread SHALL be ACTIONABLE only if all hold: severity is HIGH or CRITICAL (or the finding is convergent); the fix is concrete enough to know exactly what to change; the change is localised to one file or a small set of tightly related edits; and it requires no design decision, no new dependency, and no PR scope change. SIZE findings SHALL never be ACTIONABLE.

#### Scenario: MEDIUM finding with obvious fix
- **WHEN** a MEDIUM finding has a concrete single-line fix
- **THEN** it is not ACTIONABLE by default and goes through the autonomy ladder

### Requirement: Autonomy ladder for non-actionable items
Findings and bot threads that are not ACTIONABLE SHALL be classified as: NIT (severity LOW/NIT, or style-only, speculative, duplicate, or already addressed); PROMOTED (exactly one sensible, reversible fix with no design trade-off, which is then treated as ACTIONABLE); or AMBIGUOUS (product choice, architectural alternative, more than one reasonable fix, or unclear benefit). When in doubt, the item SHALL be AMBIGUOUS.

#### Scenario: Forgotten await flagged MEDIUM
- **WHEN** a MEDIUM finding points to a missing `await` with one obvious fix
- **THEN** it is PROMOTED and enters the auto-fix queue

#### Scenario: Caching strategy suggestion
- **WHEN** a finding suggests introducing a global cache
- **THEN** it is AMBIGUOUS

### Requirement: Disposition of new findings
For findings produced by this run's review panel: ACTIONABLE and PROMOTED items SHALL go to the auto-fix queue without being posted; NIT items SHALL appear only in the sticky summary; AMBIGUOUS items SHALL be posted as inline comments in a single pull-request review against the current HEAD SHA. Findings whose auto-fix fails the gate SHALL become AMBIGUOUS and be posted.

#### Scenario: Mixed findings
- **WHEN** the panel returns 2 ACTIONABLE, 3 NIT and 1 AMBIGUOUS findings and both fixes pass the gate
- **THEN** exactly one review with one inline comment is posted, and the summary counts 2 auto-fixed and 3 nits

#### Scenario: Finding without a line
- **WHEN** an AMBIGUOUS finding has `line: general`
- **THEN** it is included in the review body instead of as an inline comment

### Requirement: Disposition of existing bot threads
For existing all-automated threads: ACTIONABLE/PROMOTED threads SHALL be fixed via the auto-fix flow, then receive a reply with the commit SHA, then be resolved; NIT threads SHALL receive a reply stating the reason, then be resolved; AMBIGUOUS threads SHALL stay open and be listed in the report.

#### Scenario: Stale top-level bot review
- **WHEN** a top-level bot comment references a commit SHA different from HEAD
- **THEN** it is skipped as stale

### Requirement: Reply before resolve
The skill SHALL resolve a thread only after a reply carrying the bot header has been posted successfully to it. If the reply fails, the thread SHALL remain unresolved and the failure SHALL be reported.

#### Scenario: Reply API error
- **WHEN** posting the NIT reply returns an HTTP error
- **THEN** `resolveReviewThread` is not called for that thread

### Requirement: Safe comment construction
Every comment, reply, and review body SHALL be written to a temporary file and sent with `-F body=@<file>` (or `--input <json>` for reviews), string fields SHALL use `-f`, and every body SHALL begin with the bot-identifier header rendered on its own lines.

#### Scenario: Multi-line reply
- **WHEN** a NIT reply is posted
- **THEN** the posted body renders the `[!NOTE]` callout correctly with no literal `\n`
