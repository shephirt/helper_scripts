#!/usr/bin/env bash

# Exit on errors, undefined vars, failed pipes
set -euo pipefail

##############################################
# === CONFIGURATION (edit before running) ===
##############################################

# Default SSH port for the target system
SSH_PORT="4722"

# Default DEBUG mode (true/false)
DEBUG="false"

##############################################
# === OPTIONAL OVERRIDES VIA CLI ARGS ===
# 1: SSH port
# 2: DEBUG mode
##############################################

SSH_PORT="${1:-$SSH_PORT}"
DEBUG="${2:-$DEBUG}"

##############################################
# === Enable debugging if requested ===
##############################################

[ "$DEBUG" = "true" ] && set -x

echo "[INFO] Loader starting (DEBUG=$DEBUG, SSH_PORT=$SSH_PORT)"

##############################################
# === Ensure curl is installed ===
##############################################

if ! command -v curl >/dev/null 2>&1; then
    echo "[INFO] curl is missing — installing..."
    apt update -y
    apt install -y curl
fi

##############################################
# === Download main script ===
##############################################

SCRIPT_URL="https://raw.githubusercontent.com/shephirt/helper_scripts/refs/heads/main/server/initial_config.sh"

echo "[INFO] Downloading main script..."
curl -fsSL "$SCRIPT_URL" -o /tmp/initial_config.sh
chmod +x /tmp/initial_config.sh

##############################################
# === Execute main script ===
##############################################

echo "[INFO] Executing main script..."
bash /tmp/initial_config.sh "$SSH_PORT"
