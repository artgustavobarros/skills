# SIZE-1..6 — Size & Complexity Rubric

Read this when a lens evaluates **Complexity & Size** (Pass 2). Numbering and
thresholds follow Yooh Digital's `size-check` so findings can be
cross-referenced with that source.

## Thresholds

| Rule   | Metric              | WARN         | BLOCK        | INFO                              |
|--------|---------------------|--------------|--------------|-----------------------------------|
| SIZE-1 | Function lines      | ≥ 40 lines   | ≥ 80 lines   | —                                 |
| SIZE-2 | File lines          | ≥ 351 lines  | ≥ 500 lines  | —                                 |
| SIZE-3 | Nesting depth       | ≥ 4 levels   | —            | —                                 |
| SIZE-4 | Parameter count     | > 3 params   | —            | —                                 |
| SIZE-5 | Flag arguments      | —            | any flag arg | —                                 |
| SIZE-6 | God class (methods) | —            | —            | > 10 public or > 20 total methods |

## Severity mapping

| SIZE level | Finding severity | Meaning     |
|------------|------------------|-------------|
| BLOCK      | HIGH             | MUST FIX    |
| WARN       | MEDIUM           | SHOULD FIX  |
| INFO       | LOW              | NIT         |

Every SIZE finding is tagged `pass: 2`, `category: complexity`, and
`rule: SIZE-<n>`.

**SIZE findings are never ACTIONABLE.** Splitting a function, a file, or a
class is a design decision, so these findings go to the summary (LOW) or are
posted as AMBIGUOUS (MEDIUM/HIGH). They are never auto-fixed.

## Scope: changed code only

- Evaluate only functions, classes and files that the PR adds or modifies.
- A file that already exceeded a threshold before the PR and is touched only
  lightly (the PR adds less than 10% of its lines) is reported **at most as
  LOW**, with the note "pre-existing; not introduced by this PR".
- A function that crosses a threshold *because of* this PR is reported at full
  severity.

## Counting rules

- **Function lines:** count from the opening line of the body to the closing
  brace/`end`, inclusive. Exclude blank lines and comment-only lines. For
  indentation-based languages, count from `def` to the last non-blank line
  before the next declaration at the same indent.
- **File lines:** the total line count, including blanks and comments.
- **Nesting:** each `if`, `else if`, `for`, `while`, `do`, `try`, `catch`,
  `switch` block, lambda or closure body adds one level. The function body is
  level 0.
- **Parameters:** count direct parameters only. A destructured options object
  counts as 1.
- **Flag arguments:** boolean parameters (names often start with `is`, `has`,
  `should`, `can`, `enable`, `disable`, `use`, `include`, `exclude`) that select
  between two behaviours inside the function. Also flag `mode`/`type` string
  parameters with exactly two values used only to branch.
- **God class:** count public and total methods per class (or per module that
  exports an object of functions acting as a class).

## Finding body template

```
SIZE-<n> (<WARN|BLOCK|INFO>): <what> at <file>:<line> — <measured value> vs threshold <x>.
Suggestion: <named extraction / parameter object / split into two functions>.
Why: <responsibility being mixed>.
```

## Overlap with linters

If the project's linter already enforces an equivalent rule (for example
cognitive complexity in Biome/ESLint) and CI is green, lower SIZE-1/SIZE-3 by
one level (BLOCK→WARN, WARN→INFO) and mention the linter rule. This avoids
duplicating signal the author already gets.
