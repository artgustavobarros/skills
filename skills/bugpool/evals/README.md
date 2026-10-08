# Bugpool evaluation harness

Measures the skill the way a user runs it: a fresh headless Claude Code session invokes
`/bugpool --local --base <base> --dry-run` inside a throwaway git worktree with seeded bugs,
and reports cost and wall time (subagents included). Nothing is pushed, committed or posted.

## Files

- `build-bench.py <manifest> <out_dir> [--skill <dir>]` — creates a detached worktree outside the
  repo at the manifest head, applies each seed (exact find/replace, must match once), commits
  locally, symlinks `node_modules`, `.env*` and the skill under test, writes `<scenario>.diff`.
- `run-eval.sh <scenario> [--baseline] [--label <name>] [--keep]` — builds the bench and runs
  `claude -p` (orchestrator `sonnet`, budget cap `BUGPOOL_EVAL_BUDGET`, default $3) with
  `git push/commit/reset/checkout`, `gh`, `Edit` and `Write` disallowed. `--baseline` runs one
  generic single-reviewer prompt instead, for comparison. Output JSON goes to `runs/`.
- `manifests/` — one JSON per scenario (create your own; see below).

Each run spends real usage on your account. Keep `runs/` and manifests out of public repos when
they contain code from private projects.

## Manifest format

```json
{
  "scenario": "dev",
  "description": "feature PR with seeded bugs",
  "base": "<base sha>",
  "head": "<head sha>",
  "title": "<PR title used as review context>",
  "seeds": [
    {
      "id": "S1",
      "file": "path/to/file.ts",
      "class": "security/IDOR",
      "severity": "CRITICAL",
      "defect": "one-line description used when scoring",
      "find": "exact original text (must occur exactly once)",
      "replace": "buggy replacement"
    }
  ]
}
```

Recommended set: a **dev** scenario to iterate on, a **held-out** scenario in a different domain
run only for final acceptance, and a **clean** scenario (no seeds) to count false positives.
Never put seed-specific hints in the skill text.

## Scoring

A seed counts as caught when a reported finding names its file and describes its defect.
A false positive (clean scenario) is a finding that manual verification shows to be wrong;
real pre-existing defects are not false positives. Keep a scorecard with recall, FPs, cost and
wall time per run.

## Reference results (3.0.0, private Next.js + Drizzle repo, orchestrator `sonnet`)

| Scenario | Single-reviewer baseline | bugpool 3.0.0 |
| :--- | :--- | :--- |
| dev (5 seeds) | 3/5 · $0.19 · 41 s | 5/5 · $1.12 · 158 s |
| held-out (5 seeds) | 4/5 · $0.17 · 35 s | 5/5 · $1.69 · 185 s |
| clean (FPs) | 0 · $0.19 · 38 s | 0 · $0.85 · 138 s |

Single runs each; LLM reviews are stochastic, so repeat borderline results.
