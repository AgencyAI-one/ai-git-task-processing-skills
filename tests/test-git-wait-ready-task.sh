#!/usr/bin/env bash
#
# Tests for the GitHub Ready Task Poller
# Author: Bohdan Kossak
# X: https://x.com/BohdanDJA
# License: MIT

set -Eeuo pipefail

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly test_dir
project_root="$(cd "$test_dir/.." && pwd)"
readonly project_root
readonly poller="$project_root/scripts/git-wait-ready-task.sh"

gh() {
    if [[ "$1" == 'auth' && "$2" == 'status' ]]; then
        return 0
    fi

    if [[ "$1" == 'api' && "$2" == users/* ]]; then
        printf '%s\n' "$MOCK_OWNER_TYPE"
        return 0
    fi

    if [[ "$1" == 'api' && "$2" == 'graphql' ]]; then
        expected_query='itemQuery=status:"Ready for work"'
        found_query=0
        for argument in "$@"; do
            if [[ "$argument" == "$expected_query" ]]; then
                found_query=1
            fi
        done

        if [[ "$found_query" -ne 1 ]]; then
            echo "Mock expected $expected_query" >&2
            return 1
        fi

        if [[ "$MOCK_OWNER_TYPE" == 'Organization' ]]; then
            response='{
                "data": {
                    "organization": {
                        "projectV2": {
                            "items": {
                                "nodes": [
                                    {"content": {"url": "https://github.com/example/repo/issues/42", "number": 42, "title": "First ready issue", "closed": false}},
                                    {"content": {"url": "https://github.com/example/repo/issues/99", "number": 99, "title": "Second ready issue", "closed": false}}
                                ]
                            }
                        }
                    }
                }
            }'
        else
            response='{
                "data": {
                    "user": {
                        "projectV2": {
                            "items": {
                                "nodes": [
                                    {"content": {"url": "https://github.com/example/repo/issues/7", "number": 7, "title": "User project issue", "closed": false}}
                                ]
                            }
                        }
                    }
                }
            }'
        fi

        printf '%s\n' "$response"
        return 0
    fi

    echo "Unexpected gh invocation: $*" >&2
    return 1
}

export -f gh

run_poller() {
    MOCK_OWNER_TYPE="$1" \
    PROJECT_OWNER='example' \
    PROJECT_NUMBER='3' \
    READY_STATUS='Ready for work' \
    POLL_SECONDS='1' \
        bash "$poller" 2>/dev/null
}

export MOCK_OWNER_TYPE

organization_result="$(run_poller 'Organization')"
if [[ "$organization_result" != 'https://github.com/example/repo/issues/42' ]]; then
    echo "Organization project test failed: $organization_result" >&2
    exit 1
fi

user_result="$(run_poller 'User')"
if [[ "$user_result" != 'https://github.com/example/repo/issues/7' ]]; then
    echo "User project test failed: $user_result" >&2
    exit 1
fi

if PROJECT_OWNER='example' PROJECT_NUMBER='invalid' bash "$poller" >/dev/null 2>&1; then
    echo "Invalid project number test failed." >&2
    exit 1
fi

echo "Poller tests passed."
