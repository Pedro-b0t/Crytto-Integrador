#!/bin/bash
# Funções comuns aos startup scripts das VMs. Executado como root a cada boot; tudo é idempotente.
# Log: sudo journalctl -u google-startup-scripts.service
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

APT_OPTS=(-y -o DPkg::Lock::Timeout=600)

log() {
  echo "[crytto-startup] $*"
}

# S1: sem autenticação por senha e sem login direto como root.
# O Ubuntu lê sshd_config.d em ordem alfabética e vale o primeiro valor, por isso o prefixo 00-.
harden_ssh() {
  cat >/etc/ssh/sshd_config.d/00-crytto-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF
  chmod 0644 /etc/ssh/sshd_config.d/00-crytto-hardening.conf
  sshd -t
  systemctl reload ssh
  log "SSH endurecido"
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return
  fi
  log "Instalando Docker Engine e Compose plugin"
  apt-get update "${APT_OPTS[@]:1}"
  apt-get install "${APT_OPTS[@]}" ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  # shellcheck disable=SC1091
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update "${APT_OPTS[@]:1}"
  apt-get install "${APT_OPTS[@]}" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

# Lê um segredo do Secret Manager usando a identidade da VM (S5): o token vem do metadata server,
# sem nenhuma chave gravada no disco. Repete enquanto a permissão IAM ainda se propaga.
get_secret() {
  local project="$1" secret="$2" token value attempt
  for attempt in $(seq 1 30); do
    if token=$(curl -sf -H 'Metadata-Flavor: Google' \
      'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' |
      python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])') &&
      value=$(curl -sf -H "Authorization: Bearer $token" \
        "https://secretmanager.googleapis.com/v1/projects/$project/secrets/$secret/versions/latest:access" |
        python3 -c 'import base64,json,sys; print(base64.b64decode(json.load(sys.stdin)["payload"]["data"]).decode(), end="")'); then
      printf '%s' "$value"
      return 0
    fi
    log "Segredo $secret indisponível (tentativa $attempt/30); aguardando" >&2
    sleep 10
  done
  log "Falha ao ler o segredo $secret" >&2
  return 1
}
