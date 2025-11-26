#!/usr/bin/env bash

##############################################
# Unattended Debian Server Setup Script
# SSH port and DEBUG mode configurable
# 
# Can be run directly via: 
# curl -fsSL https://raw.githubusercontent.com/shephirt/helper_scripts/refs/heads/main/server/initial_config.sh | bash
# 
# SSH port (default: 22) and DEBUG mode (default: false) can be activated via parameter
# Run script via: 
# curl -fsSL https://raw.githubusercontent.com/shephirt/helper_scripts/refs/heads/main/server/initial_config.sh | bash -s -- {PORT} {DEBUG(true/false)}
# e.g. curl -fsSL https://raw.githubusercontent.com/shephirt/helper_scripts/refs/heads/main/server/initial_config.sh | bash -s -- 2222 true
##############################################

set -euo pipefail
trap 'echo "[ERROR] Failure in line $LINENO during command: $BASH_COMMAND"' ERR
PS4='+ $(date "+%H:%M:%S") ${BASH_SOURCE}:${LINENO}: '

##############################################
# Helper: log an informational line with a timestamp
##############################################
log_info() {
  echo "[INFO] $(date "+%Y-%m-%d %H:%M:%S") - $*"
}

##############################################
# CONFIGURATION (Defaults)
##############################################
SSH_PORT="22"
DEBUG="false"

##############################################
# OPTIONAL CLI OVERRIDES
# 1: SSH_PORT
# 2: DEBUG
##############################################
SSH_PORT="${1:-$SSH_PORT}"
DEBUG="${2:-$DEBUG}"

# Enable debugging if requested
[ "$DEBUG" = "true" ] && set -x

log_info "Starting setup (SSH_PORT=$SSH_PORT, DEBUG=$DEBUG)"

##############################################
# Ensure script is running in Bash
##############################################
if [ -z "$BASH_VERSION" ]; then
    echo "[ERROR] This script must be run with Bash, not sh."
    exit 1
fi

##############################################
# 1) Update system & install required packages
##############################################
log_info "Step 1/8: Updating system and installing required packages"
apt update -y
log_info "Package lists updated."

log_info "Step 1/8: Upgrading installed packages"
apt upgrade -y
log_info "Packages upgraded."

log_info "Step 1/8: Installing essential packages: curl, git, ca-certificates, gnupg, lsb-release, zsh, btop, eza, ufw, fail2ban, stow"
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
  fail2ban \
  stow
log_info "Essential packages installed."

##############################################
# 2) Configure SSH port
##############################################
log_info "Step 2/8: Configuring SSH to listen on port ${SSH_PORT}"
SSHD_CONFIG="/etc/ssh/sshd_config"
if ! grep -q "^Port ${SSH_PORT}" "$SSHD_CONFIG"; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    sed -i "s/^#Port .*/Port ${SSH_PORT}/" "$SSHD_CONFIG"
    sed -i "s/^Port .*/Port ${SSH_PORT}/" "$SSHD_CONFIG"
fi
systemctl restart ssh
log_info "SSH port configured and SSH service restarted."

##############################################
# 3) Install Micro editor
##############################################
log_info "Step 3/8: Installing Micro editor"
cd /usr/bin
curl https://getmic.ro/r | sh
log_info "Micro editor installed."

##############################################
# 4) Install ZSH + Oh-My-ZSH unattended
##############################################
log_info "Step 4/8: Installing ZSH and Oh-My-ZSH (unattended)"
export RUNZSH=no
export CHSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chsh -s /usr/bin/zsh "$USER"
log_info "ZSH and Oh-My-ZSH installed and configured (unattended)."

##############################################
# 5) Install Docker (official repo)
##############################################
log_info "Step 5/8: Installing Docker from official repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list >/dev/null
apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
log_info "Docker installed, enabled, and started."

##############################################
# 6) Configure Docker daemon binding to 127.0.0.1
##############################################
log_info "Step 6/8: Configuring Docker daemon to bind to 127.0.0.1"
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
log_info "Docker daemon configured and restarted."

##############################################
# 7) Configure UFW firewall
##############################################
log_info "Step 7/8: Configuring UFW firewall and open ports 80, 443 and SSH on ${SSH_PORT}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow "${SSH_PORT}/tcp"
ufw --force enable
log_info "UFW firewall configured and enabled."

##############################################
# 8) Enable Fail2Ban + SSH protection
##############################################
log_info "Step 8/8: Enabling Fail2Ban and SSH protection"
mkdir -p /etc/fail2ban
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16
bantime           = 1h
bantime.increment = true
bantime.factor    = 2
bantime.maxtime   = 2w
bantime.rndtime   = 10m
findtime = 1h
maxretry = 5
backend = systemd
banaction = ufw
action = %(action_mwl)s
loglevel = INFO
dbfile = /var/lib/fail2ban/fail2ban.sqlite3
dbpurgeage = 30d

[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 4h
ignoreip = 127.0.0.1/8 ::1

[ufw]
enabled = true
filter = ufw
logpath = /var/log/ufw.log

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
bantime = 4w
findtime = 2w
maxretry = 5
EOF
systemctl enable fail2ban
systemctl restart fail2ban
log_info "Fail2Ban installed and configured."

log_info "Server setup completed successfully!"
