#!/usr/bin/env bash
# deploy.sh - Provisiona VM local (VirtualBox) e sobe a aplicação com Ansible + Docker Compose.

set -euo pipefail

if ! command -v vagrant >/dev/null 2>&1; then
  if [ -x "/mnt/c/Program Files/Vagrant/bin/vagrant.exe" ]; then
    VAGRANT_CMD="/mnt/c/Program Files/Vagrant/bin/vagrant.exe"
  else
    echo "ERRO: Vagrant não encontrado no PATH."
    exit 1
  fi
else
  VAGRANT_CMD="vagrant"
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "ERRO: ansible-playbook não encontrado no PATH."
  exit 1
fi

echo "==> Subindo VM"
"$VAGRANT_CMD" up

echo "==> Aplicando provisionamento idempotente"
ansible-playbook -i infra/ansible/inventory.ini infra/ansible/playbook.yml

FRONTEND_PORT=$("$VAGRANT_CMD" port app 80 | awk -F': ' 'END{print $2}')
BACKEND_PORT=$("$VAGRANT_CMD" port app 3001 | awk -F': ' 'END{print $2}')
DB_PORT=$("$VAGRANT_CMD" port db 5432 | awk -F': ' 'END{print $2}')

echo ""
echo "Deploy VM concluído"
echo "Frontend: http://localhost:${FRONTEND_PORT}"
echo "Backend:  http://localhost:${BACKEND_PORT}"
echo "Postgres: localhost:${DB_PORT} (forward para VM de banco:5432)"
