#!/bin/bash
# Política mínima de backup (B6): dump lógico do PostgreSQL enviado ao bucket, prefixo diario/.
# Usa a identidade da VM (S5): o token vem do metadata server, sem chave gravada no disco.
# A service account só tem roles/storage.objectCreator: cria objetos novos, mas não lê, lista,
# sobrescreve nem apaga backups. Agendado por crytto-backup.timer.
set -euo pipefail

# shellcheck disable=SC1091
. /etc/crytto/backup.env # BUCKET, DB_NAME, DB_USER

ts="$(date -u +%Y%m%dT%H%M%SZ)"
object="diario/${DB_NAME}-${ts}.sql.gz"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# pg_dump é consistente do ponto de vista do banco (usa um snapshot da transação).
docker exec crytto-db pg_dump -U "$DB_USER" -d "$DB_NAME" --no-owner | gzip -9 >"$tmp"

token="$(curl -sf -H 'Metadata-Flavor: Google' \
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"

curl -sf -X POST \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/gzip' \
  --data-binary "@$tmp" \
  "https://storage.googleapis.com/upload/storage/v1/b/${BUCKET}/o?uploadType=media&name=${object//\//%2F}" >/dev/null

echo "[crytto-backup] gs://${BUCKET}/${object} ($(stat -c %s "$tmp") bytes)"
