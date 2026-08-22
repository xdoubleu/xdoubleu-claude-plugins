# claude-plugins

xdoubleu's personal Claude Code plugin marketplace: generic skills/hooks
that aren't tied to any one project, so they can be installed once and
reused across repos instead of being copy-pasted (and drifting) into each
project's own `.claude/skills/`.

## Install

```
/plugin marketplace add xdoubleu/claude-plugins
/plugin install git-task-flow@claude-plugins
/plugin install session-retro@claude-plugins
/plugin install git-cleanup@claude-plugins
/plugin install github-issue-triage@claude-plugins
/plugin install skill-lifecycle@claude-plugins
/plugin install session-hygiene@claude-plugins
```

Maintain a persistent local clone at `~/github/claude-plugins` for editing
this repo — see `plugins/skill-lifecycle`.

## Plugins

- **git-task-flow** — `task-worktree` (fresh worktree off the default
  branch) and `ship-pr` (rebase, push, open PR, auto-merge decision, watch
  CI to green). The generic halves of any project's own start-task/
  finish-task flow; a project can wrap these with its own project-specific
  steps (tracking issue creation, lint/coverage/build commands, auto-merge
  thresholds).
- **session-retro** — reflects on a session's own tool-call/CI history for
  concrete inefficiencies and ships the smallest fix as its own issue/PR
  when something real turns up.
- **git-cleanup** — automatically removes local worktrees/branches for PRs
  already merged (including squash merges) at the start of every session
  (`hooks/hooks.json`, `SessionStart`), plus an on-demand skill for the same
  cleanup right after a merge.
- **github-issue-triage** — `refine-issue` (single-issue refinement) and
  `issue-triage` (bulk pass: dedup, label, prioritize, split oversized
  issues). Config-driven via `.claude/github-triage.config.json` in the
  consuming repo — see `plugins/github-issue-triage/skills/refine-issue/SKILL.md`
  for the config shape; the skill bootstraps that file interactively on
  first use if it's missing.
- **skill-lifecycle** — `skill-placement-review`: run after creating or
  substantially editing a skill anywhere, to decide project-specific vs.
  marketplace-worthy, and to keep project wrapper skills honest about what
  they delegate to a plugin.
- **session-hygiene** — the status line script (model/effort/context%/rate
  limits/worktree badge) plus the compact-idle hooks: a sound +
  `systemMessage` nudge to `/compact` when idle with high context usage,
  and a hard `UserPromptSubmit` block past a context threshold until you
  do. **Caveat:** a plugin can't register the top-level `statusLine`
  settings key for you — that still needs a one-time manual entry in your
  own `~/.claude/settings.json`:
  ```json
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
  ```
  pointing at a copy of `plugins/session-hygiene/scripts/statusline.sh`
  (kept in sync by your own dotfiles install step). The hooks themselves
  (`hooks/hooks.json`) work automatically once the plugin is installed — no
  manual wiring needed for those.

## Project-specific wrappers

A project that wants extra project-specific behavior on top of these
(e.g. this user's `tools.xdoubleu.com` repo, which layers its own tracking-
issue creation onto `task-worktree`, and its own lint/coverage/build/
auto-merge rules onto `ship-pr`) should keep a thin local skill in its own
`.claude/skills/` that calls into the installed plugin skill by name and
adds only the project-specific parts — not a full copy of the generic
mechanics. Use `skill-lifecycle`'s `skill-placement-review` skill to decide
this each time a skill is created or edited, anywhere.
