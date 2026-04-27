#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env.full ]; then
  echo "Missing .env.full."
  exit 1
fi
set -a
source .env.full
set +a

TS="$(date +%Y%m%d-%H%M%S)"
DEST="${BACKUP_DIR:-./runtime/backups}/${TS}"
mkdir -p "$DEST"

cp .env.full "$DEST/env.full.copy" || true

if docker ps --format '{{.Names}}' | grep -q '^kb-paperless-postgres$'; then
  echo "Backing up Paperless PostgreSQL..."
  docker exec kb-paperless-postgres pg_dump -U paperless paperless > "$DEST/paperless.sql"
fi

if [ -d "${PAPERLESS_DATA:-./runtime/paperless}" ]; then
  echo "Archiving Paperless data..."
  tar -czf "$DEST/paperless-files.tgz" -C "$(dirname "${PAPERLESS_DATA}")" "$(basename "${PAPERLESS_DATA}")" --exclude='postgres' --exclude='redis'
fi

if [ -d "${KB_ROOT:-./runtime}/bridge" ]; then
  echo "Archiving bridge data..."
  tar -czf "$DEST/bridge.tgz" -C "${KB_ROOT:-./runtime}" bridge
fi

# RAGFlow and Dify are official compose stacks with their own volumes.
# For production-grade backup, use their official migration/backup guidance.
cat > "$DEST/README.txt" <<EOF
Backup created at ${TS}

Included:
- .env.full copy
- Paperless database dump if running
- Paperless bind-mounted files excluding postgres/redis runtime stores
- Bridge state/logs

Not fully included:
- RAGFlow official compose volumes
- Dify official compose volumes

For RAGFlow/Dify, use their official backup or snapshot the whole VM/PVE volume.
EOF

echo "Backup written to: $DEST"
