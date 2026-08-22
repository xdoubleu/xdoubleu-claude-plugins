#!/bin/bash
# Notification hook (matcher: idle_prompt, fires ~60s after Claude stops
# responding with no reply). Suggests /compact when context usage (cached
# by statusline.sh from the same context_window.used_percentage the status
# line displays) is >= 30%. Message is TTL-aware: mark-idle-start.sh (a
# Stop hook) records real elapsed idle seconds, compared against this
# deployment's actual Anthropic prompt-cache TTL (1h normal, 5min worst
# case under usage overage) so the wording reflects genuine risk rather
# than a generic nag.
THRESHOLD=30
CACHE_TTL_WORST=300
input=$(cat)

SESSION_ID=$(echo "$input" | jq -r '.session_id // "default"')
CACHE_FILE="$HOME/.claude/cache/context_pct/$SESSION_ID"

[ -f "$CACHE_FILE" ] || exit 0

PCT=$(cat "$CACHE_FILE" 2>/dev/null)
PCT_INT=$(printf '%.0f' "$PCT" 2>/dev/null) || exit 0

if [ "$PCT_INT" -ge "$THRESHOLD" ] 2>/dev/null; then
  IDLE_FILE="$HOME/.claude/cache/idle_since/$SESSION_ID"
  IDLE_SECONDS=""
  if [ -f "$IDLE_FILE" ]; then
    IDLE_SINCE=$(cat "$IDLE_FILE" 2>/dev/null)
    [ -n "$IDLE_SINCE" ] && IDLE_SECONDS=$(($(date +%s) - IDLE_SINCE))
  fi

  if [ -n "$IDLE_SECONDS" ] && [ "$IDLE_SECONDS" -ge "$CACHE_TTL_WORST" ] 2>/dev/null; then
    NOTE="idle $((IDLE_SECONDS / 60))m, already past the 5-minute worst-case prompt-cache TTL"
  else
    NOTE="if you'll be away a while, note the prompt-cache TTL is only 5-60 min"
  fi

  jq -n --arg pct "$PCT_INT" --arg note "$NOTE" \
    '{systemMessage: ("Context usage is " + $pct + "% and the session is idle (" + $note + "). Consider running /compact.")}'
fi
