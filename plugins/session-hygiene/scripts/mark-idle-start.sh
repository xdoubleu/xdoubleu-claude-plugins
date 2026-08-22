#!/bin/bash
# Stop hook. Marks the wall-clock moment Claude went idle (a turn just
# ended, user hasn't prompted again yet) per session, so other hooks can
# compute real elapsed idle time against Anthropic's actual prompt-cache
# TTL for this deployment: 1 hour normally, dropping to 5 minutes under
# usage overage. Overage state isn't detectable from a hook, so 300s (the
# worst case) is what other scripts treat as "cache has likely expired."
input=$(cat)
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
[ -n "$SESSION_ID" ] || exit 0

CACHE_DIR="$HOME/.claude/cache/idle_since"
mkdir -p "$CACHE_DIR" 2>/dev/null
date +%s > "$CACHE_DIR/$SESSION_ID" 2>/dev/null
exit 0
