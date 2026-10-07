---
name: bugpool
description: >
  Multi-perspective PR review swarm and autonomous triage loop. Spawns a cheap-first
  reviewer panel (Router in Haiku -> Lenses in Sonnet -> Escalation in Opus), performs
  Two-Pass Review (Critical vs Informational), checks Scope Drift and SIZE-1..6 complexity,
  triages findings and existing GitHub review threads into actionable/nit/ambiguous,
  auto-fixes with local typecheck safety gates, resolves completed threads, and leaves
  only ambiguous items flagged for the human author. Use for /bugpool, PR swarm review,
  review triage, or automated PR cleanup.
version: "1.1.0"
---

# Bugpool: Multi-Perspective PR Swarm & Autonomous Triage Loop

`bugpool` orchestrates a complete PR review and triage lifecycle. It blends cost-aware multi-perspective review with strict code quality principles (Two-Pass Review, Scope Drift Detection, SIZE-1..6 Complexity Rubric, Constructive Friction) and an autonomous triage engine that auto-fixes and resolves clear issues, never touches human discussions, and loops until only ambiguous architectural decisions remain for the author.

---

## Bot Identifier — REQUIRED on Every Posted Comment

Every comment posted to GitHub (inline review comments, thread replies, sticky PR summary) must begin with the bot-identifier header:

```markdown
> [!NOTE]
> 🤖 Automated comment by **Bugpool** — not written by a human
```

Never skip this header. It is the load-bearing indicator that separates automated bot comments from human discussions.

---

## Model Roster & Substitution Ladder

Bugpool uses a **Cheap-First** model ladder to minimize API token cost while ensuring high reasoning depth when warranted:

| Role | Bugpool Target (Anthropic) | Antigravity / Gemini Equivalent | Full Model ID | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Router (Cheap Entry)** | `haiku` | `flash` / `flash_lite` | `claude-haiku-4-5` | Pass 1 screening, blast radius, scope drift |
| **Delegated Lenses** | `sonnet` | `pro` | `claude-sonnet-5-5` | Deep lens analysis (Arch, QA, Stack, Security) |
| **Escalation / Tie-breaker**| `opus` | `pro` (high reasoning) | `claude-opus-5-5` | Critical conflicts & high-risk security disputes |

*Ladder policy:*
1. The **Router** runs on the cheapest model (`haiku` / `flash`).
2. **Specialist Lenses** run on `sonnet` / `pro` (the model tier before Opus).
3. Critical disagreements on security or data integrity escalate to `opus` / `pro`.

---

## Core Analytical Principles (Yooh Methodology)

Every review in Bugpool follows these four analytical principles:

### 1. Two-Pass Review
- **Pass 1 — Critical (Blockers Only):**
  - **Security:** Auth, input validation, secrets in code, injection, IDOR.
  - **Reliability:** Error handling, safe migrations, race conditions, crashes.
  - **Correctness:** Logic bugs, edge cases, wrong types, broken contracts.
  - **LLM Boundaries:** If code is AI-generated, actively verify against hallucinated APIs, non-existent methods, and invalid signatures.
  *(If MUST FIX blocker items are found in Pass 1, stop and flag immediately — never waste tokens on style while correctness is broken).*
- **Pass 2 — Informational (Quality & Architecture):**
  Only runs if Pass 1 is clean or acknowledged:
  - **Maintainability & Comprehension:** Readability, naming, long-term maintenance cost.
  - **Consistency:** Adherence to project patterns, framework standards.
  - **Performance:** N+1 queries, missing indexes, hydration mismatch, memory leaks.
  - **Tests:** Coverage of edge cases, test readability.
  - **Complexity & Size:** Evaluated via the SIZE-1..6 rubric below.

### 2. The SIZE-1..6 Complexity Rubric
Lenses must evaluate changed code against these objective size checks:
- **SIZE-1 (Function Length):** Functions exceeding ~50 lines without clear justification.
- **SIZE-2 (Nesting Depth):** Control flow nested deeper than 3 levels (favor early returns/guard clauses).
- **SIZE-3 (Parameter Explosion):** Functions taking more than 3 positional parameters (favor typed options objects).
- **SIZE-4 (Boolean Flag Arguments):** Functions taking boolean flags to branch behavior (favor separate, well-named functions).
- **SIZE-5 (File Bloat):** New or modified files exceeding ~300-400 lines without separation of concerns.
- **SIZE-6 (God Abstractions):** Classes or modules taking on multiple unrelated responsibilities.

### 3. Constructive Friction
Before emitting any review finding, the reviewer must check:
- Is this concrete and specific (exact code snippet, exact behavior)?
- Is it actionable (does the author know exactly what to change)?
- Is it backed by evidence from the code (`file:line`), not hunches or personal taste?
- Have I checked for false positives?
*(Avoid bikeshedding — approve with comments whenever possible, and never block on nits).*

### 4. Scope Drift Detection
Compare the actual file diff against the PR title and description:
- Did the PR modify files unrelated to the stated goal?
- Are drive-by refactorings mixed into a targeted bugfix?
- If drift is detected, flag it in the summary and suggest splitting if significant.

---

## Workflow Overview

```
       /bugpool [PR]
             │
             ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 1. RECON & SCOPE DRIFT                                          │
   │    • Extrai diff, commits, título e corpo do PR via gh CLI      │
   │    • Detecta Scope Drift (o PR fez mais do que prometeu?)       │
   └─────────────────────────────────┬───────────────────────────────┘
                                     │
                                     ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 2. PAINEL DE REVISORES (Cheap-First Router)                     │
   │    • Router (Haiku): Pass 1 Critical + blast radius             │
   │    • Se pequeno (<100 linhas, baixo risco): Router fecha direto │
   │    • Se complexo: delega Lentes em Sonnet (Arch, QA, Stack, Sec)│
   │    • Conflito crítico? ──▶ Escala para Opus                     │
   └─────────────────────────────────┬───────────────────────────────┘
                                     │
                                     ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 3. TRIAGEM & FILTRO DE IMUNIDADE HUMANA                         │
   │    • Puxa todas as review threads abertas via GraphQL           │
   │    • 🛑 REGRA DE OURO: Humano participou? ──▶ IMUNE (Não toca!) │
   │    • Bot threads & achados:                                     │
   │        - NIT ───────▶ Responde justificativa técnica e resolve  │
   │        - ACTIONABLE ▶ Fila de correção local                    │
   │        - AMBIGUOUS ─▶ Deixa aberto p/ Arthur                    │
   └─────────────────────────────────┬───────────────────────────────┘
                                     │
                                     ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 4. AUTO-FIX LOOP COM SAFETY GATE                                │
   │    • Aplica correção cirúrgica no código                        │
   │    • 🛡️ SAFETY GATE: Roda pnpm typecheck local                  │
   │        - Passou? ──▶ git commit + push + responde + resolve     │
   │        - Falhou? ──▶ git checkout (rollback) + vira Ambíguo     │
   └─────────────────────────────────┬───────────────────────────────┘
                                     │
                                     ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 5. STICKY SUMMARY & HANDOFF                                     │
   │    • Atualiza 1 único comentário no PR (Quality Score 0-100)    │
   │    • Apresenta no terminal apenas os itens ambíguos             │
   └─────────────────────────────────────────────────────────────────┘
```

---

## Detailed Step-by-Step Instructions

### Step 1: Detect PR, Gather Context & Scope Drift

If `$ARGUMENTS` is provided, parse it as a PR number or URL. Otherwise, detect the PR for the current branch:

```bash
gh pr view --json number,url,title,body,headRefName,baseRefName,headRefOid,state \
  --jq '{number, url, title, body, base: .baseRefName, head_sha: .headRefOid, state}'
```

If PR state is `MERGED` or `CLOSED`, stop immediately.

Gather diff and commits:
```bash
git diff <base>...HEAD --name-only
git diff <base>...HEAD
git log <base>...HEAD --oneline
```

**Scope Drift Evaluation:**
Compare files changed against PR title and description:
- Flag any modified file that has no clear relation to the PR's stated objective.
- Note if a bugfix expanded into an unannounced refactor.

---

### Step 2: Reviewer Panel (Router & Delegated Lenses)

#### 2a. Router Pass (Model: `haiku` / `flash`)
Dispatch the router with diff, commits, and PR context:
- Read surrounding code context (~50 lines) before judging.
- Run **Pass 1 (Critical)** checks (Security, Reliability, Correctness, LLM Boundaries).
- Assess change danger and blast radius: `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`.
- If diff is small (<100 lines) and low danger, synthesize findings directly without delegating.
- If diff >200 lines or touches auth, database schema, concurrency, or payments, output a `DELEGATION_PLAN`.

```
DELEGATION_PLAN:
danger: <LOW|MEDIUM|HIGH|CRITICAL>
confidence: <HIGH|MEDIUM|LOW>
delegations:
  - lens: <architecture|qa|stack|security> | scope: <files or "full"> | reason: <one line>
```

#### 2b. Delegated Lenses (Model: `sonnet` / `pro`)
When delegated, run the selected lenses in parallel:

1. **`architecture` (Engineering Leadership Lens):**
   - Maintainability, tech debt added vs paid down, bus factor, SIZE-5 (file bloat), SIZE-6 (God abstractions), design simplicity.
2. **`qa` (QA & Testability Lens):**
   - Edge cases, error recovery, missing Vitest/Playwright tests, boundary values, async race conditions.
3. **`stack` (React & Next.js Best Practices Lens):**
   - Audit `useEffect` (can it be derived during render or an event handler?).
   - Server vs Client component boundaries, serialization errors, hydration mismatch risks.
   - SIZE-1 (function length), SIZE-2 (nesting), SIZE-3 (parameters), SIZE-4 (flag arguments).
   - Zod schema validation adherence.
4. **`security` (Security & Data Integrity Lens):**
   - IDOR, SSRF, SQL/Drizzle query vulnerabilities, auth/session leaks, unsafe database mutations.

**Escalation Rule (Model: `opus`):**
If lenses produce conflicting evaluations on a CRITICAL/HIGH finding, or if high-risk auth/concurrency logic lacks clear consensus, dispatch an escalation agent on `opus` for final determination.

#### Structured Finding Format
Each reviewer returns findings in structured syntax:
```
STRUCTURED_FINDINGS:
- file: <path> | line: <number> | severity: <CRITICAL|HIGH|MEDIUM|LOW|NIT> | category: <category> | body: <concrete issue + suggestion with why>
```

---

### Step 3: Triage & Human Immunity Gate

Fetch all unresolved review threads from GitHub:

```bash
gh api graphql -f query='
  query($owner:String!, $repo:String!, $num:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$num) {
        reviewThreads(first:100) {
          nodes {
            id
            isResolved
            isOutdated
            comments(first:20) {
              nodes {
                databaseId
                author { login __typename }
                body
                path
                line
              }
            }
          }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F num=<pr_number>
```

#### The Golden Rule: Human Immunity
Check every comment in each thread:
- A comment is automated only if author is a known bot account (e.g. `[bot]`, `greptile`, `coderabbit`, `sonarcloud`) OR body contains `🤖 Automated comment by`.
- **IF ANY COMMENT IS HUMAN:** The entire thread is marked **HUMAN**:
  - **NEVER** auto-fix this thread.
  - **NEVER** post an automated reply to this thread.
  - **NEVER** resolve this thread.
  - Defer completely for the human author.

#### Classification of Bot Threads & New Findings
- **NIT:** Style, formatting, minor non-blocking suggestions.
  - Reply with brief technical reason:
    ```bash
    gh api repos/<owner>/<repo>/pulls/<pr_number>/comments/<first_comment_id>/replies \
      -X POST -F body="> [!NOTE]\n> 🤖 Automated comment by **Bugpool** — not written by a human\n\nResolved: Style nit / intentional pattern."
    ```
  - Resolve thread via GraphQL `resolveReviewThread`.
- **ACTIONABLE:** Concrete, localized, high/critical confidence fix where change is unambiguous.
  - Send to Step 4 (Auto-Fix Queue).
- **AMBIGUOUS:** Involves product choices, architectural alternatives, or broad trade-offs.
  - Keep thread OPEN and flag in final report.

---

### Step 4: Auto-Fix Loop with Local Safety Gate

For each item in the **Actionable** queue:

1. **Apply the patch:** Make minimal, localized edits to target file(s).
2. **Execute Safety Gate:**
   ```bash
   pnpm typecheck || npm run typecheck
   ```
3. **Handle Result:**
   - **PASSED:**
     - Stage, commit, and push:
       ```bash
       git add <modified_files>
       git commit -m "fix(review): address finding in <file>"
       git push
       ```
     - Reply to thread with commit SHA and explanation.
     - Resolve thread on GitHub.
   - **FAILED (Type/Lint Error):**
     - **Rollback immediately:**
       ```bash
       git checkout -- <modified_files>
       ```
     - Reclassify finding as **AMBIGUOUS** with note: *"Attempted automated fix, but local typecheck failed. Deferring to human."*
     - Leave thread open.

---

### Step 5: Sticky Summary & Quality Score

Maintain exactly **one** sticky summary comment per PR with marker `<!-- bugpool-summary -->`. Find existing comment ID or create new:

```bash
gh api "repos/{owner}/{repo}/issues/{pr_number}/comments" --paginate \
  --jq '[.[] | select(.body | contains("<!-- bugpool-summary -->"))][0].id'
```

#### Quality Score Calculation (0–100)
Calculate score across dimensions:
- Security & Safety (30%)
- Architecture & Simplicity (25%)
- Code Quality & Types (25%)
- Testability (20%)
Deduct points for findings (Critical = -30, High = -15, Medium = -5, Nit = -1). Map score to grade: `A (90-100)`, `B (80-89)`, `C (70-79)`, `D (60-69)`, `F (<60)`.

#### Post or Update Sticky Comment
Update via `PATCH` or create via `gh pr comment`:

```markdown
<!-- bugpool-summary -->
> [!NOTE]
> 🤖 Automated comment by **Bugpool** — not written by a human

## 🎯 Bugpool Review Summary <sub>(@ <short_sha>)</sub>

**Verdict:** <APPROVE | APPROVE WITH NITS | REQUEST CHANGES>
**Quality Score:** <Score>/100 (Grade <Grade>)

### 📊 Review Overview
| Reviewer Lens | Assessment |
| :--- | :--- |
| 🧭 Router (`haiku`) | <1-line assessment + blast radius> |
| 🏛️ Architecture (`sonnet`) | <1-line assessment> |
| 🧪 QA & Tests (`sonnet`) | <1-line assessment> |
| ⚡ React / Stack (`sonnet`) | <1-line assessment> |
| 🔒 Security (`sonnet`) | <1-line assessment> |

<if scope_drift_detected>
> [!WARNING]
> **Scope Drift Detected:** <brief explanation of drift vs PR title/body>
</if>

### 🛠️ Actions Taken
- **Auto-fixed & Resolved:** <count> threads (commits: `<sha1>`, `<sha2>`)
- **Nits Resolved:** <count> threads
- **Human Threads Untouched:** <count> threads
- **Ambiguous Pending for Author:** <count> items

<details>
<summary>📜 History of Prior Rounds</summary>

- round <N> @ <sha> — <verdict>
</details>

---
*Cleaned and verified by Bugpool*
```

---

### Step 6: Terminal Output for the Human Author

Finish execution by printing a concise, actionable report directly in the chat:

```markdown
### 🦹 Bugpool Triage Complete

- **PR:** #<number> (<title>)
- **Quality Score:** <Score>/100 (Grade <Grade>)
- **Resolved automatically:** <n> actionable items (committed & pushed)
- **Nits resolved:** <n> threads

---

#### ⚠️ Itens que precisam da sua decisão (Ambíguos & Humanos):
1. **[Human Thread]** `src/foo.ts:42` — Comentário de @colega: "Precisamos dessa mutation aqui?"
2. **[Ambiguous]** `src/bar.ts:110` — Sugestão de refatoração para cache global (envolve decisão de arquitetura).

Todas as outras pendências foram corrigidas, validadas no typecheck e resolvidas no GitHub!
```
