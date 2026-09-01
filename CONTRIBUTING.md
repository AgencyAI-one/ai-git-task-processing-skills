<!--
  AI Git Task Processing Skills contribution guide
  Author: Bohdan Kossak
  X: https://x.com/BohdanDJA
  License: MIT
-->

# Contributing

Thank you for improving AI Git Task Processing Skills.

## Before opening a pull request

1. Keep each skill focused on its existing responsibility: `git-queue` schedules work and `git-job` executes one issue.
2. Apply every skill change to both `.agents/skills` and `.claude/skills`.
3. Preserve safe defaults, one-at-a-time processing, and explicit project scoping.
4. Update documentation when behavior or configuration changes.
5. Run:

   ```bash
   ./scripts/validate.sh
   ```

## Pull requests

Describe the problem, the chosen solution, and the checks you ran. Keep unrelated changes in separate pull requests. If behavior affects GitHub writes or agent permissions, call that out clearly.

By contributing, you agree that your contribution is licensed under the project's MIT License.
