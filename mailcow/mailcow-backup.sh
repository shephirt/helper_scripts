#!/bin/bash

# Mailcow Backup and Remote Sync Script
# This script backs up mailcow and syncs to a remote destination via rsync

set -e

# ============================================
# CONFIGURATION - Edit these values
# ============================================
BACKUP_LOCATION="/root/mailcow-backup"
REMOTE_USER="u298426-sub1"
REMOTE_HOST="u298426-sub1.your-storagebox.de"
REMOTE_PORT="23"
REMOTE_PATH="mailcow-backups"
SSH_KEY="$HOME/.ssh/mailcow-backup"
LOG_FILE="/var/log/mailcow-backup.log"
# ============================================

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--backup-location)
            BACKUP_LOCATION="$2"
            shift 2
            ;;
        -h|--remote-host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -u|--remote-user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -p|--remote-port)
            REMOTE_PORT="$2"
            shift 2
            ;;
        -d|--remote-path)
            REMOTE_PATH="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -b, --backup-location PATH   Local backup directory (default: /root/mailcow-backup)"
            echo "  -h, --remote-host HOST       Remote backup server hostname/IP"
            echo "  -u, --remote-user USER       Remote SSH user (default: root)"
            echo "  -p, --remote-port PORT       SSH port (default: 23)"
            echo "  -d, --remote-path PATH       Remote destination path"
            echo "  -k, --ssh-key PATH           SSH private key path (default: ~/.ssh/id_rsa)"
            echo "  -l, --log-file PATH          Log file path (default: /var/log/mailcow-backup.log)"
            echo "      --help                   Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 -h backup.example.com -d /backups/mailcow"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Validate required variables
if [ -z "$REMOTE_HOST" ]; then
    log "ERROR: REMOTE_HOST environment variable is not set"
    exit 1
fi

if [ -z "$REMOTE_PATH" ]; then
    log "ERROR: REMOTE_PATH environment variable is not set"
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    log "ERROR: SSH key not found at $SSH_KEY"
    exit 1
fi

log "Starting mailcow backup process"
log "Backup location: $BACKUP_LOCATION"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_LOCATION"

# Run mailcow backup
log "Running mailcow backup..."
export BACKUP_LOCATION
export THREADS=4
if /opt/mailcow-dockerized/helper-scripts/backup_and_restore.sh backup all --delete-days 14; then
    log "Mailcow backup completed successfully"
else
    log "ERROR: Mailcow backup failed"
    exit 1
fi

# Sync to remote destination via rsync
log "Starting rsync to remote destination"
log "Remote: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH (port $REMOTE_PORT)"

if rsync -avz --delete \
    -e "ssh -p $REMOTE_PORT -i $SSH_KEY -o StrictHostKeyChecking=no" \
    "$BACKUP_LOCATION/" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"; then
    log "Remote sync completed successfully"
else
    log "ERROR: Remote sync failed"
    exit 1
fi

log "Backup process completed successfully"
