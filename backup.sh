#!/usr/bin/env bash
# bw-backup.sh
# Backs up your Bitwarden vault as an encrypted JSON export.
# Usage: ./bw-backup.sh [output-directory]
#   output-directory defaults to the current directory if not specified.

set -euo pipefail

# ── 1. Output directory ────────────────────────────────────────────────────────
OUTPUT_DIR="${1:-.}"
mkdir -p "$OUTPUT_DIR"

# ── 2. Session handling ────────────────────────────────────────────────────────
if [[ -z "${BW_SESSION:-}" ]]; then
  echo "No BW_SESSION found in environment."
  bwu
fi

# ── 3. Sync vault ──────────────────────────────────────────────────────────────
echo "Syncing vault..."
bw sync --session "$BW_SESSION" > /dev/null

# ── 4. Export encrypted JSON ───────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${OUTPUT_DIR}/bw-backup-${TIMESTAMP}.json"

echo "Exporting encrypted vault to: $BACKUP_FILE"
bw export \
  --format encrypted_json \
  --output "$BACKUP_FILE" \
  --session "$BW_SESSION"

# ── 5. Confirm ─────────────────────────────────────────────────────────────────
if [[ -f "$BACKUP_FILE" ]]; then
  SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
  echo ""
  echo "✅  Backup complete!"
  echo "    File : $BACKUP_FILE"
  echo "    Size : $SIZE"
  echo ""
  echo "⚠️   This file is encrypted with your Bitwarden account password."
  echo "    Keep it somewhere safe — do not store it unprotected in the cloud."
else
  echo "❌  Backup failed — file not found after export."
  exit 1
fi