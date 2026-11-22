#!/bin/bash
set -euo pipefail

install -d -m 0700 /root/.ssh

cat > /etc/ssh/sshd_config.d/10-crytto-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF

chmod 0600 /etc/ssh/sshd_config.d/10-crytto-hardening.conf
sshd -t
systemctl reload ssh || systemctl reload sshd
