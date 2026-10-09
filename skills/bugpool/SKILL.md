---
name: bugpool
description: >
  Multi-lens PR review and triage. Runs a deterministic pre-pass (lint check, typecheck,
  related tests), always-on correctness and security lenses plus router-selected extras,
  refute-first validation of findings, human-safe triage of GitHub review threads, and
  optional auto-fix in an isolated worktree. Supports PR mode, --local (no PR needed) and
  --dry-run (no GitHub or git writes). Use for /bugpool, PR review, review triage, or
  reviewing a branch before opening a PR.
version: "3.0.1"
argument-hint: "[pr-number|pr-url] [--local] [--base <ref>] [--dry-run] [--push]"
---

# Bugpool

`<skill>` below means this skill's base directory. Lens prompts live in `<skill>/reference/lenses/`, report formats in `<skill>/reference/report-templates.md`, helpers in `<skill>/scripts/`.

## Invocation

```
/bugpool [<pr number|url>] [--local] [--base <ref>] [--dry-run] [--push]
```

| Flag | Effect |
| :--- | :--- |
| *(none)* | PR mode on the current branch's PR |
| `--local` | Review `<base>...HEAD` plus uncommitted/untracked changes. No GitHub calls. `--base` defaults to `origin/main` (or `main`) |
| `--dry-run` | Review and report only. **No GitHub writes, no commits, no pushes, no file edits.** |
| `--push` | Allow pushing the auto-fix commit to the PR branch. Without it, fixes stay on a local branch |

## Hard rules

- Never run `git checkout -- …`, `git reset --hard`, `git stash`, `git clean`, or any lint/format command with `--fix`/`--write` in the user's working tree.
- Never auto-fix, reply to, or resolve a thread with any human comment (`scripts/threads.sh` marks it `"human": true`).
- Every posted comment goes through `scripts/post.sh` (adds the bot header, sends the body from a file).
- Report only validated findings with `file:line` evidence.

## Workflow

Copy this checklist and tick it as you go:

```
- [ ] 1. Context
- [ ] 2. Pre-pass
- [ ] 3. Router
- [ ] 4. Lenses
- [ ] 5. Dedupe + validation
- [ ] 6. Triage (PR mode)
- [ ] 7. Auto-fix (not dry-run)
- [ ] 8. Report
```

### 1. Context

- **PR mode**: `gh pr view <pr> --json number,title,body,state,baseRefName,headRefName,headRefOid`. If MERGED/CLOSED and not `--dry-run`, stop. `git fetch origin <baseRefName> <headRefName>`; base = `origin/<baseRefName>`. If `git rev-parse HEAD` ≠ `headRefOid`, run `<skill>/scripts/fix-worktree.sh create <headRefOid>` and use that path as the review root for every later step.
- **Local mode**: review root = repo root, base = `--base` value; title/body = branch name + `git log --format=%s <base>..HEAD`.
- Set `RUN=$TMPDIR/bugpool-$(git rev-parse --short HEAD)` and `mkdir -p $RUN`. Write the diff once: `git diff <base>...HEAD > $RUN/diff` (local mode: append `git diff HEAD`). Note changed line count.

### 2. Pre-pass

From the review root: `bash <skill>/scripts/prepass.sh <base> [--local] > $RUN/prepass.md`. Read it. Failing tests and lint diagnostics on changed lines are leads for the lenses, not automatic findings.

### 3. Router (`haiku`)

Spawn one Agent (`model: haiku`) with: "Read `<skill>/reference/lenses/router.md` and follow it. Repo: <review root>. Base: <base>. Diff: <diff path>. Pre-pass: <prepass path>. Title/body: …". Keep its SCOPE_DRIFT, DANGER and EXTRA_LENSES.

### 4. Lenses (`sonnet`, in parallel)

In **one message**, spawn an Agent (`model: sonnet`) per lens: always `correctness-stack` and `security`, plus each lens in EXTRA_LENSES. Prompt: "Read `<skill>/reference/lenses/<lens>.md` and follow it exactly. Repo: … Base: … Diff: … Pre-pass: … Title/body: … Scope: …". Lenses are never skipped because another lens found a CRITICAL issue.

### 5. Dedupe + validation

1. Parse all `STRUCTURED_FINDINGS`. Merge findings with the same file, line within ±3, and the same defect; keep the highest severity and list contributing lenses. Give each an id (F1, F2, …).
2. LOW/NIT: keep at most 5, not validated.
3. MEDIUM+: in **one message**, spawn validators reading `<skill>/reference/lenses/validator.md`:
   - each `security` finding rated CRITICAL/HIGH → its own Agent with `model: opus`;
   - all other MEDIUM+ findings → batches of up to 8 per Agent with `model: sonnet`.
4. Drop REJECTED. Mark PRE-EXISTING (reported, excluded from score). Use validated severities.

### 6. Triage (PR mode only)

1. `<skill>/scripts/threads.sh list <pr>`; count `human: true` threads as untouched and list them for the author.
2. Bot threads: NIT/obsolete → (not dry-run) reply with a one-line technical reason via `scripts/post.sh reply`, then `scripts/threads.sh resolve <thread_id>`. Concrete fixable issue → add to the fix queue. Product/architecture choice → AMBIGUOUS.
3. Validated findings: ACTIONABLE when severity ≥ MEDIUM, the fix is local (≤ 2 files) and unambiguous; otherwise AMBIGUOUS.

### 7. Auto-fix (skip in `--dry-run`; skip in local mode unless the user asked for fixes)

1. In the user's checkout: `<skill>/scripts/fix-worktree.sh check-clean`. Dirty → skip auto-fix and say so.
2. Reuse the review worktree, or `<skill>/scripts/fix-worktree.sh create HEAD`.
3. Spawn one Agent (`model: sonnet`) with `<skill>/reference/lenses/fixer.md`, the worktree path, and the ACTIONABLE list.
4. If anything is FIXED: `fix-worktree.sh commit <wt> "fix(review): bugpool round <n>"`. With `--push`: `fix-worktree.sh push <wt> <headRefName>`, then reply on fixed bot threads with the SHA and resolve them. NOT_FIXED → AMBIGUOUS with the gate error.
5. **Bounded loop**: re-run the `correctness-stack` lens on `git diff <old head>..<fix sha>` and validate. Repeat at most 2 extra rounds; stop as soon as a round adds no new validated MEDIUM+ finding.
6. `fix-worktree.sh remove <wt>` unless the user wants to inspect it (the branch is kept).

### 8. Report

Score and templates: `<skill>/reference/report-templates.md`.
- PR mode, not dry-run: write the summary to a temp file, `<skill>/scripts/post.sh sticky <pr> <file>` (updates the existing summary in place).
- Always print the terminal report. End with `Agents: <n> · Rounds: <n>`.

## Evaluation

Benchmarks, seeded-bug manifests and the scorecard live in `<skill>/evals/` (`run-eval.sh <dev|clean|heldout> [--baseline]`). Run them after changing this skill; do not tune the skill to specific seeds.

## Credits

Builds on [qa-swarm](https://github.com/pauldambra/dotfiles/tree/main/ai/skills/qa-swarm) and [review-triage](https://github.com/pauldambra/dotfiles/tree/main/ai/skills/review-triage) by Paul D'Ambra (router + lenses, structured findings, sticky summary, human immunity) and on the review methodology of [yooh-digital/ai-workflow](https://github.com/yooh-digital/ai-workflow) (two-pass review, constructive friction, scope drift, SIZE rubric).
