#!/bin/bash
input=$(cat)

CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
WORKTREE=""
if [ -n "$CWD" ]; then
  GIT_COMMON_DIR=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null)
  GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null)
  if [ -n "$GIT_COMMON_DIR" ] && [ -n "$GIT_DIR" ] && [ "$(cd "$GIT_COMMON_DIR" 2>/dev/null && pwd)" != "$(cd "$GIT_DIR" 2>/dev/null && pwd)" ]; then
    TOPLEVEL=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
    WORKTREE=$(basename "$TOPLEVEL")
  fi
fi
BADGE=""
[ -n "$WORKTREE" ] && BADGE=$(printf '\033[38;5;108m[%s]\033[0m ' "$WORKTREE")

MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
SESSION_ID=$(echo "$input" | jq -r '.session_id // "default"')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Cache the context percentage per-session so other hooks (e.g. the idle
# /compact suggestion) can read the same number the status line just showed.
if [ -n "$CTX_PCT" ]; then
  CACHE_DIR="$HOME/.claude/cache/context_pct"
  mkdir -p "$CACHE_DIR" 2>/dev/null
  echo "$CTX_PCT" > "$CACHE_DIR/$SESSION_ID" 2>/dev/null
fi
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

LIMITS=""
if [ -n "$FIVE_H" ]; then
  FIVE_H_TIME=$(date -r "$FIVE_H_RESET" +%H:%M 2>/dev/null || echo "?")
  LIMITS="5h: $(printf '%.0f' "$FIVE_H")% (resets ${FIVE_H_TIME})"
fi
if [ -n "$WEEK" ]; then
  WEEK_TIME=$(date -r "$WEEK_RESET" "+%a %H:%M" 2>/dev/null || echo "?")
  LIMITS="${LIMITS:+$LIMITS | }7d: $(printf '%.0f' "$WEEK")% (resets ${WEEK_TIME})"
fi

CTX=""
if [ -n "$CTX_PCT" ]; then
  CTX="ctx: $(printf '%.0f' "$CTX_PCT")% of $((CTX_SIZE / 1000))k"
fi

LINE="${BADGE}[$MODEL${EFFORT:+/$EFFORT}]"
[ -n "$CTX" ] && LINE="$LINE | $CTX"
[ -n "$LIMITS" ] && LINE="$LINE | $LIMITS"
echo "$LINE"
