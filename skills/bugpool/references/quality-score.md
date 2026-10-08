# Quality Score & Verdict

Read this at the scoring step (Step 7). Dimensions and weights follow Yooh
Digital's `quality-score`, so a bugpool score is comparable with a Yooh `/review`
score.

## Which findings count

Score only findings that are **still open at the reviewed HEAD**, after this
round's fixes were pushed. These are AMBIGUOUS findings, NITs, failed fixes, and
open bot threads that bugpool classified. Findings auto-fixed in this run are
listed under "Actions taken" and do not deduct points. Human threads are not
scored, because bugpool does not judge them.

## Dimensions & weights

| Dimension         | Weight | Categories that map to it                                  |
|-------------------|--------|------------------------------------------------------------|
| Security          | 20     | security, auth, secrets, injection, idor, ssrf             |
| Correctness       | 18     | correctness, logic, types, llm-boundaries                  |
| Reliability       | 14     | reliability, error-handling, migration, concurrency, race  |
| Tests             | 14     | tests, coverage                                            |
| Complexity & Size | 10     | complexity (all SIZE-n findings)                           |
| Consistency       | 8      | consistency, patterns, conventions                         |
| Comprehension     | 8      | comprehension, naming, readability                         |
| Performance       | 8      | performance, n+1, caching, bundle                          |

If a category does not match any row, assign it to the closest dimension and
state the choice in the summary's score line.

## Deductions

Each dimension starts at 100 and loses points per open finding, with a floor
of 0:

| Severity | Deduction |
|----------|-----------|
| CRITICAL | −35       |
| HIGH     | −25       |
| MEDIUM   | −15       |
| LOW      | −5        |
| NIT      | −1        |

A convergent finding deducts once, at its merged severity.

## Formula

```
overall = round( Σ(dimension_score × weight) / 100 )
```

## Grades

| Overall | Grade |
|---------|-------|
| 90–100  | A     |
| 75–89   | B     |
| 60–74   | C     |
| 40–59   | D     |
| 0–39    | F     |

## Verdict

Apply the rules in order. The first rule that matches decides the verdict.

1. **REQUEST CHANGES** if any CRITICAL or HIGH finding is open, **or** the
   overall score is below 70, **or** any dimension is below 50.
2. **APPROVE WITH NITS** if any MEDIUM, LOW or NIT finding is open.
3. **APPROVE** otherwise.

The verdict is text in the sticky summary only. Every review that bugpool posts
uses the GitHub event `COMMENT`, never `APPROVE` or `REQUEST_CHANGES`, because
it posts through the PR author's own account.

## Worked example

The only open finding is one HIGH security issue.

- Security = 100 − 25 = 75. Every other dimension = 100.
- overall = (75×20 + 100×18 + 100×14 + 100×14 + 100×10 + 100×8 + 100×8 + 100×8) / 100
  = (1500 + 8000) / 100 = **95**, grade **A**.
- Verdict: **REQUEST CHANGES**, because a HIGH finding is open (rule 1). A
  high score does not override an open blocker.

## Score line format

```
**Quality Score:** 95/100 (A) · Security 75 · Correctness 100 · Reliability 100 · Tests 100 · Complexity 100 · Consistency 100 · Comprehension 100 · Performance 100
```
