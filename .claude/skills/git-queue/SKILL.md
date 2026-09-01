---
name: git-queue
description: Continuously process GitHub Project issues in manual Ready-column order by waiting for the next issue and invoking the git-job workflow one issue at a time. Use only when the user explicitly asks to run the ongoing queue; do not use for a single issue.
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

# Continuous GitHub Task Queue

Operate continuously until the user explicitly interrupts the session.

The queue selects work. The `git-job` skill executes one selected issue.

## Requirements

- Run from the target repository root.
- Require `PROJECT_OWNER` and `PROJECT_NUMBER`.
- Use `READY_STATUS` when set; otherwise the poller defaults to `Ready`.
- Keep all status changes scoped to that configured GitHub Project.

## Queue Loop

Repeat until the user interrupts:

1. Run:

   ```bash
   ./scripts/git-wait-ready-task.sh
   ```

2. Let the command keep polling while no matching issue exists. A long wait is expected and is not a failure.

3. When the command returns a GitHub issue URL, process exactly that issue using the `git-job` skill.

4. Fully finish the current task before looking for another one.

5. As soon as the issue either reaches the configured review status or follows the `git-job` blocked workflow, return to step 1.

## Invariants

- Process one issue at a time; never parallelize queue work.
- Use only the URL returned by `git-wait-ready-task.sh`.
- Preserve the manual top-to-bottom GitHub Project order.
- Do not combine unrelated issues in one implementation.
- Do not stop after a successful or blocked issue and do not ask whether to continue.
- When no matching issue exists, keep waiting rather than ending the session.
- Stop only when the user interrupts the queue or continuing becomes unsafe.
