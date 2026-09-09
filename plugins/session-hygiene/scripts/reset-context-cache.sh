#!/bin/bash
# PreCompact + SessionStart(compact) hook. Fires for both manual /compact and
# auto-compaction (context full), before compaction and again once it completes.
#
# Drops the per-session cached context-usage reading that statusline.sh writes
# and require-compact.sh / suggest-compact.sh act on. Without this, a
# pre-compaction percentage keeps those hooks blocking/nagging every prompt
# after the context has already been compacted away — indefinitely on any
# client that never renders the status line (web, mobile), since nothing else
# ever refreshes the number. require-compact.sh only self-cleared when the user
# literally typed /compact, which auto-compaction never does.
#
# After deletion require-compact.sh fails open (missing file -> exit 0) until
# statusline.sh repopulates it with a real post-compaction number.
input=$(cat)
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
[ -n "$SESSION_ID" ] || exit 0

rm -f "$HOME/.claude/cache/context_pct/$SESSION_ID" \
      "$HOME/.claude/cache/idle_since/$SESSION_ID"
exit 0
