#!/usr/bin/env python3
"""Build a bugpool benchmark worktree from a scenario manifest.

Usage: build-bench.py <manifest.json> <out_dir> [--skill <skill_dir>]

Creates a detached git worktree at <out_dir>/<scenario> checked out at the
manifest head, applies each seed (exact find/replace, must match once),
commits locally, symlinks node_modules / .env* / the skill under test, and
writes <out_dir>/<scenario>.diff (base...HEAD). Prints the worktree path.
Never pushes and never touches the main working tree.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def git(*args, cwd):
    return subprocess.run(
        ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
    ).stdout


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    manifest = json.loads(Path(sys.argv[1]).read_text())
    out_dir = Path(sys.argv[2]).resolve()
    skill_dir = None
    if "--skill" in sys.argv:
        skill_dir = Path(sys.argv[sys.argv.index("--skill") + 1]).resolve()

    repo = Path(git("rev-parse", "--show-toplevel", cwd=Path.cwd()).strip())
    if out_dir == repo or repo in out_dir.parents:
        sys.exit(f"out_dir must be outside the repository: {out_dir}")
    out_dir.mkdir(parents=True, exist_ok=True)
    wt = out_dir / manifest["scenario"]
    if wt.exists():
        subprocess.run(["git", "worktree", "remove", "--force", str(wt)], cwd=repo)
    git("worktree", "add", "--detach", str(wt), manifest["head"], cwd=repo)

    for seed in manifest["seeds"]:
        path = wt / seed["file"]
        text = path.read_text()
        count = text.count(seed["find"])
        if count != 1:
            subprocess.run(["git", "worktree", "remove", "--force", str(wt)], cwd=repo)
            sys.exit(f"seed {seed['id']}: expected 1 match in {seed['file']}, found {count}")
        path.write_text(text.replace(seed["find"], seed["replace"], 1))

    if manifest["seeds"]:
        git(
            "-c", "user.name=bugpool-bench", "-c", "user.email=bench@localhost",
            "commit", "-qam", manifest["title"], cwd=wt,
        )

    for name in ["node_modules", *[p.name for p in repo.glob(".env*") if p.name != ".env.example"]]:
        src, dst = repo / name, wt / name
        if src.exists() and not dst.exists():
            dst.symlink_to(src)

    if skill_dir:
        for rel in [".claude/skills/bugpool", ".agents/skills/bugpool"]:
            dst = wt / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.is_symlink() or dst.exists():
                subprocess.run(["rm", "-rf", str(dst)], check=True)
            dst.symlink_to(skill_dir)
        commands = repo / ".claude/commands/bugpool.md"
        if commands.exists():
            (wt / ".claude/commands").mkdir(parents=True, exist_ok=True)
            dst = wt / ".claude/commands/bugpool.md"
            if not dst.exists():
                dst.symlink_to(commands)

    diff = git("diff", f"{manifest['base']}...HEAD", cwd=wt)
    (out_dir / f"{manifest['scenario']}.diff").write_text(diff)
    print(wt)


if __name__ == "__main__":
    main()
