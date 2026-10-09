#!/usr/bin/env bash
# Isolated auto-fix workspace for bugpool. Never touches the user's working tree.
#
#   fix-worktree.sh check-clean                 exit 1 if the user's tree has uncommitted changes
#   fix-worktree.sh create <sha>                worktree + branch bugpool/fix-<short>; prints path
#   fix-worktree.sh gate <wt> <files...>        typecheck + lint check + related tests (no fixes)
#   fix-worktree.sh revert <wt> <files...>      discard edits INSIDE the fix worktree only
#   fix-worktree.sh commit <wt> <message>       one commit with all tracked edits; prints sha
#   fix-worktree.sh push <wt> <remote_ref>      push HEAD to origin/<remote_ref> (only with --push)
#   fix-worktree.sh remove <wt>                 remove the worktree (branch is kept)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"

repo="$(git rev-parse --show-toplevel)"
prefix="${TMPDIR:-/tmp}/bugpool-fix-"

guard_wt() {
  local wt
  wt="$(cd "$1" && pwd)"
  if [[ "$wt" != "$prefix"* || "$wt" == "$repo" ]]; then
    echo "refusing: $wt is not a bugpool fix worktree" >&2
    exit 2
  fi
  echo "$wt"
}

# gate_check <name> <cmd...>: runs one gate check, updating $status and $ran.
# Exit 127 = tool not available for this stack: skipped, not a failure.
gate_check() {
  local name="$1" rc=0
  shift
  echo "## $name"
  "$@" || rc=$?
  [[ $rc -eq 127 ]] && { echo "skipped"; return; }
  ran=$((ran + 1))
  [[ $rc -eq 0 ]] || status=1
}

cmd="${1:?command required}"
shift
case "$cmd" in
  check-clean)
    if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
      echo "dirty: uncommitted changes in $repo — auto-fix skipped" >&2
      exit 1
    fi
    echo "clean"
    ;;
  create)
    sha="$(git -C "$repo" rev-parse "${1:?sha required}")"
    short="${sha:0:7}"
    wt="$prefix$short"
    [[ -e "$wt" ]] && git -C "$repo" worktree remove --force "$wt"
    git -C "$repo" worktree add -q -B "bugpool/fix-$short" "$wt" "$sha"
    link_deps "$repo" "$wt"
    echo "$wt"
    ;;
  gate)
    wt="$(guard_wt "${1:?worktree required}")"
    shift
    cd "$wt"
    mapfile -t files < <(code_files "$@")
    status=0
    ran=0
    gate_check typecheck run_typecheck
    gate_check "lint check" run_lint_check "${files[@]}"
    gate_check "related tests" run_related_tests "${files[@]}"
    if [[ $status -ne 0 ]]; then
      echo "GATE: FAIL"
    elif [[ $ran -eq 0 ]]; then
      echo "GATE: PASS (unverified: no checks available for this stack)"
    else
      echo "GATE: PASS"
    fi
    exit $status
    ;;
  revert)
    wt="$(guard_wt "${1:?worktree required}")"
    shift
    git -C "$wt" checkout -- "$@"
    ;;
  commit)
    wt="$(guard_wt "${1:?worktree required}")"
    git -C "$wt" add -u
    git -C "$wt" diff --cached --quiet && { echo "nothing to commit" >&2; exit 1; }
    git -C "$wt" commit -q -m "${2:?message required}"
    git -C "$wt" rev-parse HEAD
    ;;
  push)
    wt="$(guard_wt "${1:?worktree required}")"
    git -C "$wt" push origin "HEAD:${2:?remote ref required}"
    ;;
  remove)
    wt="$(guard_wt "${1:?worktree required}")"
    git -C "$repo" worktree remove --force "$wt"
    ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 2
    ;;
esac
