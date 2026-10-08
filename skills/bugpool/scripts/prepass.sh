#!/usr/bin/env bash
# Deterministic, NON-MUTATING pre-pass for bugpool. Run from the repository root.
#
#   prepass.sh <base> [--local]
#
# Changed files = git diff <base>...HEAD (+ uncommitted and untracked with --local).
# Runs lint check (no fixes) on changed files, project typecheck, and related unit tests.
# Prints a markdown block for reviewers. Always exits 0; per-tool status is ok|fail|skipped.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"

base="${1:?base ref required}"
local_mode=0
[[ "${2:-}" == "--local" ]] && local_mode=1
max_lines="${BUGPOOL_PREPASS_MAX_LINES:-150}"

mapfile -t changed < <(
  {
    git diff --name-only --diff-filter=ACMR "$base...HEAD"
    if [[ $local_mode -eq 1 ]]; then
      git diff --name-only --diff-filter=ACMR HEAD
      git ls-files --others --exclude-standard
    fi
  } | sort -u
)
mapfile -t files < <(code_files "${changed[@]}")

section() {
  local name="$1"
  shift
  local out status
  out="$("$@" 2>&1)"
  status=$?
  local label="ok"
  [[ $status -eq 127 ]] && label="skipped"
  [[ $status -ne 0 && $status -ne 127 ]] && label="fail"
  echo "### $name: $label"
  if [[ $label != "ok" || -n "${BUGPOOL_PREPASS_VERBOSE:-}" ]]; then
    echo '```'
    printf '%s\n' "$out" | tail -n "$max_lines"
    echo '```'
  fi
  echo
}

echo "## Pre-pass ($base...HEAD$([[ $local_mode -eq 1 ]] && echo ' + working tree'))"
echo
echo "Changed files (${#changed[@]}): ${changed[*]:-none}"
echo
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No lintable source files changed."
  exit 0
fi
section "lint check (changed files, no fixes)" run_lint_check "${files[@]}"
section "typecheck (project)" run_typecheck
section "related unit tests" run_related_tests "${files[@]}"
exit 0
