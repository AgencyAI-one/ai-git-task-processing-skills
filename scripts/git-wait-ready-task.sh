#!/usr/bin/env bash
#
# GitHub Ready Task Poller
# Part of AI Git Task Processing Skills.
# Author: Bohdan Kossak
# X: https://x.com/BohdanDJA
# License: MIT

set -Eeuo pipefail

readonly PROJECT_OWNER="${PROJECT_OWNER:?Set PROJECT_OWNER to a GitHub user or organization login}"
readonly PROJECT_NUMBER="${PROJECT_NUMBER:?Set PROJECT_NUMBER to a GitHub Projects v2 number}"
readonly POLL_SECONDS="${POLL_SECONDS:-20}"
readonly READY_STATUS="${READY_STATUS:-Ready}"

for dependency in gh jq; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "[queue] Error: '$dependency' is required but was not found." >&2
        exit 1
    fi
done

if [[ ! "$PROJECT_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "[queue] Error: PROJECT_NUMBER must be a positive integer." >&2
    exit 1
fi

if [[ ! "$POLL_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
    echo "[queue] Error: POLL_SECONDS must be a positive integer." >&2
    exit 1
fi

if [[ -z "$READY_STATUS" || "$READY_STATUS" == *$'\n'* ]]; then
    echo "[queue] Error: READY_STATUS must be a non-empty, single-line value." >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "[queue] Error: GitHub CLI is not authenticated. Run 'gh auth login'." >&2
    exit 1
fi

echo "[queue] Watching GitHub Project ${PROJECT_OWNER}/${PROJECT_NUMBER} for status '${READY_STATUS}'..." >&2

OWNER_TYPE="$(gh api "users/$PROJECT_OWNER" --jq '.type')"
readonly OWNER_TYPE

case "$OWNER_TYPE" in
    Organization)
        read -r -d '' QUERY <<'GRAPHQL' || true
query($login: String!, $number: Int!, $itemQuery: String!) {
    organization(login: $login) {
        projectV2(number: $number) {
            items(
                first: 100
                query: $itemQuery
                orderBy: {field: POSITION, direction: ASC}
            ) {
                nodes {
                    content {
                        ... on Issue {
                            url
                            number
                            title
                            closed
                        }
                    }
                }
            }
        }
    }
}
GRAPHQL
        readonly ITEMS_PATH='.data.organization.projectV2.items.nodes'
        ;;
    User)
        read -r -d '' QUERY <<'GRAPHQL' || true
query($login: String!, $number: Int!, $itemQuery: String!) {
    user(login: $login) {
        projectV2(number: $number) {
            items(
                first: 100
                query: $itemQuery
                orderBy: {field: POSITION, direction: ASC}
            ) {
                nodes {
                    content {
                        ... on Issue {
                            url
                            number
                            title
                            closed
                        }
                    }
                }
            }
        }
    }
}
GRAPHQL
        readonly ITEMS_PATH='.data.user.projectV2.items.nodes'
        ;;
    *)
        echo "[queue] Error: '$PROJECT_OWNER' is not a GitHub user or organization." >&2
        exit 1
        ;;
esac

escaped_ready_status="${READY_STATUS//\\/\\\\}"
escaped_ready_status="${escaped_ready_status//\"/\\\"}"
readonly ITEM_QUERY="status:\"${escaped_ready_status}\""

while true; do
    RESULT="$(
        gh api graphql \
            -f query="$QUERY" \
            -F login="$PROJECT_OWNER" \
            -F number="$PROJECT_NUMBER" \
            -f itemQuery="$ITEM_QUERY"
    )"

    ISSUE="$(
        printf '%s\n' "$RESULT" |
        jq -r "$ITEMS_PATH |
            map(select(.content.url != null and .content.closed == false)) |
            .[0].content |
            if . == null then empty
            else [.url, (.number|tostring), .title] | @tsv
            end"
    )"

    if [[ -n "$ISSUE" ]]; then
        IFS=$'\t' read -r URL NUMBER TITLE <<< "$ISSUE"

        echo "[queue] Found Ready task #$NUMBER: $TITLE" >&2
        echo "$URL"
        exit 0
    fi

    echo "[queue] No Ready tasks. Checking again in ${POLL_SECONDS}s..." >&2
    sleep "$POLL_SECONDS"
done
