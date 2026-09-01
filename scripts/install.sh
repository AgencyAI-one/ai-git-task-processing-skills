#!/usr/bin/env bash
#
# AI Git Task Processing Skills installer
# Installs Claude Code and Codex skills into a target repository.
# Author: Bohdan Kossak
# X: https://x.com/BohdanDJA
# License: MIT

set -Eeuo pipefail

usage() {
    cat <<'USAGE'
Usage: ./scripts/install.sh [--force] /path/to/target-repository

Options:
  --force  Overwrite existing skill and poller files.
  --help   Show this help message.
USAGE
}

force=0
target_path=''

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            force=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --*)
            echo "Error: unknown option '$1'." >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$target_path" ]]; then
                echo "Error: provide exactly one target repository path." >&2
                usage >&2
                exit 2
            fi
            target_path="$1"
            ;;
    esac
    shift
done

if [[ -z "$target_path" ]]; then
    echo "Error: a target repository path is required." >&2
    usage >&2
    exit 2
fi

if [[ ! -d "$target_path" ]]; then
    echo "Error: target directory does not exist: $target_path" >&2
    exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir
source_root="$(cd "$script_dir/.." && pwd)"
readonly source_root
target_root="$(cd "$target_path" && pwd)"
readonly target_root

if [[ "$source_root" == "$target_root" ]]; then
    echo "The skills are already present in this repository."
    exit 0
fi

sources=(
    '.agents/skills/git-job/SKILL.md'
    '.agents/skills/git-queue/SKILL.md'
    '.claude/skills/git-job/SKILL.md'
    '.claude/skills/git-queue/SKILL.md'
    'scripts/git-wait-ready-task.sh'
)

if [[ "$force" -eq 0 ]]; then
    conflicts=()
    for relative_path in "${sources[@]}"; do
        if [[ -e "$target_root/$relative_path" ]]; then
            conflicts+=("$relative_path")
        fi
    done

    if [[ "${#conflicts[@]}" -gt 0 ]]; then
        echo "Error: installation would overwrite existing files:" >&2
        printf '  %s\n' "${conflicts[@]}" >&2
        echo "Re-run with --force only after reviewing those files." >&2
        exit 1
    fi
fi

for relative_path in "${sources[@]}"; do
    destination="$target_root/$relative_path"
    mkdir -p "$(dirname "$destination")"
    cp "$source_root/$relative_path" "$destination"

    if [[ "$relative_path" == scripts/* ]]; then
        chmod 0755 "$destination"
    else
        chmod 0644 "$destination"
    fi

    echo "Installed $relative_path"
done

echo "Installation complete. Commit the installed files in your target repository."
