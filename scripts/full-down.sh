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

echo "Stopping Paperless + Caddy + Bridge..."
docker compose --env-file .env.full -f full/compose.paperless.yml -f full/compose.platform.yml down

if [ -d "${RAGFLOW_DIR}/docker" ]; then
  echo "Stopping RAGFlow official compose..."
  (cd "${RAGFLOW_DIR}/docker" && docker compose down)
fi

if [ -d "${DIFY_DIR}/docker" ]; then
  echo "Stopping Dify official compose..."
  (cd "${DIFY_DIR}/docker" && docker compose down)
fi
