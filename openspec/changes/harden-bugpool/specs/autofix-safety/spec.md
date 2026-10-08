## ADDED Requirements

### Requirement: Invocation modes
The skill SHALL accept `[<pr-number>|<pr-url>] [--review-only] [--allow-foreign]`. With `--review-only`, the skill SHALL NOT edit files, commit, push, reply to, or resolve threads; ACTIONABLE items SHALL be posted like AMBIGUOUS ones, labelled as suggested fixes.

#### Scenario: Review-only run
- **WHEN** the user runs `/bugpool 42 --review-only`
- **THEN** the working tree and remote branch are unchanged after the run

### Requirement: PR checkout
When a PR number or URL is given, the skill SHALL compare the PR's `headRefName` with the current branch and, if different, run `gh pr checkout <n>` before diffing (subject to the clean-tree precondition). Diffs SHALL be computed against `origin/<baseRefName>` after `git fetch origin <baseRefName>`.

#### Scenario: Different branch checked out
- **WHEN** the user is on `main` and runs `/bugpool 42`
- **THEN** the skill checks out PR #42's branch before gathering the diff

#### Scenario: Stale local base
- **WHEN** local `main` is behind `origin/main`
- **THEN** the diff is still computed against `origin/main`

### Requirement: Auto-fix preconditions
Before any auto-fix, the skill SHALL verify: `git status --porcelain` is empty; the current branch equals the PR's `headRefName`; local HEAD equals the PR's `headRefOid` after fetching; and the PR author equals the authenticated `gh` user unless `--allow-foreign` was passed. If any check fails, the skill SHALL run in review-only mode for that run and state which precondition failed.

#### Scenario: Dirty working tree
- **WHEN** the user has uncommitted changes
- **THEN** no file is modified, the run continues as review-only, and the report says "working tree not clean"

#### Scenario: Someone else's PR
- **WHEN** the PR author is `colleague` and `--allow-foreign` is absent
- **THEN** no commits are pushed to the PR branch

#### Scenario: Local branch behind remote
- **WHEN** local HEAD differs from `headRefOid`
- **THEN** auto-fix is disabled for the run

### Requirement: Gate detection
The skill SHALL detect the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock`/`bun.lockb` → bun, `package-lock.json` → npm) and SHALL build the gate from whichever of these `package.json` scripts exist: a typecheck script, a lint script, and a test script (preferring a related-files invocation when the runner supports it, e.g. `vitest related --run <files>`). In repositories without `package.json`, the skill SHALL use a check command documented in AGENTS.md/CLAUDE.md if one exists. If no gate command can be determined, auto-fix SHALL be disabled and all ACTIONABLE items SHALL be treated as AMBIGUOUS.

#### Scenario: pnpm project with three scripts
- **WHEN** the repo has `pnpm-lock.yaml` and scripts `typecheck`, `lint`, `test` (vitest)
- **THEN** the gate runs `pnpm typecheck`, `pnpm lint`, and vitest on the files related to the fix

#### Scenario: No scripts
- **WHEN** no typecheck, lint, or test command can be found
- **THEN** the report states "no local gate, auto-fix disabled" and nothing is committed

#### Scenario: Missing script is not a failure
- **WHEN** the repo has `test` but no `typecheck` script
- **THEN** the gate runs only the available checks and does not treat the missing script as a failure

### Requirement: Per-fix commit and SHA-based rollback
For each queued fix the skill SHALL record the pre-fix SHA, apply the minimal edit, run the gate, and on success create one local commit `fix(bugpool): <short description>`. On gate failure the skill SHALL restore the tree with `git reset --hard <pre-fix-sha>` followed by `git clean -fd` (which is safe because the clean-tree precondition was verified), and SHALL reclassify the item as AMBIGUOUS with the note "automated fix attempted, local gate failed".

#### Scenario: Fix creates a new file and fails
- **WHEN** a fix adds `src/util/new.ts` and the gate fails
- **THEN** the new file is removed and HEAD equals the pre-fix SHA

### Requirement: Single push per round
The skill SHALL push once per round after all fixes in that round are committed locally. Replies and resolutions referencing commits SHALL only be posted after the push succeeds. If the push fails, the skill SHALL NOT reply to or resolve any thread for that round, and SHALL report the failure with the local commit SHAs.

#### Scenario: Three fixes in a round
- **WHEN** three fixes pass the gate
- **THEN** exactly one `git push` is executed for that round

#### Scenario: Push rejected
- **WHEN** `git push` is rejected as non-fast-forward
- **THEN** no thread is resolved and the report lists the unpushed commits
