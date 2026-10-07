# /bugpool — Multi-Perspective PR Swarm & Autonomous Triage

Execute the Bugpool skill to review, triage, auto-fix, and clean up a GitHub Pull Request.

## Usage

```bash
/bugpool                   # Review and triage current branch PR
/bugpool <PR_NUMBER>       # Review and triage specific PR by number (e.g. /bugpool 42)
/bugpool <PR_URL>          # Review and triage specific PR by URL
```

## Instructions

Load and follow `.agents/skills/bugpool/SKILL.md` completely:
1. Detect PR context, diff, and check for Scope Drift.
2. Run Router (`haiku`) for Pass 1 Critical checks (Security, Reliability, Correctness, LLM Boundaries), delegating to specialist lenses (`sonnet`) if needed, and escalating critical disagreements to `opus`.
3. Apply the SIZE-1..6 complexity rubric and Constructive Friction (evidence-based findings only).
4. Fetch GitHub review threads; apply the strict **Human Immunity Gate** (never touch threads with human participants).
5. Auto-fix localized Actionable findings, validating with `pnpm typecheck` safety gate before committing and pushing. Rollback immediately on failure.
6. Resolve Nit threads with technical justification.
7. Post/update sticky PR summary (`<!-- bugpool-summary -->`) with Quality Score (0–100).
8. Print terminal summary with only the ambiguous items left for the author.
