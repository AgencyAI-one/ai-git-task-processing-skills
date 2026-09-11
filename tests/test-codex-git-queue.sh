#!/usr/bin/env bash
#
# Tests for the fresh-context Codex queue runner
# Author: Bohdan Kossak
# X: https://x.com/BohdanDJA
# License: MIT

set -Eeuo pipefail

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly test_dir
project_root="$(cd "$test_dir/.." && pwd)"
readonly project_root
readonly runner="$project_root/scripts/codex-git-queue.sh"

tmp_dir="$(mktemp -d)"
readonly tmp_dir
trap 'rm -rf "$tmp_dir"' EXIT

repo="$tmp_dir/repo"
mkdir -p "$repo/scripts" "$tmp_dir/bin"

git init -q -b dev_01 "$repo"
git -C "$repo" config user.email 'test@example.com'
git -C "$repo" config user.name 'Queue Test'
printf 'test\n' > "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -q -m 'Initial commit'

cp "$runner" "$repo/scripts/codex-git-queue.sh"
chmod +x "$repo/scripts/codex-git-queue.sh"

cat > "$repo/scripts/git-wait-ready-task.sh" <<'POLLER'
#!/usr/bin/env bash
printf '%s\n' 'https://github.com/example/repo/issues/42'
POLLER
chmod +x "$repo/scripts/git-wait-ready-task.sh"

cat > "$tmp_dir/bin/codex" <<'CODEX'
#!/usr/bin/env bash
set -Eeuo pipefail

{
    printf 'BASE=%s\n' "${GIT_JOB_BASE_BRANCH:-}"
    printf 'ARG=%s\n' "$@"
} > "$CODEX_TEST_LOG"

git switch -q -c ai/issue-42-test
CODEX
chmod +x "$tmp_dir/bin/codex"

log="$tmp_dir/codex.log"
PATH="$tmp_dir/bin:$PATH" \
CODEX_TEST_LOG="$log" \
CODEX_QUEUE_MAX_TASKS='1' \
CODEX_RETRY_SECONDS='1' \
    bash -c 'cd "$1" && ./scripts/codex-git-queue.sh' _ "$repo" >/dev/null 2>&1

current_branch="$(git -C "$repo" branch --show-current)"
if [[ "$current_branch" != 'dev_01' ]]; then
    echo "Runner did not restore base branch: $current_branch" >&2
    exit 1
fi

for expected in \
    'BASE=dev_01' \
    'ARG=exec' \
    'ARG=--ephemeral' \
    'ARG=--cd' \
    "ARG=$repo" \
    'ARG=--sandbox' \
    'ARG=workspace-write' \
    'ARG=sandbox_workspace_write.network_access=true' \
    'ARG=$git-job https://github.com/example/repo/issues/42'; do
    if ! grep -Fqx "$expected" "$log"; then
        echo "Missing expected Codex invocation entry: $expected" >&2
        cat "$log" >&2
        exit 1
    fi
done

echo "Codex queue runner tests passed."
