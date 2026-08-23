#!/bin/bash
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/statusline.sh"
INSTALLED_PATH="$HOME/.claude/statusline.sh"
SETTINGS_PATH="$HOME/.claude/settings.json"

if [ -L "$INSTALLED_PATH" ] && [ "$(readlink "$INSTALLED_PATH")" = "$SCRIPT_PATH" ]; then
  echo "Already up to date: $INSTALLED_PATH -> $SCRIPT_PATH"
else
  rm -f "$INSTALLED_PATH"
  ln -s "$SCRIPT_PATH" "$INSTALLED_PATH"
  echo "Linked $INSTALLED_PATH -> $SCRIPT_PATH"
fi

WANT_JSON='  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }'

if [ -f "$SETTINGS_PATH" ] && jq -e '.statusLine.type == "command" and .statusLine.command == "~/.claude/statusline.sh"' "$SETTINGS_PATH" >/dev/null 2>&1; then
  echo "settings.json already wires up statusLine correctly."
else
  echo
  echo "settings.json ($SETTINGS_PATH) is missing or has a different statusLine entry."
  echo "Add/update this key (ask before applying automatically):"
  echo "$WANT_JSON"
fi
