#!/usr/bin/env bash
# ──────────────────────────────────────────────
# Bitwarden CLI helpers
# ──────────────────────────────────────────────

# bwu — Unlock (or login + unlock) Bitwarden and export the session key.
# Requires BW_EMAIL to be set in your shell config (e.g. ~/.bashrc).
# Usage: bwu
#   Checks login status first; logs in if needed, then unlocks and
#   exports BW_SESSION so subsequent `bw` commands are authenticated.
bwu() {
  bw login --check 2>/dev/null || bw login --quiet $BW_EMAIL
  export BW_SESSION=$(bw unlock --raw)
}

# bwf — Find vault items matching a search term and display a formatted table.
# Usage: bwf <search>
#   Example: bwf github
bwf() {
  bw list items --search "$1" | jq -r '
    ["NAME", "ID", "URI"],
    ["----", "--", "---"],
    (.[] | [
      .name,
      .id,
      (.login.uris[0].uri // "N/A")
    ])
    | @tsv
  ' | column -t
}

# bwg — Get a field from a vault item and copy it to the clipboard.
# Usage: bwg <item>            — copies the password (default)
#        bwg <field> <item>    — copies the specified field (e.g. username, totp)
#   Example: bwg github
#   Example: bwg username github
bwg() {
  local object="password"
  local term="$1"

  if [ $# -eq 2 ]; then
    object="$1"
    term="$2"
  fi

  bw get "$object" "$term" | xclip -sel clip
  echo "Copied $object to clipboard for: $term"
}
