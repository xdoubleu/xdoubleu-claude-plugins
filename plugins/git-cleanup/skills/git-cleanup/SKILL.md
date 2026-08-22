---
name: git-cleanup
description: Remove local git worktrees and branches for PRs already merged (including squash merges). Use when asked to "clean up branches", "prune merged branches/worktrees", "git cleanup", or before starting fresh work when the repo has accumulated stale worktrees.
---

# Git Cleanup

Removes local worktrees and branches whose PR has already merged upstream —
safe to run repeatedly, and skips anything still in active use.

Run this directly (works in any git repo with a GitHub remote and `gh`
authenticated):

```bash
default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@')
default=${default:-main}
current=$(git branch --show-current)

git fetch --prune
git worktree prune

git for-each-ref refs/heads --format='%(refname:short)' | while read -r b; do
  [ "$b" = "$default" ] && continue
  [ "$b" = "$current" ] && continue

  merged=$(gh pr list --state merged --search "head:$b" --json number --jq 'length' 2>/dev/null || echo 0)
  [ "$merged" = "0" ] || [ -z "$merged" ] && continue

  wt=$(git worktree list --porcelain | awk -v want="refs/heads/$b" '/^worktree /{w=$2} $0=="branch "want{print w}')
  if [ -n "$wt" ]; then
    if git worktree list --porcelain | grep -A5 "^worktree $wt$" | grep -q "^locked"; then
      echo "skipping $wt (branch $b): worktree locked, likely in active use"
      continue
    fi
    echo "removing worktree $wt (branch $b, merged)"
    git worktree remove "$wt" --force || { echo "skipping branch $b: could not remove worktree"; continue; }
  fi

  echo "deleting branch $b (merged)"
  git branch -D "$b" || echo "skipping branch $b: could not delete"
done
```

## Notes

- Never removes the default branch's own checkout, the branch currently
  checked out in the session's own worktree, or a worktree marked `locked`
  in `git worktree list --porcelain`.
- A branch only gets deleted once `gh pr list --state merged --search
  "head:<branch>"` finds a merged PR for it — including squash merges,
  since that search matches on the head ref regardless of merge strategy.
