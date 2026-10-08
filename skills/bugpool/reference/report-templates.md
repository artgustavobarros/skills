# Report templates

## Score

`score = max(0, 100 − Σ deductions)` over **validated** findings only (CONFIRMED, not PRE-EXISTING):
CRITICAL 30 · HIGH 15 · MEDIUM 5 · LOW 2 · NIT 0.
Grade: A ≥ 90 · B ≥ 80 · C ≥ 70 · D ≥ 60 · F < 60.
Verdict: any open CRITICAL/HIGH → REQUEST CHANGES; only MEDIUM or lower open → APPROVE WITH NITS; nothing open → APPROVE.

## Sticky PR summary (PR mode, not dry-run)

Write to a temp file and post with `scripts/post.sh sticky <pr> <file>` (the script adds the marker and bot header).

```markdown
## 🎯 Bugpool Review Summary <sub>(@ <short_sha>, round <n>)</sub>

**Verdict:** <APPROVE | APPROVE WITH NITS | REQUEST CHANGES> · **Score:** <score>/100 (<grade>)

| Stage | Result |
| :--- | :--- |
| Pre-pass | lint <ok/fail/skipped> · typecheck <…> · tests <…> |
| Router (`haiku`) | danger <LEVEL> · extra lenses: <list or none> |
| Lenses (`sonnet`) | <lens: n findings, …> |
| Validation | <n> confirmed · <n> rejected · <n> pre-existing |

> [!WARNING]
> **Scope drift:** <only if detected — files and why>

### Open findings
| Severity | Location | Issue |
| :--- | :--- | :--- |
| <SEV> | `<file>:<line>` | <one line> |

### Actions
- Auto-fixed: <n> (commit `<sha>` on `<branch>`, pushed: <yes/no>)
- Bot nits resolved: <n> · Human threads untouched: <n> · Ambiguous for author: <n>

<details><summary>History</summary>

- round <n> @ <sha> — <verdict>, <score>
</details>
```

## Terminal report (always)

```markdown
### 🦹 Bugpool — <PR #n | local> <(dry-run)>

**Verdict:** <…> · **Score:** <score>/100 (<grade>) · **Danger:** <LEVEL>
Pre-pass: lint <…> · typecheck <…> · tests <…> · Lenses: <list> · Validation: <c> confirmed / <r> rejected

#### Findings (validated, most severe first)
1. **<SEV>** `<file>:<line>` — <issue> → <fix>   <[fixed in <sha>] | [ambiguous] | [pre-existing]>

#### Needs your decision
1. **[Human thread]** `<file>:<line>` — @<author>: "<excerpt>"
2. **[Ambiguous]** `<file>:<line>` — <why it needs a decision>

<Scope drift line, if any>
<Auto-fix line: done / skipped (reason: dry-run | dirty tree | none actionable)>
```
