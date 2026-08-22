---
name: skill-placement-review
description: Run after creating a new Claude Code skill, or substantially editing an existing one, in ANY project. Decides whether the skill belongs only in that project's .claude/skills/, should move to (or update) the xdoubleu/xdoubleu-claude-plugins marketplace, or is a project-specific wrapper around an existing marketplace plugin that needs to stay in sync with it. Use whenever the user asks "should this be a skill", "add a skill", "should this go in the marketplace", or right after any SKILL.md is written or edited.
---

# Skill Placement Review

A skill's *content* isn't the only thing worth getting right — where it
*lives* matters just as much, because a project-specific skill that's
secretly generic just drifts and gets copy-pasted, and a marketplace plugin
that's secretly project-specific breaks the moment someone else installs
it. Run this review every time a skill is created or meaningfully edited,
anywhere — not just in `xdoubleu/xdoubleu-claude-plugins` itself.

## The marketplace

`xdoubleu/xdoubleu-claude-plugins` (public GitHub repo) is the one place generic,
cross-project Claude Code skills/hooks live. Maintain a persistent local
clone at `~/github/claude-plugins` — clone it there if it isn't present yet
(`gh repo clone xdoubleu/xdoubleu-claude-plugins ~/github/claude-plugins`); don't do
marketplace edits in a throwaway scratch directory, since that work needs
to survive past the current session.

## Step 0 — Check for existing reuse first

Before writing a new skill's content — not just after, when deciding where
it lives — check whether an existing skill from a trusted source already
covers the need, in whole or in part:

- List the plugins/skills already installed from known marketplaces (the
  personal `xdoubleu/xdoubleu-claude-plugins` marketplace and the official
  `claude-plugins-official` marketplace) and skim their descriptions for
  overlap with what's being built.
- **Full overlap** — an existing skill already does this: use/invoke it
  instead of writing a new one. Don't create a duplicate just because it
  wasn't top of mind.
- **Partial overlap** — an existing skill covers part of the need: prefer
  composing (the new skill invokes the existing one for that part) over
  re-implementing it. This is the same delegation pattern already used
  throughout these plugins and their consumers — e.g. `tools.xdoubleu.com`'s
  `start-task` invokes `task-worktree` + `refine-issue` rather than
  reimplementing worktree or issue-creation mechanics.
- **No overlap**: write the new skill for the part with no existing
  coverage, then continue to Step 1 to decide where it belongs.

"Trusted source" means a marketplace already known to the user (already in
`extraKnownMarketplaces`, or the official `claude-plugins-official`
marketplace) — not an arbitrary skill found on the web with no way to
verify its provenance or quality.

## Step 1 — Decide: project-specific, or marketplace-worthy?

Ask of the new/edited skill:

- Does it hardcode a repo name, org/repo slug, project-board number, domain
  name, file path, or build command that only exists in this one project?
- Does it assume this project's own tooling (a specific Makefile target, a
  specific MCP tool only this project's server exposes, a specific CI
  workflow)?
- Would a reasonable person copy-pasting it into an unrelated repo need to
  rewrite more than a config value or two?

**If yes to any of these** — it's project-specific. Leave it in that
project's own `.claude/skills/`. Nothing to do in the marketplace. (It's
still worth checking whether it *could* be split into a thin
project-specific wrapper around a more generic core — see Step 3 — but
don't force a split that isn't there yet.)

**If no to all of these** — it's marketplace-worthy. Prefer designing it to
be config-driven (read a small JSON/YAML file at a conventional path in the
consuming project, falling back to asking the user and writing that file on
first use) over parameterizing every value inline — see
`github-issue-triage`'s `.claude/github-triage.config.json` convention for
the pattern to copy. Continue to Step 2.

## Step 2 — Add or update the plugin in the marketplace

In the `~/github/claude-plugins` checkout:

1. `git pull` first — don't work from a stale clone.
2. New skill with no obvious existing plugin to join: create
   `plugins/<new-plugin-name>/.claude-plugin/plugin.json` +
   `plugins/<new-plugin-name>/skills/<skill-name>/SKILL.md`, and add an
   entry to `.claude-plugin/marketplace.json`'s `plugins` array. Related
   skills (e.g. a single-issue version and a bulk version of the same
   workflow) belong in one plugin with multiple `skills/` entries rather
   than one plugin each — see `github-issue-triage`'s `refine-issue` +
   `issue-triage` pairing.
3. Change to an existing plugin's skill: just edit the file in place.
   `plugin.json` intentionally has no `version` field, so updates are
   picked up automatically from the new commit SHA — no manifest bump
   needed. Only touch `marketplace.json` when adding a brand-new plugin
   entry, not for content-only edits to an existing one.
4. Update `README.md`'s plugin list if a plugin was added or its shape
   changed enough that the one-line description there is now wrong.
5. Commit and push directly to `main` — this repo has no CI/PR requirement
   of its own (unlike `tools.xdoubleu.com`'s start-task/finish-task flow);
   a plain `git commit` + `git push` is the whole flow here.

## Step 3 — Keep the origin project's wrapper thin and correct

If the skill came from a project that should keep using it with
project-specific behavior layered on top (a tracking-issue step, particular
lint/build commands, an auto-merge threshold, etc.):

- Replace the project's local skill with a thin wrapper that names and
  delegates to the marketplace plugin's skill, adding only the
  project-specific parts — never a full copy of the generic mechanics. See
  `tools.xdoubleu.com`'s `start-task`/`finish-task` for the pattern (they
  wrap `task-worktree`/`ship-pr` from `git-task-flow`).
- Make sure the project's own `.claude/settings.json` declares the
  marketplace and the plugin in `extraKnownMarketplaces`/`enabledPlugins`
  so any contributor gets it without manual setup.
- If a config-driven plugin needs a config file in that project (e.g.
  `.claude/github-triage.config.json`), create/update it with that
  project's real values.

If the skill being edited **already** wraps a marketplace plugin, check for
drift both directions:

- Did this edit re-implement something the plugin already does generically?
  If so, move that logic into the plugin (Step 2) instead of duplicating it
  in the wrapper, and shrink the wrapper back down.
- Did this edit reveal the plugin is missing something every consumer would
  want (not just this one project)? If so, that belongs in the plugin
  itself, not as a project-only patch.

## Notes

- This review is about placement, not skill-writing mechanics (structure,
  description tuning, frontmatter) — pair with `skill-creator` for that.
- A skill can legitimately stay project-specific forever — most should.
  Don't force genericization on something that only makes sense for one
  project; a bad abstraction is worse than a duplicated skill.
- `xdoubleu/xdoubleu-claude-plugins` is a personal marketplace, not a public-facing
  product — there's no obligation to keep every plugin polished for
  strangers, just correct and current for the projects that consume it.
