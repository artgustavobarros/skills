#!/usr/bin/env bash
# Shared helpers for bugpool scripts. Source, don't execute.
# All checks are NON-MUTATING: never pass --fix / --write / --apply to any tool.

# has_dep <name>: true if package.json lists <name> in any dependency field.
has_dep() {
  python3 - "$1" <<'PY' 2>/dev/null
import json, sys
p = json.load(open("package.json"))
deps = {**p.get("dependencies", {}), **p.get("devDependencies", {})}
sys.exit(0 if sys.argv[1] in deps else 1)
PY
}

# has_script <name>: true if package.json defines scripts.<name>.
has_script() {
  python3 - "$1" <<'PY' 2>/dev/null
import json, sys
sys.exit(0 if sys.argv[1] in json.load(open("package.json")).get("scripts", {}) else 1)
PY
}

# code_files <files...>: keep existing source files a linter/test runner can take.
code_files() {
  local f
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    case "$f" in
      *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css) echo "$f" ;;
    esac
  done
}

# run_typecheck: project typecheck via npm (works with symlinked node_modules).
run_typecheck() {
  if has_script typecheck; then
    npm run -s typecheck
  elif [[ -f tsconfig.json ]]; then
    npx --no-install tsc --noEmit
  else
    return 127
  fi
}

# run_lint_check <files...>: lint/format check on the given files, no fixes.
run_lint_check() {
  [[ $# -gt 0 ]] || return 0
  if has_dep ultracite; then
    npx --no-install ultracite check "$@"
  elif has_dep @biomejs/biome; then
    npx --no-install biome check "$@"
  elif has_dep eslint; then
    npx --no-install eslint "$@"
  elif has_script lint; then
    npm run -s lint
  else
    return 127
  fi
}

# run_related_tests <files...>: unit tests related to the given files.
run_related_tests() {
  [[ $# -gt 0 ]] || return 0
  if has_dep vitest; then
    npx --no-install vitest related --run --passWithNoTests "$@"
  else
    return 127
  fi
}

# link_deps <src_repo> <dst_worktree>: symlink node_modules and .env* (not .env.example).
link_deps() {
  local src="$1" dst="$2" f
  [[ -e "$src/node_modules" && ! -e "$dst/node_modules" ]] && ln -s "$src/node_modules" "$dst/node_modules"
  for f in "$src"/.env*; do
    [[ -e "$f" ]] || continue
    [[ "$(basename "$f")" == ".env.example" ]] && continue
    [[ -e "$dst/$(basename "$f")" ]] || ln -s "$f" "$dst/$(basename "$f")"
  done
}
