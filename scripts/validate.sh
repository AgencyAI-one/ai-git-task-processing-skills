#!/usr/bin/env bash
#
# AI Git Task Processing Skills validator
# Checks mirrored skills, frontmatter, shell scripts, and poller behavior.
# Author: Bohdan Kossak
# X: https://x.com/BohdanDJA
# License: MIT

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir
project_root="$(cd "$script_dir/.." && pwd)"
readonly project_root

cd "$project_root"

shell_files=(scripts/*.sh tests/*.sh)

echo "[validate] Checking Bash syntax..."
for shell_file in "${shell_files[@]}"; do
    bash -n "$shell_file"
done

if command -v shellcheck >/dev/null 2>&1; then
    echo "[validate] Running ShellCheck..."
    shellcheck "${shell_files[@]}"
else
    echo "[validate] ShellCheck not found; skipping optional lint check."
fi

echo "[validate] Comparing Claude Code and Codex skill copies..."
cmp .agents/skills/git-job/SKILL.md .claude/skills/git-job/SKILL.md
cmp .agents/skills/git-queue/SKILL.md .claude/skills/git-queue/SKILL.md

echo "[validate] Checking skill frontmatter..."
for skill_file in .agents/skills/*/SKILL.md .claude/skills/*/SKILL.md; do
    first_line="$(sed -n '1p' "$skill_file")"
    if [[ "$first_line" != '---' ]]; then
        echo "Invalid frontmatter start: $skill_file" >&2
        exit 1
    fi

    frontmatter="$(sed -n '2,/^---$/p' "$skill_file")"
    if [[ "$(printf '%s\n' "$frontmatter" | tail -n 1)" != '---' ]]; then
        echo "Missing frontmatter end: $skill_file" >&2
        exit 1
    fi

    printf '%s\n' "$frontmatter" | grep -Eq '^name: [a-z0-9-]+$'
    printf '%s\n' "$frontmatter" | grep -Eq '^description: .+$'
    printf '%s\n' "$frontmatter" | grep -Eq '^license: MIT$'
    printf '%s\n' "$frontmatter" | grep -Eq '^  author: "Bohdan Kossak"$'
    printf '%s\n' "$frontmatter" | grep -Eq '^  x-profile: "https://x.com/BohdanDJA"$'
done

echo "[validate] Running poller tests..."
bash tests/test-git-wait-ready-task.sh

echo "[validate] All checks passed."
