---
name: git-job
description: Execute one GitHub issue end to end by reviewing its context, implementing and testing the change, updating the pull request or branch, reporting the result, and moving the configured GitHub Project item to review. Use when given a specific GitHub issue URL; do not use it to select work from a queue.
license: MIT
metadata:
  author: "Bohdan Kossak"
  x-profile: "https://x.com/BohdanDJA"
---

<!--
  AI Git Task Processing Skills
  Author: Bohdan Kossak
  X: https://x.com/BohdanDJA
  License: MIT
-->

# GitHub Issue Workflow

Process exactly one GitHub issue: the URL supplied to this invocation.

## Configuration

Use these environment variables when they are set:

- `PROJECT_OWNER` and `PROJECT_NUMBER`: the only GitHub Project whose status may be changed.
- `IN_PROGRESS_STATUS`: work-started status; default to `In Progress`.
- `IN_REVIEW_STATUS`: review-ready status; default to `In Review`.
- `TASK_COMMENT_LANGUAGE`: language for GitHub comments. If unset, use the issue's language and default to English when unclear.

Never change the status of an unrelated issue or of the same issue in another project.

## Understand the Issue

1. Read the complete description and acceptance criteria.
2. Read every comment in chronological order. Treat newer confirmed corrections as higher priority when requirements changed.
3. Inspect every relevant attachment, image, screenshot, document, and linked discussion.
4. Review referenced or related pull requests, branches, commits, and code history when useful.
5. Determine what is already implemented and what remains. Preserve valid existing work and do not duplicate it.

## Start Work

1. Confirm the target repository, issue, and configured GitHub Project before changing anything.
2. Move only this issue to the configured in-progress status. If it is already there, continue.
3. Inspect the current branch or worktree and all uncommitted changes.
4. Preserve unrelated user changes. Do not overwrite, revert, stage, or commit them.

## Implement and Verify

1. Implement every requirement from the issue and its latest confirmed comments.
2. Keep the change scoped. Record unrelated follow-up work instead of silently expanding the issue.
3. Resolve small unspecified details from repository conventions, surrounding code, tests, and issue context.
4. Review existing coverage and add or update tests for changed behavior.
5. Run the relevant tests plus applicable lint, format, type-check, and build commands.
6. Fix failures caused by the implementation. Do not claim checks passed unless they actually ran and passed.
7. Review the complete diff against the description, comments, attachments, acceptance criteria, and project conventions.
8. Remove accidental debug code, temporary files, and generated artifacts before finishing.

## Deliver the Change

Follow the repository's established Git workflow when authorized by the issue workflow:

1. Commit the completed work with a meaningful issue reference when commits are expected.
2. Push the branch when the repository expects remote branches.
3. Create or update the pull request when pull requests are used. Never create a duplicate pull request.
4. Add a concise final issue comment covering:
   - what changed;
   - the important files or areas affected;
   - tests and checks run, including results;
   - branch or pull request details;
   - incomplete work, blockers, or recommended follow-up issues.
5. Only after the main work is complete and validated, move this issue to the configured review status.

## Blocked Work

Treat the issue as blocked when the main change cannot be completed safely, required checks fail, or the result cannot be validated.

When blocked:

1. Leave the issue in the configured in-progress status.
2. Add a comment explaining the blocker, work completed, impact, and exact action needed to continue.
3. Do not mark the issue complete or move it to review.
4. Do not retry destructive or clearly failing actions indefinitely.

## Queue Boundary

- Never search for or select another issue.
- Never process more than the supplied issue.
- Do not ask the user to make routine implementation decisions that can be resolved from available evidence.
- If a requirement is genuinely impossible or unsafe to infer, use the blocked workflow.
- Return control after this issue reaches review or is documented as blocked. The `git-queue` skill schedules subsequent work.
