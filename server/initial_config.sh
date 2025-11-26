#!/usr/bin/env bash
set -e

echo "=== [1/7] System aktualisieren & benötigte Pakete installieren ==="

apt update -y
apt upgrade -y

apt install -y \
  curl \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  zsh \
  btop \
  eza \
  ufw


echo "=== [2/7] SSH-Port auf 4722 setzen ==="

SSHD_CONFIG="/etc/ssh/sshd_config"

if ! grep -q "^Port 4722" "$SSHD_CONFIG"; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    sed -i 's/^#Port 22/Port 4722/' "$SSHD_CONFIG"
    sed -i 's/^Port 22/Port 4722/' "$SSHD_CONFIG"
    echo "SSH Port auf 4722 geändert."
else
    echo "SSH Port war bereits auf 4722 gesetzt."
fi

systemctl restart ssh


echo "=== [3/7] Micro Editor installieren ==="

cd /usr/bin
curl https://getmic.ro/r | sudo sh


echo "=== [4/7] ZSH & Oh My Zsh installieren (unattended) ==="

export RUNZSH=no
export CHSH=no

# Oh My Zsh installieren
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# ZSH als Standardshell setzen (unattended)
chsh -s /usr/bin/zsh "$USER"


echo "=== [5/7] Docker installieren (offizielles Docker-Repo) ==="

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update -y

apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker


echo "=== [6/7] Docker Daemon konfigurieren ==="

DAEMON_FILE="/etc/docker/daemon.json"

if [ -f "$DAEMON_FILE" ]; then
    cp "$DAEMON_FILE" "${DAEMON_FILE}.bak"
fi

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


echo "=== [7/7] UFW konfigurieren ==="

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Ports freigeben
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 4722/tcp

ufw --force enable


echo "=============================================="
echo "✔ Setup abgeschlossen!"
echo "✔ SSH Port: 4722"
echo "✔ Docker läuft und bindet nur auf 127.0.0.1"
echo "✔ ZSH ist deine Standardshell"
echo "=============================================="
