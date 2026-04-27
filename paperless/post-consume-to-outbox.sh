#!/usr/bin/env bash
set -euo pipefail

OUTBOX="/usr/src/paperless/outbox"
mkdir -p "$OUTBOX/pending" "$OUTBOX/done" "$OUTBOX/failed"

DOC_ID="${DOCUMENT_ID:-unknown}"
FILE_NAME="${DOCUMENT_FILE_NAME:-document}"
ORIGINAL_NAME="${DOCUMENT_ORIGINAL_FILENAME:-$FILE_NAME}"
SAFE_NAME="$(echo "$FILE_NAME" | tr '/ ' '__')"
DEST_FILE="$OUTBOX/pending/${DOC_ID}-${SAFE_NAME}"
META_FILE="$OUTBOX/pending/${DOC_ID}.json"

SOURCE_FILE="${DOCUMENT_ARCHIVE_PATH:-}"
if [ -z "$SOURCE_FILE" ] || [ ! -f "$SOURCE_FILE" ]; then
  SOURCE_FILE="${DOCUMENT_SOURCE_PATH:-}"
fi

if [ -n "$SOURCE_FILE" ] && [ -f "$SOURCE_FILE" ]; then
  cp "$SOURCE_FILE" "$DEST_FILE"
fi

cat > "$META_FILE" <<EOF
{
  "paperless_id": "${DOCUMENT_ID:-}",
  "file_name": "${FILE_NAME}",
  "original_filename": "${ORIGINAL_NAME}",
  "document_type": "${DOCUMENT_TYPE:-}",
  "created": "${DOCUMENT_CREATED:-}",
  "added": "${DOCUMENT_ADDED:-}",
  "correspondent": "${DOCUMENT_CORRESPONDENT:-}",
  "tags": "${DOCUMENT_TAGS:-}",
  "download_url": "${DOCUMENT_DOWNLOAD_URL:-}",
  "source_file": "${DEST_FILE}",
  "status": "pending"
}
EOF

echo "Exported Paperless document ${DOC_ID} to bridge outbox."
