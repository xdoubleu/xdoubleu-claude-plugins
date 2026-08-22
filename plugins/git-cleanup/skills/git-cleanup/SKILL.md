---
name: git-cleanup
description: Remove local git worktrees and branches for PRs already merged (including squash merges). Use when asked to "clean up branches", "prune merged branches/worktrees", "git cleanup", or before starting fresh work when the repo has accumulated stale worktrees. Also runs automatically as a SessionStart hook in this plugin — this skill is for an on-demand run outside that (e.g. right after a merge, without waiting for the next session).
---

# Git Cleanup

Removes local worktrees and branches whose PR has already merged upstream —
safe to run repeatedly, and skips anything still in active use (the current
branch, the default branch, or a `locked` worktree).

This plugin already runs the same cleanup automatically at the start of
every session (see `hooks/hooks.json`), so most of the time nothing needs
to be done by hand. Use this skill when an on-demand run is wanted sooner
than the next session start — e.g. right after watching a PR's auto-merge
land.

Run the script bundled with this plugin:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/git-cleanup.sh"
```

If `${CLAUDE_PLUGIN_ROOT}` isn't set in this context, locate
`git-cleanup.sh` under this plugin's installed directory (typically
`~/.claude/plugins/marketplaces/claude-plugins/plugins/git-cleanup/scripts/git-cleanup.sh`)
and run it directly instead.

## Notes

- Never removes the default branch's own checkout, the branch currently
  checked out in the session's own worktree, or a worktree marked `locked`
  in `git worktree list --porcelain`.
- A branch only gets deleted once `gh pr list --state merged --search
  "head:<branch>"` finds a merged PR for it — including squash merges,
  since that search matches on the head ref regardless of merge strategy.
- No-ops entirely outside a git repo, so the automatic hook is safe to run
  from any working directory.
