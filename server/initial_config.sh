#!/usr/bin/env bash

set -euo pipefail
trap 'echo "[ERROR] Fehler in Zeile $LINENO beim Befehl: $BASH_COMMAND"' ERR

PS4='+ $(date "+%H:%M:%S") ${BASH_SOURCE}:${LINENO}: '
DEBUG="${DEBUG:-false}"
[ "$DEBUG" = "true" ] && set -x

SSH_PORT="$1"
if [ -z "$SSH_PORT" ]; then
  echo "Fehler: Kein SSH-Port übergeben."
  exit 1
fi


##############################################
# 1) System aktualisieren & benötigte Pakete
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
# 2) SSH-Port setzen
##############################################

SSHD_CONFIG="/etc/ssh/sshd_config"

# Port nur anpassen, wenn er nicht bereits gesetzt ist
if ! grep -q "^Port ${SSH_PORT}" "$SSHD_CONFIG"; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    sed -i "s/^#Port .*/Port ${SSH_PORT}/" "$SSHD_CONFIG"
    sed -i "s/^Port .*/Port ${SSH_PORT}/" "$SSHD_CONFIG"
fi

systemctl restart ssh


##############################################
# 3) Micro Editor installieren
##############################################

cd /usr/bin
curl https://getmic.ro/r | sudo sh


##############################################
# 4) ZSH + Oh-My-ZSH installieren
##############################################

export RUNZSH=no
export CHSH=no

# Oh My Zsh unattended installieren
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# ZSH als Standardshell aktivieren (unattended)
chsh -s /usr/bin/zsh "$USER"


##############################################
# 5) Docker installieren (offizielles Repo)
##############################################

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list >/dev/null

apt update -y

apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker


##############################################
# 6) Docker: Host Binding auf 127.0.0.1
##############################################

DAEMON_FILE="/etc/docker/daemon.json"
if [ -f "$DAEMON_FILE" ]; then cp "$DAEMON_FILE" "${DAEMON_FILE}.bak"; fi

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
# 7) UFW Firewall konfigurieren
##############################################

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow 80/tcp
ufw allow 443/tcp
ufw allow ${SSH_PORT}/tcp

ufw --force enable


##############################################
# 8) Fail2Ban aktivieren + SSH schützen
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
