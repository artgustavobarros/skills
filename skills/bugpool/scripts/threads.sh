#!/usr/bin/env bash
# Review threads for bugpool triage. Run inside the repository.
#
#   threads.sh list <pr_number>       unresolved threads as JSON lines, each with "human": true|false
#   threads.sh resolve <thread_id>    resolve one thread (never call for human threads)
#
# A comment is automated only if its author is a GitHub Bot / *[bot] / known review bot,
# or its body STARTS WITH the bugpool bot header. Any other comment makes the thread human.
set -euo pipefail

cmd="${1:?command required: list|resolve}"
case "$cmd" in
  list)
    pr="${2:?pr number required}"
    owner_repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
    gh api graphql --paginate -F owner="${owner_repo%/*}" -F repo="${owner_repo#*/}" -F num="$pr" -f query='
      query($owner:String!, $repo:String!, $num:Int!, $endCursor:String) {
        repository(owner:$owner, name:$repo) {
          pullRequest(number:$num) {
            reviewThreads(first:50, after:$endCursor) {
              pageInfo { hasNextPage endCursor }
              nodes {
                id isResolved isOutdated path line
                comments(first:50) {
                  nodes { databaseId author { login __typename } body }
                }
              }
            }
          }
        }
      }' --jq '.data.repository.pullRequest.reviewThreads.nodes[]' |
      python3 -c '
import json, sys
BOTS = {"coderabbitai", "greptile-apps", "sonarcloud", "github-actions", "copilot-pull-request-reviewer", "vercel"}
HEADER = "> [!NOTE]\n> 🤖 Automated comment by **Bugpool**"
def automated(c):
    a = c.get("author") or {}
    login = (a.get("login") or "").lower()
    return a.get("__typename") == "Bot" or login.endswith("[bot]") or login in BOTS or (c.get("body") or "").lstrip().startswith(HEADER)
for line in sys.stdin:
    t = json.loads(line)
    if t["isResolved"]:
        continue
    comments = t["comments"]["nodes"]
    print(json.dumps({
        "thread_id": t["id"], "path": t["path"], "line": t["line"], "outdated": t["isOutdated"],
        "first_comment_id": comments[0]["databaseId"] if comments else None,
        "human": any(not automated(c) for c in comments),
        "comments": [{"author": (c.get("author") or {}).get("login"), "body": (c.get("body") or "")[:500]} for c in comments],
    }, ensure_ascii=False))
'
    ;;
  resolve)
    gh api graphql -F id="${2:?thread id required}" -f query='
      mutation($id:ID!) { resolveReviewThread(input:{threadId:$id}) { thread { isResolved } } }' \
      --jq '.data.resolveReviewThread.thread.isResolved'
    ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 2
    ;;
esac
