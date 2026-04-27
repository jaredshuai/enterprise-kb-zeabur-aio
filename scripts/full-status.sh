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

echo "== Paperless / Caddy / Bridge =="
docker compose --env-file .env.full -f full/compose.paperless.yml -f full/compose.platform.yml ps

echo
if [ -d "${RAGFLOW_DIR}/docker" ]; then
  echo "== RAGFlow =="
  (cd "${RAGFLOW_DIR}/docker" && docker compose ps)
fi

echo
if [ -d "${DIFY_DIR}/docker" ]; then
  echo "== Dify =="
  (cd "${DIFY_DIR}/docker" && docker compose ps)
fi

echo
if command -v curl >/dev/null 2>&1; then
  echo "== Bridge health =="
  curl -fsS "http://localhost:${BRIDGE_DIRECT_PORT:-18080}/health" || true
  echo
fi
