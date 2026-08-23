---
name: setup-statusline
description: Symlink this machine's installed status line (~/.claude/statusline.sh) to the session-hygiene plugin's own script, and verify settings.json wires it up correctly. Use when the status line is out of date, missing, or was installed as a plain copy instead of a symlink, or when setting up session-hygiene on a new machine.
---

# Setup Status Line

`~/.claude/settings.json`'s `statusLine.command` points at `~/.claude/statusline.sh`, since Claude
Code plugins have no mechanism to declare `statusLine` directly (only hooks/commands/skills). That
means the plugin's own `scripts/statusline.sh` has to be wired in by hand — as a symlink, not a
plain copy, so future changes to the plugin script apply automatically instead of the installed
copy silently drifting out of date.

Run the script bundled with this plugin:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/setup-statusline.sh"
```

If `${CLAUDE_PLUGIN_ROOT}` isn't set in this context, locate `setup-statusline.sh` under this
plugin's installed directory (typically
`~/.claude/plugins/marketplaces/xdoubleu-claude-plugins/plugins/session-hygiene/scripts/setup-statusline.sh`)
and run it directly instead.

## Notes

- Idempotent: safe to re-run any time. It only touches `~/.claude/statusline.sh` when it isn't
  already the correct symlink.
- It never edits `~/.claude/settings.json` itself — if the `statusLine` entry there is missing or
  wrong, it prints the exact JSON to add and expects the user (or an agent, with confirmation) to
  apply it.
