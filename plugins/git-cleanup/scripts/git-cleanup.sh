#!/bin/sh
# git cleanup: remove worktrees + local branches for PRs already merged (incl. squash merges).
# Safe to run repeatedly/automatically: never touches the default branch, the
# currently checked-out branch, or a worktree marked "locked".
set -e

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@')
default=${default:-main}
current=$(git branch --show-current)

git fetch --prune --quiet 2>/dev/null || true
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
