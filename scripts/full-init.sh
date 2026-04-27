#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env.full ]; then
  cp .env.full.example .env.full
  echo "Created .env.full from .env.full.example. Please edit secrets and domains before production use."
fi

set -a
source .env.full
set +a

mkdir -p \
  "${KB_ROOT}" \
  "${PAPERLESS_DATA}/consume" \
  "${PAPERLESS_DATA}/media" \
  "${PAPERLESS_DATA}/data" \
  "${PAPERLESS_DATA}/export" \
  "${PAPERLESS_DATA}/outbox/pending" \
  "${PAPERLESS_DATA}/outbox/done" \
  "${PAPERLESS_DATA}/outbox/failed" \
  "${BACKUP_DIR}" \
  "$(dirname "${RAGFLOW_DIR}")" \
  "$(dirname "${DIFY_DIR}")"

chmod +x paperless/post-consume-to-outbox.sh || true
chmod +x scripts/*.sh || true

if [ ! -d "${RAGFLOW_DIR}/.git" ]; then
  echo "Cloning RAGFlow into ${RAGFLOW_DIR}..."
  git clone https://github.com/infiniflow/ragflow.git "${RAGFLOW_DIR}"
fi
(
  cd "${RAGFLOW_DIR}"
  git fetch --all --tags --prune
  git checkout "${RAGFLOW_GIT_REF:-main}"
)

if [ ! -d "${DIFY_DIR}/.git" ]; then
  echo "Cloning Dify into ${DIFY_DIR}..."
  git clone https://github.com/langgenius/dify.git "${DIFY_DIR}"
fi
(
  cd "${DIFY_DIR}"
  git fetch --all --tags --prune
  git checkout "${DIFY_GIT_REF:-main}"
  if [ -d docker ] && [ ! -f docker/.env ]; then
    cp docker/.env.example docker/.env
    echo "Created Dify docker/.env. Review ${DIFY_DIR}/docker/.env before exposing Dify."
  fi
  if [ -f docker/.env ]; then
    # Avoid fighting RAGFlow for host port 80. Dify compose commonly uses EXPOSE_NGINX_PORT.
    if grep -q '^EXPOSE_NGINX_PORT=' docker/.env; then
      sed -i "s/^EXPOSE_NGINX_PORT=.*/EXPOSE_NGINX_PORT=${DIFY_HTTP_PORT:-8088}/" docker/.env
    else
      printf '\nEXPOSE_NGINX_PORT=%s\n' "${DIFY_HTTP_PORT:-8088}" >> docker/.env
    fi
    if grep -q '^EXPOSE_NGINX_SSL_PORT=' docker/.env; then
      sed -i 's/^EXPOSE_NGINX_SSL_PORT=.*/EXPOSE_NGINX_SSL_PORT=8444/' docker/.env
    fi
  fi
)

echo
cat <<EOF
Full stack workspace initialized.

Next steps:
1. Edit .env.full and set strong secrets.
2. Add local DNS/hosts records if using *.kb.local.
3. Run: scripts/full-up.sh
4. Create Paperless admin: scripts/paperless-create-admin.sh
5. Configure RAGFlow API key and Dataset IDs in .env.full, then restart bridge.

EOF
