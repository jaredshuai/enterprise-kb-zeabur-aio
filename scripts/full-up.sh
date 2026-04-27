#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env.full ]; then
  echo "Missing .env.full. Run scripts/full-init.sh first."
  exit 1
fi
set -a
source .env.full
set +a

# RAGFlow search backends require vm.max_map_count on Linux.
if command -v sysctl >/dev/null 2>&1; then
  current="$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)"
  if [ "${current}" -lt 262144 ]; then
    echo "Warning: vm.max_map_count=${current}. RAGFlow usually requires >=262144."
    echo "Run: echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p"
  fi
fi

echo "Starting Paperless + Caddy + Bridge..."
docker compose --env-file .env.full -f full/compose.paperless.yml -f full/compose.platform.yml up -d --build

if [ -d "${RAGFLOW_DIR}/docker" ]; then
  echo "Starting RAGFlow official compose..."
  (
    cd "${RAGFLOW_DIR}/docker"
    docker compose up -d
  )
else
  echo "RAGFlow directory not initialized. Run scripts/full-init.sh."
fi

if [ -d "${DIFY_DIR}/docker" ]; then
  echo "Starting Dify official compose..."
  (
    cd "${DIFY_DIR}/docker"
    docker compose up -d
  )
else
  echo "Dify directory not initialized. Run scripts/full-init.sh."
fi

echo
cat <<EOF
Full stack startup requested.

Main entries:
- Paperless: http://${PAPERLESS_HOST} or http://localhost:${PAPERLESS_DIRECT_PORT}
- RAGFlow:  http://${RAGFLOW_HOST}
- Dify:     http://${DIFY_HOST}
- Bridge:   http://${BRIDGE_HOST} or http://localhost:${BRIDGE_DIRECT_PORT}/health

EOF
