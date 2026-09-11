#!/usr/bin/env bash
#
# Fresh-context Codex GitHub queue runner
# Part of AI Git Task Processing Skills.
# Author: Bohdan Kossak
# X: https://x.com/BohdanDJA
# License: MIT

set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
readonly repo_root
readonly poller="$repo_root/scripts/git-wait-ready-task.sh"
readonly codex_sandbox="${CODEX_SANDBOX:-workspace-write}"
readonly codex_network_access="${CODEX_NETWORK_ACCESS:-true}"
readonly retry_seconds="${CODEX_RETRY_SECONDS:-10}"
readonly max_tasks="${CODEX_QUEUE_MAX_TASKS:-0}"

cd "$repo_root"

for dependency in git codex; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "[codex-queue] Error: '$dependency' is required but was not found." >&2
        exit 1
    fi
done

if [[ ! -x "$poller" ]]; then
    echo "[codex-queue] Error: queue poller is missing or not executable: $poller" >&2
    exit 1
fi

case "$codex_sandbox" in
    read-only|workspace-write|danger-full-access) ;;
    *)
        echo "[codex-queue] Error: CODEX_SANDBOX must be read-only, workspace-write, or danger-full-access." >&2
        exit 1
        ;;
esac

if [[ "$codex_network_access" != 'true' && "$codex_network_access" != 'false' ]]; then
    echo "[codex-queue] Error: CODEX_NETWORK_ACCESS must be true or false." >&2
    exit 1
fi

if [[ ! "$retry_seconds" =~ ^[1-9][0-9]*$ ]]; then
    echo "[codex-queue] Error: CODEX_RETRY_SECONDS must be a positive integer." >&2
    exit 1
fi

if [[ ! "$max_tasks" =~ ^[0-9]+$ ]]; then
    echo "[codex-queue] Error: CODEX_QUEUE_MAX_TASKS must be 0 or a positive integer." >&2
    exit 1
fi

processed_tasks=0

echo "[codex-queue] Starting queue with a fresh Codex context per task..." >&2

while true; do
    base_branch="$(git branch --show-current)"
    if [[ -z "$base_branch" ]]; then
        echo "[codex-queue] Error: start each task from a named branch, not detached HEAD." >&2
        exit 1
    fi

    baseline_status="$(git status --porcelain=v1)"

    issue_url="$($poller)"
    if [[ -z "$issue_url" ]]; then
        echo "[codex-queue] Error: poller exited without an issue URL." >&2
        sleep "$retry_seconds"
        continue
    fi

    echo >&2
    echo "============================================================" >&2
    echo "[codex-queue] Fresh Codex task" >&2
    echo "[codex-queue] Base branch: $base_branch" >&2
    echo "[codex-queue] Issue: $issue_url" >&2
    echo "============================================================" >&2
    echo >&2

    codex_args=(
        exec
        --ephemeral
        --cd "$repo_root"
        --sandbox "$codex_sandbox"
    )

    if [[ "$codex_sandbox" == 'workspace-write' ]]; then
        codex_args+=(
            -c "sandbox_workspace_write.network_access=$codex_network_access"
        )
    fi

    if [[ -n "${CODEX_PROFILE:-}" ]]; then
        codex_args+=(--profile "$CODEX_PROFILE")
    fi

    if GIT_JOB_BASE_BRANCH="$base_branch" \
        codex "${codex_args[@]}" "\$git-job $issue_url"; then
        codex_exit=0
    else
        codex_exit=$?
        echo "[codex-queue] Codex exited with code $codex_exit for $issue_url." >&2
    fi

    current_branch="$(git branch --show-current)"
    if [[ "$current_branch" != "$base_branch" ]]; then
        echo "[codex-queue] Agent left checkout on '$current_branch'; restoring '$base_branch'..." >&2

        if ! git switch "$base_branch" >/dev/null; then
            echo "[codex-queue] Error: could not restore base branch safely. Queue stopped." >&2
            exit 1
        fi

        if [[ -n "${DEV_SERVER_RESTART_COMMAND:-}" ]]; then
            echo "[codex-queue] Restarting local dev server after branch recovery..." >&2
            if ! bash -lc "$DEV_SERVER_RESTART_COMMAND"; then
                echo "[codex-queue] Error: dev server restart failed after branch recovery. Queue stopped." >&2
                exit 1
            fi
        fi
    fi

    final_status="$(git status --porcelain=v1)"
    if [[ "$final_status" != "$baseline_status" ]]; then
        echo "[codex-queue] Error: worktree state differs from the pre-task baseline after returning to '$base_branch'." >&2
        echo "[codex-queue] Review the checkout before processing another issue. Queue stopped." >&2
        exit 1
    fi

    processed_tasks=$((processed_tasks + 1))
    if [[ "$max_tasks" -gt 0 && "$processed_tasks" -ge "$max_tasks" ]]; then
        echo "[codex-queue] Reached CODEX_QUEUE_MAX_TASKS=$max_tasks; stopping." >&2
        exit "$codex_exit"
    fi

    if [[ "$codex_exit" -ne 0 ]]; then
        echo "[codex-queue] Retrying queue in ${retry_seconds}s..." >&2
        sleep "$retry_seconds"
    fi
done
