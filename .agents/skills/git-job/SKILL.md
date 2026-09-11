---
name: git-job
description: Execute one GitHub issue end to end on an isolated task branch by reviewing its context, implementing and testing the change, integrating completed work back into the branch that was active before the task, restoring local development services, reporting the result, and moving the configured GitHub Project item to review. Use when given a specific GitHub issue URL; do not use it to select work from a queue.
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
- `GIT_JOB_BASE_BRANCH`: expected integration branch supplied by an external queue runner. When unset, use the named branch that is current when this job starts.
- `TASK_BRANCH_PREFIX`: task-branch prefix; default to `ai/issue-`.
- `DEV_SERVER_RESTART_COMMAND`: optional repository-specific command that safely starts or restarts the local development server after branch changes. It should return instead of permanently occupying the foreground.
- `DEV_SERVER_CHECK_COMMAND`: optional command that verifies the local development server is ready after a restart.

Never change the status of an unrelated issue or of the same issue in another project.

## Understand the Issue

1. Read the complete description and acceptance criteria.
2. Read every comment in chronological order. Treat newer confirmed corrections as higher priority when requirements changed.
3. Inspect every relevant attachment, image, screenshot, document, and linked discussion.
4. Review referenced or related pull requests, branches, commits, and code history when useful.
5. Determine what is already implemented and what remains. Preserve valid existing work and do not duplicate it.

## Establish the Task Branch

1. Confirm the target repository, issue, and configured GitHub Project before changing anything.
2. Inspect the current branch or worktree and all uncommitted changes. Preserve unrelated user changes; never overwrite, revert, stage, commit, or stash them just to make the workflow easier.
3. Determine `BASE_BRANCH` before switching branches:
   - when `GIT_JOB_BASE_BRANCH` is set, verify that branch exists and use it;
   - otherwise require a named current branch and use that branch;
   - this is the branch to which completed work must return, for example `dev_01`.
4. Record the starting commit of `BASE_BRANCH` so unexpected movement of the integration branch can be detected before merge-back.
5. Move only this issue to the configured in-progress status. If it is already there, continue.
6. Create a dedicated task branch from `BASE_BRANCH`, using the issue number and a short slug, for example `ai/issue-123-fix-login`. Never implement a new issue directly on `BASE_BRANCH` unless repository policy explicitly requires that.
7. If an existing branch unambiguously belongs to this same issue, inspect it and reuse valid prior work instead of creating a duplicate branch.
8. Switch to the task branch without discarding unrelated worktree changes. If branch isolation cannot be done safely because of conflicting local state, use the blocked workflow rather than modifying unrelated work.
9. If the repository has a local development server, make sure it reflects the task branch before UI or runtime testing:
   - prefer `DEV_SERVER_RESTART_COMMAND` when configured;
   - otherwise use only a restart/start workflow clearly documented by the repository or already used by the current project;
   - if the server uses reliable hot reload and already follows the checked-out files, do not restart it unnecessarily;
   - never kill arbitrary processes merely because they occupy a likely development port.
10. When a server is restarted and `DEV_SERVER_CHECK_COMMAND` is configured, run the check before relying on the server for validation.

## Implement and Verify

1. Implement every requirement from the issue and its latest confirmed comments.
2. Keep the change scoped. Record unrelated follow-up work instead of silently expanding the issue.
3. Resolve small unspecified details from repository conventions, surrounding code, tests, and issue context.
4. Review existing coverage and add or update tests for changed behavior.
5. Run the relevant tests plus applicable lint, format, type-check, and build commands.
6. Fix failures caused by the implementation. Do not claim checks passed unless they actually ran and passed.
7. For web applications, use the local development server for relevant runtime or UI checks when it is available. Restart or reload it during the task when dependency, environment, configuration, or build-pipeline changes require that.
8. Review the complete diff against the description, comments, attachments, acceptance criteria, and project conventions.
9. Remove accidental debug code, temporary files, and generated artifacts before finishing.

## Integrate Completed Work

Only integrate the task when the requested change is complete and the required validation has passed.

1. Commit the completed task work on the task branch with a meaningful issue reference when commits are expected. Never include unrelated user changes.
2. Re-check `BASE_BRANCH` before integration. If it moved since the task started, understand why and incorporate the new base safely before proceeding; do not overwrite or force-reset newer work.
3. Unless the repository explicitly requires pull-request-only integration, switch back to `BASE_BRANCH` and merge the task branch into it using the repository's established merge convention.
4. When no merge convention is documented, prefer a normal non-destructive Git merge. If an integration conflict cannot be resolved confidently from the issue and repository context, do not guess; preserve the task branch and use the blocked workflow.
5. After the task changes are present on `BASE_BRANCH`, update the local development server so it is running from the integrated branch:
   - run `DEV_SERVER_RESTART_COMMAND` when configured;
   - otherwise use the repository's known safe restart/reload workflow when one exists;
   - run `DEV_SERVER_CHECK_COMMAND` when configured.
6. Perform a post-integration smoke check appropriate to the changed behavior. For web changes, confirm the restarted or reloaded local server is serving the integrated code.
7. If the post-integration check reveals a task-caused problem, keep the issue in progress, fix it through the task branch and repeat integration. Do not mark the issue ready for review while the integrated branch is known to be broken.
8. If repository policy requires pull requests into `BASE_BRANCH`, do not bypass that policy: push the task branch and create or update the pull request targeting `BASE_BRANCH`, then return the local checkout to `BASE_BRANCH` and restore its development server. Never create a duplicate pull request.
9. When direct updates to the development branch are the repository's established workflow, push the integrated `BASE_BRANCH` only when that push is authorized and expected.

## Deliver the Change

1. Add a concise final issue comment covering:
   - what changed;
   - the task branch and integration/base branch;
   - the important files or areas affected;
   - tests and checks run, including results;
   - local development server restart/check results when applicable;
   - push or pull request details when applicable;
   - incomplete work, blockers, or recommended follow-up issues.
2. Only after the main work is complete, validated, integrated or submitted through the repository's required PR workflow, and the local checkout is back on `BASE_BRANCH`, move this issue to the configured review status.
3. Return control with the repository left on `BASE_BRANCH`, ready for the next task.

## Blocked Work

Treat the issue as blocked when the main change cannot be completed safely, required checks fail, integration cannot be completed safely, or the result cannot be validated.

When blocked:

1. Leave the issue in the configured in-progress status.
2. Do not merge incomplete task work into `BASE_BRANCH` and do not move the issue to review.
3. Preserve useful task-related partial work on the dedicated task branch. If a clean branch switch requires saving task-related changes, commit only those task-related changes as clearly incomplete/WIP work; never include unrelated user changes.
4. Add a comment explaining the blocker, work completed, task branch, impact, and exact action needed to continue.
5. Switch the local checkout back to `BASE_BRANCH` without discarding unrelated changes. If returning safely is impossible, stop and report the exact repository state so a subsequent task is not started from the wrong branch.
6. After returning to `BASE_BRANCH`, restore the local development server using `DEV_SERVER_RESTART_COMMAND` or the repository's known safe workflow when applicable, then run `DEV_SERVER_CHECK_COMMAND` when configured.
7. Do not retry destructive or clearly failing actions indefinitely.
8. Return control only after the repository is safely back on `BASE_BRANCH`, or clearly report that this invariant could not be restored.

## Queue Boundary

- Never search for or select another issue.
- Never process more than the supplied issue.
- Do not ask the user to make routine implementation decisions that can be resolved from available evidence.
- If a requirement is genuinely impossible or unsafe to infer, use the blocked workflow.
- Return control after this issue reaches review or is documented as blocked. The queue layer schedules subsequent work.
