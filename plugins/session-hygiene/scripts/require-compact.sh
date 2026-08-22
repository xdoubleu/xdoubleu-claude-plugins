#!/bin/bash
# UserPromptSubmit hook. Blocks the prompt from reaching the model when
# cached context usage (written by statusline.sh from the same
# context_window.used_percentage the status line shows) is >= THRESHOLD,
# forcing /compact (or /clear) first.
#
# No time-based staleness fail-open: context % only changes on an actual
# turn, not by elapsed wall-clock time, so a cache file that's merely "old"
# because the session has been idle is still accurate. Treating "old" as
# "unreliable" would disable the block right when it matters most: a large,
# uncompacted context left idle long enough for Anthropic's prompt cache to
# expire pays full reprocessing cost on its *next* request, so this block
# must still be in force whenever that request lands, however long the idle
# gap was. CACHE_MAX_AGE is only a backstop against a truly orphaned file
# (e.g. a session_id reused across days), not a normal-idle escape hatch.
#
# Fails open (allows the prompt) on missing/unreadable/orphaned data, and
# always exempts /compact and /clear so there is never a way to get stuck.
#
# The reason text is TTL-aware: mark-idle-start.sh (a Stop hook) records the
# wall-clock moment the last turn ended, so at prompt-submit time we know
# real elapsed idle seconds and can compare against this deployment's actual
# Anthropic prompt-cache TTL — 1 hour normally, 5 minutes under usage
# overage (undetectable from a hook, so treated as the worst case).
THRESHOLD=30
CACHE_MAX_AGE=86400
CACHE_TTL_WORST=300
CACHE_TTL_NORMAL=3600

input=$(cat)

USER_INPUT=$(echo "$input" | jq -r '.user_input // empty')

case "$USER_INPUT" in
  "/compact"*|"/clear"*) exit 0 ;;
esac

SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
[ -n "$SESSION_ID" ] || exit 0

CACHE_FILE="$HOME/.claude/cache/context_pct/$SESSION_ID"
[ -f "$CACHE_FILE" ] || exit 0

MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null) || exit 0
AGE=$(($(date +%s) - MTIME))
[ "$AGE" -le "$CACHE_MAX_AGE" ] || exit 0

PCT=$(cat "$CACHE_FILE" 2>/dev/null)
PCT_INT=$(printf '%.0f' "$PCT" 2>/dev/null) || exit 0

if [ "$PCT_INT" -ge "$THRESHOLD" ] 2>/dev/null; then
  IDLE_FILE="$HOME/.claude/cache/idle_since/$SESSION_ID"
  IDLE_SECONDS=""
  if [ -f "$IDLE_FILE" ]; then
    IDLE_SINCE=$(cat "$IDLE_FILE" 2>/dev/null)
    if [ -n "$IDLE_SINCE" ]; then
      IDLE_SECONDS=$(($(date +%s) - IDLE_SINCE))
    fi
  fi

  if [ -n "$IDLE_SECONDS" ] && [ "$IDLE_SECONDS" -ge "$CACHE_TTL_NORMAL" ] 2>/dev/null; then
    IDLE_MIN=$((IDLE_SECONDS / 60))
    CACHE_NOTE="Idle ${IDLE_MIN}m, past the 1-hour normal prompt-cache TTL — your cache has expired."
  elif [ -n "$IDLE_SECONDS" ] && [ "$IDLE_SECONDS" -ge "$CACHE_TTL_WORST" ] 2>/dev/null; then
    IDLE_MIN=$((IDLE_SECONDS / 60))
    CACHE_NOTE="Idle ${IDLE_MIN}m, past the 5-minute worst-case prompt-cache TTL — your cache has very likely expired, so this would reprocess the full context."
  else
    CACHE_NOTE="Compacting now keeps any later cache expiry cheap instead of reprocessing the full context."
  fi

  jq -n --arg pct "$PCT_INT" --arg note "$CACHE_NOTE" \
    '{decision: "block", reason: ("Context usage is " + $pct + "% (>= 30%). " + $note + " Run /compact (or /clear) before continuing.")}'
fi
exit 0
