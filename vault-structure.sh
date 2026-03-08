#!/usr/bin/env bash
# bw-structure.sh
# Outputs a nested JSON tree of your Bitwarden folders and their items.
# Passwords, TOTP, and other sensitive fields are intentionally excluded.
# Usage: ./bw-structure.sh [output-file]
#   If output-file is specified, JSON is written there. Otherwise stdout.

set -euo pipefail

# ── 1. Session handling ────────────────────────────────────────────────────────
if [[ -z "${BW_SESSION:-}" ]]; then
  echo "No BW_SESSION found in environment." >&2
  bwu
fi

# ── 2. Sync vault ──────────────────────────────────────────────────────────────
echo "Syncing vault..." >&2
bw sync --session "$BW_SESSION" > /dev/null

# ── 3. Fetch folders and items ─────────────────────────────────────────────────
echo "Fetching folders..." >&2
FOLDERS=$(bw list folders --session "$BW_SESSION")

echo "Fetching items..." >&2
ITEMS=$(bw list items --session "$BW_SESSION")

# ── 4. Build nested JSON tree ──────────────────────────────────────────────────
# For each item, we keep only non-sensitive fields:
#   id, name, type, folderId, login.username, login.uris
# Passwords, TOTP, card numbers, etc. are stripped.
echo "Building structure..." >&2

TMP_FOLDERS=$(mktemp)
TMP_ITEMS=$(mktemp)
echo "$FOLDERS" > "$TMP_FOLDERS"
echo "$ITEMS" > "$TMP_ITEMS"

STRUCTURE=$(jq -n \
  --slurpfile folders "$TMP_FOLDERS" \
  --slurpfile items "$TMP_ITEMS" '
  $folders[0] as $folders | $items[0] as $items |

  # Item type labels
  def type_label:
    if . == 1 then "login"
    elif . == 2 then "secure_note"
    elif . == 3 then "card"
    elif . == 4 then "identity"
    else "unknown"
    end;

  # Strip each item to non-sensitive fields only
  def safe_item:
    {
      id: .id,
      name: .name,
      type: (.type | type_label),
      username: (.login.username // null),
      urls: ([ .login.uris[]?.uri ] // [])
    };

  # Build a folder entry with its items
  def folder_with_items(folder_id; folder_name):
    folder_id as $fid |
    folder_name as $fname |
    {
      folder_id: $fid,
      folder_name: $fname,
      item_count: ([ $items[] | select(.folderId == $fid) ] | length),
      items: [
        $items[] |
        select(.folderId == $fid) |
        safe_item
      ]
    };

  {
    # One entry per named folder
    folders: [
      $folders[] |
      folder_with_items(.id; .name)
    ],

    # Unfiled items (folderId is null)
    unfiled: folder_with_items(null; "(no folder)"),

    summary: {
      total_folders: ($folders | length),
      total_items: ($items | length),
      unfiled_items: ([ $items[] | select(.folderId == null) ] | length)
    }
  }
')

rm -f "$TMP_FOLDERS" "$TMP_ITEMS"

# ── 5. Output ──────────────────────────────────────────────────────────────────
OUTPUT_FILE="${1:-}"
if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$STRUCTURE" > "$OUTPUT_FILE"
  echo "✅  Structure written to: $OUTPUT_FILE" >&2
else
  echo "$STRUCTURE"
fi