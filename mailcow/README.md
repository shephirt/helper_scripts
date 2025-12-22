# Mailcow Backup Script

## Setup

1. **Edit configuration in the script:**
   ```bash
   nano mailcow-backup.sh
   ```
   
   Current defaults in the script:
   ```bash
   BACKUP_LOCATION="/root/mailcow-backup"
   REMOTE_USER="your-remote-user"
   REMOTE_HOST="remote.host.example.com"
   REMOTE_PORT="23"
   REMOTE_PATH="mailcow-backups"
   SSH_KEY="$HOME/.ssh/mailcow-backup"
   LOG_FILE="/var/log/mailcow-backup.log"
   ```

2. **Ensure your SSH key is set up:**
   ```bash
   # Test SSH connection (adjust user/host/port/key as needed)
   ssh -p 23 -i ~/.ssh/mailcow-backup your-remote-user@remote.host.example.com
   ```

**Note about Storage Boxes:** use a relative `REMOTE_PATH` (no leading `/`).

## Usage

### Option 1: Use configured values in script
```bash
./mailcow-backup.sh
```

### Option 2: Override with command-line parameters
```bash
./mailcow-backup.sh -h backup.example.com -d mailcow-backups -p 23
```

### Available parameters:
```
  -b, --backup-location PATH   Local backup directory
  -h, --remote-host HOST       Remote backup server hostname/IP
  -u, --remote-user USER       Remote SSH user
  -p, --remote-port PORT       SSH port
  -d, --remote-path PATH       Remote destination path (relative for Storage Boxes)
  -k, --ssh-key PATH           SSH private key path
  -l, --log-file PATH          Log file path
      --help                   Show help message
```

### Schedule with cron:
```bash
# Edit crontab
crontab -e

# Run daily at 2 AM using configured values:
0 2 * * * /root/mailcow-backup.sh >> /var/log/mailcow-backup.log 2>&1

# Or with parameters:
0 2 * * * /root/mailcow-backup.sh -h remote.host.example.com -d mailcow-backups >> /var/log/mailcow-backup.log 2>&1
```

## What the script does

1. Creates local mailcow backup using the official helper script
2. Deletes backups older than 14 days
3. Syncs the backup directory to remote destination via rsync over SSH
4. Logs all operations to `/var/log/mailcow-backup.log`

## Features

- Configure values directly in the script or via command-line parameters
- Validates required settings before execution
- Comprehensive error handling
- Detailed logging with timestamps
- Uses SSH key authentication on custom port
- Sets `THREADS=4` for the mailcow helper before running the backup
- Automatic cleanup of old backups
