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

Wait using `gh`'s own watch and a loop that **exits on the outcome** — never a
foreground sleep-then-recheck cycle, which burns a turn per iteration and
tells you nothing the exit status wouldn't have.

Run both waits below in the background (Bash `run_in_background`): each ends by
itself once the result is decided, so you get one completion notification and
spend no turns waiting.

**a. Wait for the checks.** `--watch` polls inside the `gh` process
(`--interval`, 10s by default), so there is no loop to hand-roll — except for
one startup wrinkle: run immediately after PR creation, `gh pr checks
--required` can exit 1 with `no required checks reported` before GitHub has
registered any check runs on the branch yet — a transient gap, not a real
failure, since the workflow triggers off the push and hasn't started
reporting statuses. Wrap the watch in a small retry so that specific message
doesn't get mistaken for "no checks are required on this PR":

```bash
until out=$(gh pr checks --watch --fail-fast --required 2>&1); do
  code=$?
  if [ "$code" = 1 ] && grep -q "no required checks reported" <<<"$out"; then
    sleep 10
    continue
  fi
  echo "$out"
  exit "$code"
done
echo "$out"
```

`--fail-fast` returns on the first failure instead of sitting through the
remaining checks; `--required` ignores checks that don't gate the merge. Exit
status is the result: `0` all passed, `8` still pending, anything else means a
check failed.

**b. Wait for the PR's terminal state.** Green checks are not the end state —
with auto-merge armed the merge itself lands seconds to minutes later, and
mergeability is reported separately from check status. Which condition you wait
for follows from step 2:

```bash
# mode=merged    → auto-merge was armed in step 2; wait for the merge to land
# mode=mergeable → no auto-merge; wait for a conflict-free PR, then hand off
mode=merged
while :; do
  read -r state mergeable mergestate <<<"$(gh pr view \
    --json state,mergeable,mergeStateStatus \
    --jq '"\(.state) \(.mergeable) \(.mergeStateStatus)"' 2>/dev/null)" || true
  echo "state=$state mergeable=$mergeable mergeStateStatus=$mergestate"
  case "$state" in
    MERGED|CLOSED) break ;;
  esac
  if [ "$mergestate" = DIRTY ]; then
    break                       # merge conflicts — needs you, not more waiting
  fi
  case "$mergeable" in
    MERGEABLE|CONFLICTING)      # UNKNOWN means still computing; keep polling
      if [ "$mode" = mergeable ]; then break; fi ;;
  esac
  sleep 20
done
```

Poll no faster than 20s — this is a remote API with rate limits — and let a
failed `gh` call fall through to the next iteration rather than killing the
loop; one flaky request is not an outcome.  Keep the variable named `mergestate` rather
than the obvious `status`: `status` is read-only in zsh, and the loop aborts on
its first line in any shell that happens to be one.

This second wait cannot be replaced by a single `gh pr view`, and the poll in it
is not an oversight: GitHub delivers state changes by webhook, which needs a
public endpoint a local CLI doesn't have; `mergeable` is computed lazily, so the
first query after a push legitimately returns `UNKNOWN` and merely *triggers*
the computation; and there is no `gh pr view --watch` to block on. `gh pr
checks --watch` is a poll too — the win is that its loop, and this one, run
somewhere you aren't spending turns.

A red PR or a non-mergeable state is not "done" — diagnose the actual failure
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
