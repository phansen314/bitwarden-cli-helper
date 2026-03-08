#!/usr/bin/env bash
# check-missing-folders.sh
# Finds all Bitwarden vault items that do not have a folder associated with them.
# Usage: ./check-missing-folders.sh

set -euo pipefail

# ── 1. Session handling ────────────────────────────────────────────────────────
if [[ -z "${BW_SESSION:-}" ]]; then
  echo "No BW_SESSION found in environment."
  bwu
fi

# ── 2. Sync vault ──────────────────────────────────────────────────────────────
echo "Syncing vault..."
bw sync --session "$BW_SESSION" > /dev/null

# ── 3. Fetch all items once ────────────────────────────────────────────────────
echo "Fetching items..."
ITEMS=$(bw list items --session "$BW_SESSION")

echo ""
echo "─────────────────────────────────────────────"
echo " Items NOT assigned to a folder"
echo "─────────────────────────────────────────────"
echo "$ITEMS" | jq -r '
  [
    .[] |
    select(
      (.folderId == null) or
      (.folderId == "")
    )
  ] |
  if length == 0 then
    "✅  None found."
  else
    "Found \(length) item(s):",
    (
      .[] |
      "  • \(.name)" +
      (if .login.username then " — username: \(.login.username)" else "" end) +
      " [id: \(.id)]"
    )
  end
'

echo ""