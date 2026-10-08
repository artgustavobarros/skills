#!/usr/bin/env bash
# Post bugpool comments. Bodies always come from a file (real line breaks) and always
# start with the bot header. Never called in --dry-run.
#
#   post.sh reply  <pr_number> <comment_id> <body_file>   reply inside a review thread
#   post.sh sticky <pr_number> <body_file>                create or update the single summary comment
#   post.sh find-sticky <pr_number>                       print the summary comment id (read-only)
set -euo pipefail

HEADER=$'> [!NOTE]\n> 🤖 Automated comment by **Bugpool** — not written by a human'
MARKER='<!-- bugpool-summary -->'

with_header() {
  local src="$1" out
  out="$(mktemp)"
  if head -c 200 "$src" | grep -q "Automated comment by \*\*Bugpool\*\*"; then
    cat "$src" >"$out"
  else
    { printf '%s\n\n' "$HEADER"; cat "$src"; } >"$out"
  fi
  echo "$out"
}

find_sticky() {
  gh api "repos/{owner}/{repo}/issues/$1/comments" --paginate \
    --jq ".[] | select(.body | contains(\"$MARKER\")) | .id" | head -1
}

cmd="${1:?command required: reply|sticky|find-sticky}"
case "$cmd" in
  reply)
    body="$(with_header "${4:?body file required}")"
    gh api "repos/{owner}/{repo}/pulls/${2:?pr}/comments/${3:?comment id}/replies" -X POST -F body=@"$body" --jq .html_url
    rm -f "$body"
    ;;
  sticky)
    pr="${2:?pr}"
    src="${3:?body file required}"
    tmp="$(mktemp)"
    if grep -q "$MARKER" "$src"; then cat "$src" >"$tmp"; else { echo "$MARKER"; cat "$src"; } >"$tmp"; fi
    body="$(with_header "$tmp")"
    # keep the marker as the very first line so find_sticky and humans see it first
    if [[ "$(head -1 "$body")" != "$MARKER" ]]; then
      { echo "$MARKER"; grep -vF "$MARKER" "$body"; } >"$tmp" && mv "$tmp" "$body"
    fi
    id="$(find_sticky "$pr")"
    if [[ -n "$id" ]]; then
      gh api "repos/{owner}/{repo}/issues/comments/$id" -X PATCH -F body=@"$body" --jq .html_url
    else
      gh api "repos/{owner}/{repo}/issues/$pr/comments" -X POST -F body=@"$body" --jq .html_url
    fi
    rm -f "$body" "$tmp"
    ;;
  find-sticky)
    find_sticky "${2:?pr}"
    ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 2
    ;;
esac
