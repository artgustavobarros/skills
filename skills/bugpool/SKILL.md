---
name: bugpool
description: >
  Self-review swarm for your own GitHub pull request. A router reviewer screens the
  diff and delegates to specialist lenses (architecture, QA, stack, security); findings
  are triaged together with existing bot review threads. Clear, localised fixes are
  applied locally behind a typecheck/lint/test gate and pushed once per round; nits go
  to a single sticky summary; only ambiguous items are posted for the author. Threads
  with human participants are never touched. Use for /bugpool, PR self-review, or
  automated cleanup of bot review threads.
argument-hint: "[pr-number|pr-url] [--review-only] [--allow-foreign]"
disable-model-invocation: true
license: TBD
metadata:
  version: "2.0.0"
---

# Bugpool

Bugpool reviews a pull request before a human reviewer spends time on it. It
fixes what is clearly fixable, keeps nits out of the PR, and posts only the
items that need the author's judgement. It loops until nothing autonomous is
left, or until the round cap.

```
 context ─▶ state & preconditions ─▶ review panel ─▶ triage ─▶ auto-fix ─▶ publish ─▶ score & sticky
    ▲                                                                                     │
    └──────────────── next round (diff of bugpool's own fixes only, max 3) ◀──────────────┘
```

Where each item ends up:

| Item                              | Destination                                                 |
|-----------------------------------|-------------------------------------------------------------|
| New finding, ACTIONABLE/PROMOTED  | fixed locally → gate → commit → pushed (not posted)         |
| New finding, NIT                  | sticky summary only                                         |
| New finding, AMBIGUOUS            | one inline comment in a single PR review                    |
| Bot thread, ACTIONABLE/PROMOTED   | fixed → pushed → reply with SHA → resolved                  |
| Bot thread, NIT                   | reply with reason → resolved                                |
| Bot thread, AMBIGUOUS             | left open, listed in the report                             |
| Any thread with a human in it     | untouched, listed in the report                             |

## Non-negotiable rules

1. **Bot header.** Every body posted to GitHub (review, inline comment, reply,
   sticky) starts with:
   ```markdown
   > [!NOTE]
   > 🤖 Automated comment by **Bugpool** — not written by a human
   ```
2. **Human immunity.** If any comment in a thread is human (see *Provenance* in
   Step 4), never edit code for it, never reply to it, never resolve it.
3. **No local writes without verified preconditions.** Every file edit, `reset`,
   `clean`, commit or push requires the Step 2 preconditions, re-checked
   immediately before each fix.
4. **Reply before resolve.** Resolve a thread only after a reply to it was posted
   successfully. Post replies that reference a commit only after that commit was
   pushed.
5. **Comments only.** Every review bugpool posts uses event `COMMENT`. Bugpool
   never approves a PR or blocks it on GitHub.
6. **When in doubt, defer.** An unclear provenance counts as human. An unclear
   classification counts as AMBIGUOUS. A doubt about whether a fix is safe means
   no fix.

## Narration

Before every step, and before any action that may take more than a few
seconds, print one line: `[bugpool] <step> — <what and why>`. Examples:

```
[bugpool] context — PR #42 is on another branch, running gh pr checkout
[bugpool] preconditions — working tree not clean, continuing as review-only
[bugpool] review — router delegated security + qa on 3 files
[bugpool] fix — 2/3 gate passed (pnpm typecheck, lint, vitest related), committed 1a2b3c4
```

Write narration and the final report in the user's language. Comments posted to
GitHub follow the language of the PR description.

## Roles and models

Dispatch every reviewer with the **Agent tool and an explicit `model`**. Never
run the review inline on the session model: the ladder exists to control cost
and to give each reviewer an independent context.

| Role        | Model    | Job                                                          |
|-------------|----------|--------------------------------------------------------------|
| Router      | `sonnet` | full Pass 1 review, danger grade, delegation plan            |
| Lenses      | `sonnet` | focused review of a delegated scope                          |
| Escalation  | `opus`   | settles CRITICAL/HIGH disagreements and unclear auth/concurrency |

- If the harness rejects an alias, map by tier: router and lenses on the
  harness's mid tier, escalation on its top tier. For example, Gemini-based
  harnesses use `pro` and `pro` with high reasoning. Record the substitution in
  the sticky summary.
- **Never put the router on the cheapest tier (`haiku`, `flash`).** Cheap
  runners skip steps often enough that the reruns cost more than they save, and
  the router owns the critical pass.
- **Only the orchestrator (you) dispatches agents.** Every agent prompt says:
  "You are the sole reviewer for this scope. Do not launch other agents."
- Run independent lenses in parallel: one message, several Agent calls.

## Step 0 — Parse arguments

`$ARGUMENTS` may contain a PR number or URL and the flags `--review-only` and
`--allow-foreign`. Without a PR, use the PR of the current branch.

## Step 1 — Context

Read `references/github-api.md` now. Use its recipes for every `gh` call.

1. Get `<viewer>` (`gh api user`) and the PR fields: number, url, title, body,
   author, headRefName, baseRefName, headRefOid, state, isCrossRepository.
   - If there is no PR, run in **local mode**: diff against `origin/main` (or
     `origin/master`), skip every GitHub write, and print the report only.
   - If the state is `MERGED` or `CLOSED`, report it and stop.
2. If the current branch is not `headRefName`: run `gh pr checkout <n>` only if
   `git status --porcelain` is empty. Otherwise stop and ask the user to commit
   or stash first, because diffing the wrong branch is useless.
3. `git fetch origin <baseRefName> <headRefName>`. Collect the changed files,
   the stat, the full diff and the log against `origin/<baseRefName>`. Never
   diff against a local base branch, which may be stale.
4. **Project context.** Read `AGENTS.md` and/or `CLAUDE.md` at the repo root (if
   present) and the dependency manifest (`package.json`, `pyproject.toml`,
   `go.mod`, …). If a project file points to bundled framework docs (for
   example `node_modules/<pkg>/dist/docs/`), note that path for the reviewers.
5. **Scope drift.** Compare the changed files and commits with the PR title and
   body. List the files that have no clear relation to the stated goal, and
   drive-by refactors inside a targeted fix. Record them for the summary; drift
   is reported, never auto-fixed.

## Step 2 — State and preconditions

**2a. Idempotency.** Find the sticky summary authored by `<viewer>` and parse its
state marker (`references/github-api.md` → *State marker*): round, reviewed
SHA, fingerprints of already-posted findings. If HEAD equals the recorded SHA
and no unresolved thread is newer than the sticky, print "nothing to do since
<short sha>" and stop. Otherwise set `round = previous round + 1` (or 1).

**2b. Auto-fix preconditions.** Auto-fix is enabled only if **all** of these
hold:

- `--review-only` was not passed;
- `git status --porcelain` prints nothing;
- the current branch equals `headRefName`;
- `git rev-parse HEAD` equals `headRefOid`;
- the PR author equals `<viewer>` and `isCrossRepository` is false, or
  `--allow-foreign` was passed.

If any check fails, continue in **review-only mode** and state which check
failed in the narration, in the summary and in the report.

**2c. Gate detection.** Build the local gate:

| Lockfile                     | Runner |
|------------------------------|--------|
| `pnpm-lock.yaml`             | `pnpm` |
| `yarn.lock`                  | `yarn` |
| `bun.lock` / `bun.lockb`     | `bun`  |
| `package-lock.json` or none  | `npm run` |

From the `package.json` scripts, take whichever exist:

- **typecheck:** `typecheck`, `type-check`, `tsc`, `check-types`
- **lint:** `lint`, `check`
- **test:** `test`

For the test step, when the runner supports it, prefer a related-files run (for
example `npx vitest related --run <files>`, `npx jest --findRelatedTests
<files>`). Otherwise run the full `test` script and note its duration.

A missing script is skipped, not counted as a failure. Without a
`package.json`, use the check command that AGENTS.md or CLAUDE.md documents. If
no command can be found, auto-fix is **disabled** ("no local gate"), and every
ACTIONABLE item is handled as AMBIGUOUS.

## Step 3 — Review panel

In rounds ≥ 2, the panel reviews only `git diff <round_start_sha>..HEAD`, that
is, bugpool's own fixes from the previous round.

### 3a. Router

Dispatch one router Agent (`model: sonnet`). Its prompt contains: the diff,
changed files, commit log, PR title and body, the project context from Step 1,
the *Reviewer contract* below, and these instructions:

- Read at least 50 lines of surrounding code for every hunk before judging.
- Do a complete **Pass 1** review: security, reliability, correctness, and LLM
  boundaries (hallucinated APIs, non-existent methods, wrong signatures). Check
  framework API usage against the installed version (types, bundled docs), not
  against memory.
- Grade danger as `LOW|MEDIUM|HIGH|CRITICAL`, then return a delegation plan:

```
DELEGATION_PLAN:
danger: <LOW|MEDIUM|HIGH|CRITICAL>
confidence: <HIGH|MEDIUM|LOW>
delegations:
- lens: <architecture|qa|stack|security> | scope: <files/hunks or "full"> | reason: <one line>
(empty list if none)
```

**Objective triggers.** The plan must contain at least one delegation when the
diff has **more than 150 changed lines**, or touches any of: auth or
authorization, sessions, secrets or crypto, database schema or migrations,
destructive writes, concurrency or shared mutable state, payments or billing,
deploy/release/CI configuration. A sensitive area requires the `security` lens,
scoped to those hunks.

These triggers apply **whatever danger grade the router gave**, because the
grade is the thing being checked. Below the triggers, an empty plan is the
cheap path working as intended. If the router returns an empty plan despite a
trigger, add the delegation yourself.

### 3b. Lenses

Dispatch each delegation (`model: sonnet`), in parallel, with its scoped diff,
the project context, and the *Reviewer contract*.

- **architecture:** maintainability, tech debt added vs paid down, design
  simplicity, coupling, SIZE-2 / SIZE-6.
- **qa:** edge cases, error paths, boundary values, async races, and whether
  the tests cover the change (in the project's test framework).
- **stack:** a checklist derived from the detected stack (manifest and config
  files). If React/Next.js is present, include: a necessity check on every
  `useEffect` (could the value be derived during render, or handled in an event
  handler?), server/client boundaries, serialization across the boundary,
  hydration risks. Add SIZE-1, SIZE-3, SIZE-4, SIZE-5, and schema-validation
  adherence when the project uses a validator. Do not emit framework findings
  for frameworks that are not present.
- **security:** IDOR, SSRF, injection (including ORM/query-builder misuse),
  auth/session leaks, secrets, unsafe mutations, tenant isolation.

Lenses that check SIZE rules read `references/size-rubric.md`.

### 3c. Escalation

If two reviewers disagree on a CRITICAL or HIGH finding, or high-risk
auth/concurrency logic has no clear consensus, dispatch one Agent
(`model: opus`). Scope it to the disputed hunks and both arguments, and adopt
its determination. Cap: 2 escalations per round.

### Reviewer contract (include in every reviewer prompt)

Every finding must pass the constructive-friction checks: it is concrete (exact
code, exact behaviour), actionable (the author knows what to change), backed by
evidence at `file:line` rather than taste, and checked for false positives.
Do not bikeshed.

**Severity scale.** Use only these values:

| Severity | Equivalent  | Use for                                                      |
|----------|-------------|--------------------------------------------------------------|
| CRITICAL | MUST FIX    | exploitable security hole, data loss, crash on a main path   |
| HIGH     | MUST FIX    | correctness bug, reliability gap, unsafe migration, SIZE BLOCK |
| MEDIUM   | SHOULD FIX  | performance, missing important test, smell, SIZE WARN        |
| LOW      | NIT         | minor improvement, SIZE INFO, pre-existing issue             |
| NIT      | NIT         | style, naming, wording                                       |

**Pass tag.** `pass: 1` for security, reliability, correctness and LLM
boundaries. `pass: 2` for maintainability, consistency, performance, tests and
complexity.

End the response with exactly:

```
STRUCTURED_FINDINGS:
- file: <path> | line: <number|general> | severity: <CRITICAL|HIGH|MEDIUM|LOW|NIT> | pass: <1|2> | category: <category> | rule: <SIZE-n or -> | reviewer: <tag> | body: <issue · evidence · suggested fix · why>
(or "(none)")

OVERALL_SUMMARY:
<one paragraph>
```

### 3d. Synthesis

- Normalise any other vocabulary (for example "MUST FIX" → HIGH, or CRITICAL
  for security/data loss; "SHOULD FIX" → MEDIUM).
- Merge findings about the same concern within 5 lines of the same file into
  one finding marked `convergent`, at the highest severity.
- Drop findings whose fingerprint is already in the state marker.

## Step 4 — Triage

Fetch threads with the filtered query in `references/github-api.md` (unresolved,
not outdated, bodies truncated to 1500 characters). Skip stale top-level bot
reviews.

### Provenance

A comment is **automated** only if one of these holds:

- (a) its author `__typename` is `Bot`;
- (b) its author login ends in `[bot]` or matches the known review-bot list;
- (c) its body carries the `🤖 Automated comment by` header **and** its author
  is `<viewer>`. Bugpool and similar tools post through your own account.

Every other comment is **human**, including a comment by someone else that
pastes the bot header. If provenance is unclear, treat the comment as human. A
thread with at least one human comment is a **human thread**: defer it and
leave it untouched.

### Classification

Classify every new finding and every all-automated thread. **ACTIONABLE**
requires all four:

1. the severity is HIGH or CRITICAL, or the finding is convergent;
2. the fix is concrete: you know exactly what to change (a missing null check,
   a forgotten `await`, a wrong variable, an off-by-one);
3. the change is localised: one file, or a few tightly related edits;
4. it needs no design decision, no new dependency, and no change of PR scope.

SIZE findings are never ACTIONABLE. Everything else falls into one of these,
checked in order:

- **NIT:** LOW or NIT severity, style-only, speculative, duplicate, or already
  addressed.
- **PROMOTED:** there is exactly one sensible, reversible fix with no trade-off
  (the "just do it" case). Handle it like ACTIONABLE.
- **AMBIGUOUS:** a product choice, architectural alternatives, more than one
  reasonable fix, or an unclear benefit. **Any doubt lands here.**

Before fixing a thread classified ACTIONABLE or PROMOTED whose
`body_truncated` is true, refetch its full body.

Without auto-fix (review-only or no gate), ACTIONABLE and PROMOTED new findings
are posted with **Suggested fix**, and such bot threads stay open, listed as
"fix available".

## Step 5 — Auto-fix

Skip this step if auto-fix is disabled.

**Queue order:** Pass 1 items first (CRITICAL before HIGH), then Pass 2. When
the Pass 1 items are done, if any Pass 1 CRITICAL/HIGH item is still unfixed
(its gate failed, or it is AMBIGUOUS), **do not auto-fix any Pass 2 item this
round**. Report the Pass 2 items instead.

For each queued item:

1. Run `git status --porcelain`. If it prints anything, stop auto-fixing for the
   run and report why.
2. Record `pre=$(git rev-parse HEAD)`.
3. Make the minimal edit. Do not touch unrelated code.
4. Run the gate from Step 2c.
5. **Pass:** `git add <files>` and
   `git commit -m "fix(bugpool): <short description>"`. Record the SHA against
   the item.
6. **Fail:** `git reset --hard <pre>` then `git clean -fd`. This is safe only
   because step 1 verified a clean tree. `clean` without `-x` keeps ignored
   files such as `.env` and `node_modules`. Reclassify the item as AMBIGUOUS
   with the note "automated fix attempted, local gate failed: <first error
   line>".

## Step 6 — Publish

Skip all GitHub writes in local mode.

1. **Push once.** If any fix was committed this round, run one `git push`. If it
   fails, do not reply to or resolve any thread this round. Report the
   unpushed commit SHAs and the error, then go to Step 7.
2. **Bot threads.**
   - Fixed: reply "Fixed in `<sha>` — <one line>", then resolve.
   - NIT: reply "<intentional | out of scope | disagree> — <reason>", then
     resolve.
   - AMBIGUOUS: leave open.

   Apply the reply-before-resolve rule from `references/github-api.md`.
3. **New AMBIGUOUS findings** (plus the suggested fixes in review-only mode):
   post them as **one** review with event `COMMENT` against the current HEAD,
   using the inline format in `references/github-api.md`. Findings with
   `line: general` go in the review body. If there is nothing to post, post no
   review.

## Step 7 — Score and sticky summary

Read `references/quality-score.md`. Compute the dimension scores, the overall
score, the grade and the verdict from the findings still open at the reviewed
HEAD.

Upsert the sticky comment with `references/github-api.md` → *Sticky summary*.
Body:

```markdown
<!-- bugpool-summary -->
<!-- bugpool-state {"v":1,"round":<N>,"sha":"<head sha>","fp":[<posted fingerprints, previous + new>]} -->
> [!NOTE]
> 🤖 Automated comment by **Bugpool** — not written by a human

## 🎯 Bugpool — <APPROVE | APPROVE WITH NITS | REQUEST CHANGES> <sub>(round <N> @ <short sha>)</sub>

<1–2 sentences explaining the verdict>

**Quality Score:** <score line from references/quality-score.md>
<if review-only:> **Mode:** review-only — <reason>

| Reviewer | Assessment |
| --- | --- |
| 🧭 router (<model>) | <1 line + danger grade + what it delegated> |
<one row per reviewer that actually ran this round; omit the others>

<if scope drift:>
> [!WARNING]
> **Scope drift:** <stated goal> vs <unrelated files/changes>

### Actions
- **Auto-fixed:** <n> (<sha list>)
- **Bot threads resolved as nits:** <n>
- **Human threads untouched:** <n>
- **Ambiguous for the author:** <n> (see inline review)

<details><summary>Nits (<n>)</summary>

- `<file:line>` — <one line>
</details>

<details><summary>Previous rounds (<n>)</summary>

- round <N-1> @ <short sha> — <verdict>, <score>: <one-line disposition>
</details>
```

To build the history, take the previous sticky's header line, collapse it to
one line, and put it on top of the previous history list. Do not carry the old
body verbatim.

## Step 8 — Loop

Start another round (back to Step 2b, with `round_start_sha` = the HEAD before
this round's fixes) only if **all** of these hold:

- this round pushed at least one fix;
- the run is not review-only;
- `round < 3`.

Otherwise stop. Items still ACTIONABLE when the cap is reached are reported as
AMBIGUOUS.

## Step 9 — Terminal report

```
### 🦹 Bugpool — PR #<n> (<title>)
Score <score>/100 (<grade>) · verdict <verdict> · <rounds> round(s) · mode <auto-fix | review-only: reason>

Threads fetched: <T> = resolved <r> + fixed <f> + deferred <d>   ← must add up
New findings: fixed <a> · nits <b> · posted as ambiguous <c>

Needs your decision:
1. [human]     src/foo.ts:42 — @reviewer: "<short quote>"
2. [ambiguous] src/bar.ts:110 — <one-line reason>
3. [gate fail] src/baz.ts:7 — <first error line>
```

The counts must reconcile: every fetched thread ends in exactly one bucket.

## Degradation

- **`gh` not authenticated:** stop and tell the user to run `gh auth login`.
- **Agent tool unavailable:** perform the router pass yourself, mark the summary
  "degraded: single reviewer", and do not claim lens coverage.
- **A lens agent fails:** report the gap in the summary row, and do not invent
  its conclusions. If it was the mandatory `security` lens, add a HIGH general
  finding: "security lens unavailable for <scope>".
- **No PR:** local mode (Step 1). Offer to post if the user provides a PR.
- **User interrupts:** stop at the next step boundary and print the report.

## References

| File                          | Read when                                       |
|-------------------------------|-------------------------------------------------|
| `references/github-api.md`    | Step 1, before the first `gh` call             |
| `references/size-rubric.md`   | in every lens prompt that checks SIZE rules     |
| `references/quality-score.md` | Step 7                                          |

Bugpool builds on [qa-swarm](https://github.com/pauldambra/dotfiles/tree/main/ai/skills/qa-swarm)
and [review-triage](https://github.com/pauldambra/dotfiles/tree/main/ai/skills/review-triage)
by Paul D'Ambra, and on the review methodology of
[yooh-digital/ai-workflow](https://github.com/yooh-digital/ai-workflow).
