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

docker compose --env-file .env.full -f full/compose.paperless.yml exec -T paperless-webserver \
  python manage.py createsuperuser --noinput \
  --username "${PAPERLESS_ADMIN_USER:-admin}" \
  --email "${PAPERLESS_ADMIN_MAIL:-admin@example.local}" || true

docker compose --env-file .env.full -f full/compose.paperless.yml exec -T paperless-webserver \
  python manage.py changepassword "${PAPERLESS_ADMIN_USER:-admin}" <<EOF
${PAPERLESS_ADMIN_PASSWORD:-change-me-paperless}
${PAPERLESS_ADMIN_PASSWORD:-change-me-paperless}
EOF

echo "Paperless admin ready: ${PAPERLESS_ADMIN_USER:-admin}"
