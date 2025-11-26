#!/usr/bin/env bash

# Exit on errors, undefined vars, failed pipes
set -euo pipefail

# Error trap for debugging
trap 'echo "[ERROR] Failure in line $LINENO during command: $BASH_COMMAND"' ERR

# Enable execution trace debugging when DEBUG=true is passed
PS4='+ $(date "+%H:%M:%S") ${BASH_SOURCE}:${LINENO}: '
[ "${DEBUG:-false}" = "true" ] && set -x

# ===== Read SSH port from parameter =====
SSH_PORT="${1:-}"
if [ -z "$SSH_PORT" ]; then
    echo "[ERROR] No SSH port provided."
    exit 1
fi

##############################################
# 1) Update system and install required packages
##############################################

apt update -y
apt upgrade -y

apt install -y \
  curl \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  zsh \
  btop \
  eza \
  ufw \
  fail2ban

##############################################
# 2) Update SSH port (sshd_config)
##############################################

SSHD_CONFIG="/etc/ssh/sshd_config"

if ! grep -q "^Port ${SSH_PORT}" "$SSHD_CONFIG"; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    sed -i "s/^#Port .*/Port ${SSH_PORT}/" "$SSHD_CONFIG"
    sed -i "s/^Port .*/Port ${SSH_PORT}/" "$SSHD_CONFIG"
fi

systemctl restart ssh

##############################################
# 3) Install Micro editor
##############################################

cd /usr/bin
curl https://getmic.ro/r | sh

##############################################
# 4) Install ZSH + Oh-My-ZSH unattended
##############################################

export RUNZSH=no
export CHSH=no

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set ZSH as the default shell for the current user
chsh -s /usr/bin/zsh "$USER"

##############################################
# 5) Install Docker (official source)
##############################################

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian \
$(lsb_release -cs) stable" \
| tee /etc/apt/sources.list.d/docker.list >/dev/null

apt update -y

apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable docker
systemctl start docker

##############################################
# 6) Configure Docker daemon: bind bridge to 127.0.0.1
##############################################

DAEMON_FILE="/etc/docker/daemon.json"
[ -f "$DAEMON_FILE" ] && cp "$DAEMON_FILE" "${DAEMON_FILE}.bak"

cat > "$DAEMON_FILE" <<EOF
{
  "default-network-opts": {
    "bridge": {
      "com.docker.network.bridge.host_binding_ipv4": "127.0.0.1"
    }
  }
}
EOF

systemctl restart docker

##############################################
# 7) Configure UFW firewall
##############################################

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow 80/tcp
ufw allow 443/tcp
ufw allow "${SSH_PORT}/tcp"

ufw --force enable

##############################################
# 8) Enable Fail2Ban with SSH protection and UFW integration
##############################################

mkdir -p /etc/fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ${SSH_PORT}

[ufw]
enabled = true
EOF

systemctl enable fail2ban
systemctl restart fail2ban
