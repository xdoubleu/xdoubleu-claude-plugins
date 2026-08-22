---
name: ship-pr
description: Rebase a finished branch on the latest default branch, push, open the GitHub PR, decide on auto-merge, and watch CI to green. Use when a task's code changes are complete and ready to ship, or when asked to "open a PR", "ship this", "finish up".
---

# Ship PR

The closing move of any task, paired with `task-worktree`. Run these steps
in order — don't skip ahead to opening the PR before this repo's own
lint/test/build checks pass, and don't stop at "CI is running" as if that
were done.

## 1. Rebase on the latest default branch, then open the PR yourself

Before opening the PR — not on every later push, see the note below — bring
the branch up to date:

```bash
git fetch origin <default>
git rebase origin/<default>
```

If the rebase reports conflicts, resolve them the normal way (fix the
files, `git add`, `git rebase --continue`) — never `git rebase --abort` and
skip this step. If the rebase actually replayed any upstream commits (check
`git log --oneline origin/<default>..HEAD` before and after — a no-op
rebase changes nothing there), re-run this repo's own lint/test/build
checks before pushing, since the rebase can shift line numbers or interact
with this task's own changes.

Then push and open the PR:

```bash
git push -u origin HEAD --force-with-lease
gh pr view --json number >/dev/null 2>&1 || gh pr create --fill --base <default>
```

`--force-with-lease` (not `-f`) is safe here — this is this task's own
feature branch, not the default branch, and it refuses to overwrite anything
if someone else pushed to the same branch since your last fetch. On a
brand-new branch (nothing pushed yet) it behaves like a normal push.

Only rebase+force-push right before the PR is first created. Once a PR is
open and under review (step 3's fix-and-repush loop), just push normally —
rebasing an already-reviewed branch rewrites commits a reviewer may have
already looked at.

Never push to the default branch directly; never open as `--draft`. If a
tracking issue exists for this work, reference it in the PR body using a
closing keyword (`Fixes #123`, `Closes #123`) so it auto-closes on merge —
a bare `#123` or "Related to #123" leaves it open even after merge.

## 2. Decide on auto-merge

Whether a change is safe to auto-merge is repo-specific — the calling
context (a project's own finish-task-style skill or CLAUDE.md) should supply
the actual criteria (size thresholds, which file patterns count as
"tooling/architectural", etc.). As a generic default absent any other rule:

- **Small, self-contained changes with no architectural/tooling footprint**:
  enable auto-merge right away, in the same breath as creating the PR —
  `gh pr merge --auto --squash` only merges once checks pass, so there's no
  reason to wait for green first:
  ```bash
  gh pr create --fill --base <default> && gh pr merge --auto --squash
  ```
- **Anything larger, or touching shared config/tooling/CI**: do **not**
  enable auto-merge. Open a normal (non-draft) PR and wait for the user's
  own review.

## 3. Monitor CI until green, fixing it yourself if it isn't

```bash
gh pr checks --watch
gh pr view --json mergeable,mergeStateStatus,statusCheckRollup
```

A red PR or non-mergeable state is not "done" — diagnose the actual failure
(don't just re-run blindly) and repeat from step 1. Once green + mergeable,
report the PR URL. Auto-merge was already armed in step 2 for small
self-contained changes; otherwise, stop here and wait for review.

## Notes

- Never skip hooks (`--no-verify`) or bypass signing (`--no-gpg-sign`)
  unless the user has explicitly asked for it. If a hook fails, investigate
  and fix the underlying issue.
- Prefer whatever this repo's own lint/test/build commands are (Makefile
  targets, npm scripts, etc.) over ad-hoc equivalents for every check in
  this skill.
