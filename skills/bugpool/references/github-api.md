# GitHub API Recipes

Read this before the first `gh` call in a run. Every command uses only `gh` and
`git`. JSON filtering uses `gh`'s built-in `--jq`, so a standalone `jq` is
**not** required. `gh --jq` has no `--arg`, so substitute literal values (such as
`<viewer>`) directly into the filter string. GitHub logins contain only
`[A-Za-z0-9-]`, so this is safe.

## Conventions (apply to every call)

- **Work directory.** Create one temp directory at the start of the run with
  `mktemp -d -t bugpool.XXXXXX` and note the printed path. Shell variables may
  not survive between tool calls, so reuse the **literal path** afterwards.
  Below it is written `<tmp>`.
- **Bodies always come from files.** Write each comment body to a file with the
  file-writing tool, never with `echo` or `printf` and `\n`, then send it with
  `-F body=@<tmp>/file.md`. A literal `\n` inside a quoted shell string reaches
  GitHub as the two characters `\n` and breaks the `[!NOTE]` callout.
- **`-f` for plain strings, `-F` for `@file` and typed values.** `-F` converts
  `true`, `false`, `null` and integers. **Exception:** when a payload has an
  array of objects (`key[][field]`), use `-F` for **every** field of the call.
  Mixing `-f` and `-F` makes `gh` group the fields into the wrong objects.
- **Bot header.** Every body starts with these lines, followed by a blank line:

  ```markdown
  > [!NOTE]
  > 🤖 Automated comment by **Bugpool** — not written by a human
  ```

## Identity and PR context

```bash
gh api user --jq .login                       # → <viewer>
gh pr view [<n>|<url>] --json number,url,title,body,author,headRefName,baseRefName,headRefOid,state,isCrossRepository
git rev-parse --abbrev-ref HEAD               # current branch
git status --porcelain                        # must print nothing for auto-fix
```

Take `owner/repo` from `url` (`https://github.com/<owner>/<repo>/pull/<n>`).

## Checkout and diff

```bash
gh pr checkout <n>                            # only if current branch != headRefName
git fetch origin <baseRefName> <headRefName>
git rev-parse HEAD                            # compare with headRefOid
git diff origin/<baseRefName>...HEAD --name-only
git diff origin/<baseRefName>...HEAD --stat
git diff origin/<baseRefName>...HEAD
git log origin/<baseRefName>..HEAD --oneline
```

Rounds after the first use `git diff <round_start_sha>..HEAD` instead.

## Review threads (filtered and truncated)

```bash
gh api graphql -f query='
  query($owner:String!, $repo:String!, $num:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$num) {
        reviewThreads(first:100) {
          nodes {
            id isResolved isOutdated
            comments(first:30) {
              nodes { databaseId author { login __typename } body path line }
            }
          }
        }
      }
    }
  }' -f owner=<owner> -f repo=<repo> -F num=<n> --jq '[
  .data.repository.pullRequest.reviewThreads.nodes[]
  | select(.isResolved == false and .isOutdated == false)
  | {
      id,
      path: .comments.nodes[0].path,
      line: .comments.nodes[0].line,
      first_comment_id: .comments.nodes[0].databaseId,
      body_head: (.comments.nodes[0].body[:1500]),
      body_truncated: ((.comments.nodes[0].body | length) > 1500),
      participants: [ .comments.nodes[] | {
        login: .author.login,
        type: .author.__typename,
        has_header: (.body[:300] | contains("🤖 Automated comment by")),
        is_viewer: (.author.login == "<viewer>")
      } ]
    }
]'
```

Classify each participant with the provenance rule in `SKILL.md`. The
`has_header` flag counts only when `is_viewer` is true.

**Known review-bot logins** (match case-insensitively as substrings):
`greptile`, `veria`, `coderabbit`, `cursor`, `sonarcloud`, `codescene`,
`sourcery`, `ellipsis`, `copilot`, `claude`, `dependabot`, `renovate`,
`github-actions`. If AGENTS.md or CLAUDE.md lists more review bots, add them.

### Refetch one full body (only before acting on a truncated thread)

```bash
gh api graphql -f query='
  query($id:ID!) { node(id:$id) { ... on PullRequestReviewThread {
    comments(first:1) { nodes { body } } } } }' -f id=<thread_id>
```

## Post AMBIGUOUS findings as one review

Write the review body and each inline body to their own files. Then pass every
field with `-F`. Each repeated `comments[][path]` starts a new comment object,
so keep the four fields of a comment together and in the same order:

```bash
gh api repos/<owner>/<repo>/pulls/<n>/reviews --method POST \
  -F commit_id=<head_sha> -F event=COMMENT -F body=@<tmp>/review-body.md \
  -F 'comments[][path]=src/a.ts' -F 'comments[][line]=42' -F 'comments[][side]=RIGHT' -F 'comments[][body]=@<tmp>/c1.md' \
  -F 'comments[][path]=src/b.ts' -F 'comments[][line]=7'  -F 'comments[][side]=RIGHT' -F 'comments[][body]=@<tmp>/c2.md' \
  --jq .id
```

Never build the JSON by hand: bodies contain quotes and newlines.

- `event` is always `"COMMENT"`.
- An inline comment's `line` must fall inside a diff hunk on the RIGHT side. If
  the API returns **422**, move the comments that are outside any hunk into the
  review `body` (as `` `file:line` — text ``) and retry once.
- Findings with `line: general` go into the review `body`.

Inline comment body format:

```markdown
> [!NOTE]
> 🤖 Automated comment by **Bugpool** — not written by a human

**[<reviewer tag>]** <emoji> <SEVERITY> · <rule or category>

<issue>

**Evidence:** <file:line and snippet>
**Options:** <the alternatives the author must choose between>
```

Severity emojis: 🔴 CRITICAL, 🟠 HIGH, 🟡 MEDIUM, 🟢 LOW, ⚪ NIT.

In `--review-only` mode, ACTIONABLE findings use the same format, with
**Suggested fix:** in place of **Options:**.

## Reply to a thread, then resolve it

```bash
gh api repos/<owner>/<repo>/pulls/<n>/comments/<first_comment_id>/replies \
  --method POST -F body=@<tmp>/reply-<thread>.md --jq .id
```

Only if the reply returned an id:

```bash
gh api graphql -f query='
  mutation($id:ID!) { resolveReviewThread(input:{threadId:$id}) { thread { isResolved } } }' \
  -f id=<thread_id>
```

If the reply fails, do not resolve. Record the failure for the report.

## Sticky summary (upsert)

Find the existing comment. It must contain the marker **and** be authored by
the viewer, because anyone can paste the marker. `--paginate` applies `--jq`
per page, so emit ids line by line and take the first one:

```bash
gh api "repos/<owner>/<repo>/issues/<n>/comments" --paginate \
  --jq '.[] | select((.body | contains("<!-- bugpool-summary -->")) and .user.login == "<viewer>") | .id' \
  | head -n 1
```

To read its body, which holds the state marker and the history:

```bash
gh api repos/<owner>/<repo>/issues/comments/<comment_id> --jq .body > <tmp>/prev-summary.md
```

Update or create:

```bash
gh api repos/<owner>/<repo>/issues/comments/<comment_id> --method PATCH -F body=@<tmp>/summary.md
gh pr comment <n> --body-file <tmp>/summary.md
```

## State marker

The first line of the sticky body is the visible marker. The second line holds
the state as single-line JSON inside an HTML comment. The JSON must never
contain `--`.

```
<!-- bugpool-summary -->
<!-- bugpool-state {"v":1,"round":2,"sha":"<full head sha>","fp":["a1b2c3d4e5f6","..."]} -->
```

Extract it with:

```bash
grep -o '<!-- bugpool-state {.*} -->' <tmp>/prev-summary.md | sed -E 's/^<!-- bugpool-state //; s/ -->$//'
```

**Finding fingerprint:** the first 12 hex characters of
`sha1("<file>|<rule or category>|<floor(line / 10)>")`. For `line: general`,
use `general` as the last part.

```bash
printf '%s|%s|%s' 'src/a.ts' 'idor' '4' | { sha1sum 2>/dev/null || shasum -a 1; } | cut -c1-12
```

## Stale top-level bot reviews

For top-level PR comments from bots (not review threads), look for a commit
reference: "reviewing commit `<sha>`", "in `<sha>`", or `/commit/<sha>`. If the
referenced SHA is not a prefix of HEAD, skip the comment as stale. If there is
no reference and the comment predates the latest push, skip it too: acting on a
stale review is worse than waiting for the bot to re-run.
