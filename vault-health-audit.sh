#!/usr/bin/env bash
# vault-health-audit.sh — Read-only vault health audit
# Checks: missing passwords, short passwords, missing usernames, missing URLs, no folder.
# No passwords are printed — only metadata and password length for [SHORT] items.

set -euo pipefail

SHORT_PW_THRESHOLD=12

# ── Prerequisites ─────────────────────────────────────────────────────────────
if [[ -z "$BW_SESSION" ]]; then
  echo "Error: BW_SESSION is not set. Run bwu first." >&2
  exit 1
fi
for cmd in bw jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' not found on PATH." >&2
    exit 1
  fi
done

# ── Fetch data (one API call each) ────────────────────────────────────────────
echo "Fetching vault data..."
ITEMS=$(bw list items --session "$BW_SESSION")
FOLDERS=$(bw list folders --session "$BW_SESSION")

if [[ -z "$ITEMS" || "$ITEMS" == "null" || "$ITEMS" == "[]" ]]; then
  echo "Error: Failed to fetch vault items. Is your session valid?" >&2
  exit 1
fi

FOLDER_MAP=$(echo "$FOLDERS" | jq '[.[] | select(.id != null)] | map({(.id): .name}) | add // {}')
TOTAL=$(echo "$ITEMS" | jq '[.[] | select(.type == 1)] | length')

echo ""
echo "Vault Health Audit — $TOTAL login items scanned"
echo ""

# ── jq helpers (reused inline) ────────────────────────────────────────────────
# folder_name: resolves folderId to a display name
# user_field:  returns username or "(no username)"
# sort_key:    sorts unassigned items last (alphabetically by folder otherwise)
jq_folder='if .folderId == null then "(no folder)" else ($folderMap[.folderId] // "(no folder)") end'
jq_user='if (.login.username // "") == "" then "(no username)" else .login.username end'
jq_sort='if .folderId == null then "zzz" else ($folderMap[.folderId] // "zzz") end'

# ── Check: no password ────────────────────────────────────────────────────────
NO_PW_LINES=$(echo "$ITEMS" | jq -r \
  --argjson folderMap "$FOLDER_MAP" \
  "[ .[] | select(.type == 1 and (.login.password == null or .login.password == \"\")) ]
   | sort_by($jq_sort)
   | .[]
   | [ \"NO-PW\", ($jq_folder), (.name // \"(unnamed)\"), ($jq_user) ]
   | @tsv")

# ── Check: short password (has a pw but < threshold) ─────────────────────────
SHORT_LINES=$(echo "$ITEMS" | jq -r \
  --argjson folderMap "$FOLDER_MAP" \
  --argjson threshold "$SHORT_PW_THRESHOLD" \
  "[ .[] | select(
       .type == 1
       and (.login.password != null and .login.password != \"\")
       and (.login.password | length) < \$threshold
     ) ]
   | sort_by($jq_sort)
   | .[]
   | [ \"SHORT\", ($jq_folder), (.name // \"(unnamed)\"), ($jq_user), (.login.password | length | tostring) ]
   | @tsv")

# ── Check: no username ────────────────────────────────────────────────────────
NO_USER_LINES=$(echo "$ITEMS" | jq -r \
  --argjson folderMap "$FOLDER_MAP" \
  "[ .[] | select(.type == 1 and (.login.username == null or .login.username == \"\")) ]
   | sort_by($jq_sort)
   | .[]
   | [ \"NO-USER\", ($jq_folder), (.name // \"(unnamed)\"), \"(no username)\" ]
   | @tsv")

# ── Check: no URI ─────────────────────────────────────────────────────────────
NO_URI_LINES=$(echo "$ITEMS" | jq -r \
  --argjson folderMap "$FOLDER_MAP" \
  "[ .[] | select(.type == 1 and (.login.uris == null or (.login.uris | length) == 0)) ]
   | sort_by($jq_sort)
   | .[]
   | [ \"NO-URI\", ($jq_folder), (.name // \"(unnamed)\"), ($jq_user) ]
   | @tsv")

# ── Check: no folder ─────────────────────────────────────────────────────────
NO_FOLDER_LINES=$(echo "$ITEMS" | jq -r \
  --argjson folderMap "$FOLDER_MAP" \
  "[ .[] | select(.type == 1 and .folderId == null) ]
   | sort_by(.name)
   | .[]
   | [ \"NO-FOLDER\", \"(no folder)\", (.name // \"(unnamed)\"), ($jq_user) ]
   | @tsv")

# ── Display helpers ───────────────────────────────────────────────────────────
count_tsv_lines() {
  local lines="$1"
  if [[ -z "$lines" ]]; then
    echo 0
  else
    echo "$lines" | wc -l | tr -d ' '
  fi
}

print_standard() {
  local lines="$1"
  [[ -z "$lines" ]] && return
  while IFS=$'\t' read -r flag folder name user; do
    printf "%-13s %-22s %s — %s\n" "[$flag]" "$folder" "$name" "$user"
  done <<< "$lines"
}

print_short() {
  local lines="$1"
  [[ -z "$lines" ]] && return
  while IFS=$'\t' read -r flag folder name user pw_len; do
    printf "%-13s %-22s %s — %s  [%s chars]\n" "[$flag]" "$folder" "$name" "$user" "$pw_len"
  done <<< "$lines"
}

# ── Display sections ──────────────────────────────────────────────────────────
NO_PW_COUNT=$(count_tsv_lines "$NO_PW_LINES")
SHORT_COUNT=$(count_tsv_lines "$SHORT_LINES")
NO_USER_COUNT=$(count_tsv_lines "$NO_USER_LINES")
NO_URI_COUNT=$(count_tsv_lines "$NO_URI_LINES")
NO_FOLDER_COUNT=$(count_tsv_lines "$NO_FOLDER_LINES")

print_standard "$NO_PW_LINES";     [[ "$NO_PW_COUNT"     -gt 0 ]] && echo ""
print_short    "$SHORT_LINES";     [[ "$SHORT_COUNT"      -gt 0 ]] && echo ""
print_standard "$NO_USER_LINES";   [[ "$NO_USER_COUNT"    -gt 0 ]] && echo ""
print_standard "$NO_URI_LINES";    [[ "$NO_URI_COUNT"     -gt 0 ]] && echo ""
print_standard "$NO_FOLDER_LINES"; [[ "$NO_FOLDER_COUNT"  -gt 0 ]] && echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
SEP="──────────────────────────────────────────"
echo "$SEP"
printf " %-12s %4s  → %s\n" "NO-PW:"     "$NO_PW_COUNT"     "add/rotate password"
printf " %-12s %4s  → %s\n" "SHORT:"     "$SHORT_COUNT"     "rotate to stronger password (< ${SHORT_PW_THRESHOLD} chars)"
printf " %-12s %4s  → %s\n" "NO-USER:"   "$NO_USER_COUNT"   "add username or delete if stale"
printf " %-12s %4s  → %s\n" "NO-URI:"    "$NO_URI_COUNT"    "add URL or delete if stale"
printf " %-12s %4s  → %s\n" "NO-FOLDER:" "$NO_FOLDER_COUNT" "assign to a folder"
echo "$SEP"
