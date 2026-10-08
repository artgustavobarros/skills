## ADDED Requirements

### Requirement: Frontmatter
`skills/bugpool/SKILL.md` frontmatter SHALL contain `name`, `description`, `argument-hint`, `disable-model-invocation: true`, `license`, and `metadata.version`, and SHALL NOT contain a top-level `version` key.

#### Scenario: Casual mention of review
- **WHEN** a user asks the agent to "review this function" without invoking `/bugpool`
- **THEN** the bugpool skill is not auto-loaded

### Requirement: Single entry point
The repository SHALL NOT ship `commands/bugpool.md`; `/bugpool` SHALL be provided by the skill itself.

#### Scenario: Global install
- **WHEN** the skill is installed with `npx skills add ... -g`
- **THEN** `/bugpool` works without any project-relative path

### Requirement: Progressive disclosure layout
`SKILL.md` SHALL contain the workflow and decision rules and SHALL stay under 500 lines; detailed reference material (size rubric, quality-score tables, GitHub API recipes) SHALL live in `skills/bugpool/references/` and be linked from `SKILL.md` with instructions on when to read each file.

#### Scenario: Scoring step
- **WHEN** the orchestrator reaches the scoring step
- **THEN** `SKILL.md` directs it to read `references/quality-score.md`

### Requirement: Language and neutrality
`SKILL.md` and references SHALL be written in English and SHALL NOT contain personal names of the repository owner or project-specific assumptions; user-facing terminal output SHALL follow the user's language.

#### Scenario: Neutral wording
- **WHEN** `SKILL.md` is searched for the owner's first name
- **THEN** no match is found

### Requirement: Installer correctness
`install.sh` SHALL copy the skill to `<target>/.agents/skills/bugpool` and SHALL symlink `<target>/.claude/skills/bugpool` to it, SHALL NOT reference `commands/`, and SHALL NOT contain conditions that are always true. It SHALL remove a stale `<target>/.claude/commands/bugpool.md` left by 1.x when present, after printing a notice.

#### Scenario: Upgrade from 1.1.0
- **WHEN** `install.sh` runs on a project that has `.claude/commands/bugpool.md`
- **THEN** that file is removed and a notice is printed

### Requirement: Accurate README and attribution
The README SHALL describe behaviour that matches `SKILL.md` (the gate checks it actually runs, review-only mode, posting policy, model ladder), SHALL document 2.0.0 breaking changes, and SHALL credit qa-swarm and review-triage (pauldambra/dotfiles) and the Yooh ai-workflow, with links.

#### Scenario: Safety gate claim
- **WHEN** the README describes the safety gate
- **THEN** it lists typecheck, lint, and tests "when available", not "tests the code" unconditionally
