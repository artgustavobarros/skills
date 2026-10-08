#!/usr/bin/env bash
# Run one bugpool evaluation scenario with a fresh headless Claude ("Claude B").
#
# Usage: run-eval.sh <dev|heldout|clean> [--baseline] [--label <name>] [--keep]
#   --baseline  run one generic single-reviewer prompt instead of /bugpool
#   --label     suffix for the run file (default: skill version or "baseline")
#   --keep      keep the benchmark worktree after the run
#
# Env: BUGPOOL_EVAL_DIR (default $TMPDIR/bugpool-eval), BUGPOOL_EVAL_BUDGET (USD, default 3),
#      BUGPOOL_EVAL_MODEL (orchestrator model, default sonnet).
# Safety: runs inside a throwaway worktree outside the repo; push, commit, gh and file
# edit tools are disallowed. Nothing is posted to GitHub.
set -euo pipefail

scenario="${1:?scenario required: dev|heldout|clean}"
shift
mode="skill"
label=""
keep=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline) mode="baseline" ;;
    --label) label="$2"; shift ;;
    --keep) keep=1 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(dirname "$here")"
repo="$(git -C "$skill_dir" rev-parse --show-toplevel)"
manifest="$here/manifests/$scenario.json"
out_dir="${BUGPOOL_EVAL_DIR:-${TMPDIR:-/tmp}/bugpool-eval}"
budget="${BUGPOOL_EVAL_BUDGET:-3}"
model="${BUGPOOL_EVAL_MODEL:-sonnet}"
base="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["base"])' "$manifest")"
title="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["title"])' "$manifest")"
version="$(sed -n 's/^version: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$skill_dir/SKILL.md" | head -1)"
[[ -z "$label" ]] && label="$([[ $mode == baseline ]] && echo baseline || echo "v${version:-unknown}")"

wt="$(cd "$repo" && python3 "$here/build-bench.py" "$manifest" "$out_dir" --skill "$skill_dir")"
cleanup() { [[ $keep -eq 1 ]] || git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || true; }
trap cleanup EXIT

if [[ $mode == baseline ]]; then
  prompt="You are a senior code reviewer. Review the changes in \`git diff $base...HEAD\` (PR title: \"$title\") for real bugs: security, correctness, reliability, React/Next.js pitfalls, and files unrelated to the stated goal. Read surrounding code to verify each finding; report only findings you can defend with file:line evidence. Do not modify files. Output only a STRUCTURED_FINDINGS list: - file: <path> | line: <n> | severity: <CRITICAL|HIGH|MEDIUM|LOW|NIT> | category: <...> | body: <issue + fix + why>"
else
  prompt="/bugpool --local --base $base --dry-run"
fi

stamp="$(date +%Y%m%d-%H%M%S)"
run_file="$here/runs/$stamp-$scenario-$label.json"
mkdir -p "$here/runs"

start_s=$SECONDS
(
  cd "$wt"
  claude -p "$prompt" \
    --model "$model" \
    --output-format json \
    --max-budget-usd "$budget" \
    --permission-mode bypassPermissions \
    --disallowedTools "Bash(git push:*)" "Bash(git commit:*)" "Bash(git reset:*)" "Bash(git checkout:*)" "Bash(gh:*)" "Edit" "Write" "NotebookEdit"
) >"$run_file"
wall_s=$((SECONDS - start_s))

python3 - "$run_file" "$wall_s" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(f"run file: {sys.argv[1]}")
d['wall_s'] = int(sys.argv[2])
json.dump(d, open(sys.argv[1], 'w'), ensure_ascii=False)
print(f"cost_usd={d.get('total_cost_usd')} wall_s={d['wall_s']} turns={d.get('num_turns')} error={d.get('is_error')}")
PY
