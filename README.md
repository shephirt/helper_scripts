# Helper Scripts

## Introduction

This repository provides a variety of Bash helper scripts designed to save time and reduce repetitive tasks. The scripts focus on day-to-day server administration, backup routines, Docker management, and service maintenance. Whether you want to quickly bootstrap a Debian server, backup a Mailcow instance, or automate document handling for Paperless-ngx, you'll find useful utilities here.

## Installation

To get started, clone this repository:

```bash
git clone https://github.com/shephirt/helper_scripts.git
cd helper_scripts
```

You can execute the scripts directly or adapt them for your own workflow.

## List of Scripts

### 1. Server Bootstrapping & Configuration

#### [`server/initialize.sh`](server/initialize.sh)
- **Purpose:** Unattended Debian server setup. Updates the system, installs essential packages, sets the SSH port, and applies basic hardening.
- **Usage:**  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/shephirt/helper_scripts/main/server/initialize.sh | bash -s -- -p 2222 -d true
  ```
  Use `-p` to set SSH port and `-d` to enable debugging.

#### [`server/initial_config.sh`](server/initial_config.sh)
- **Purpose:** Similar to `initialize.sh`, performs a Debian server setup with optional CLI overrides for SSH port and debug mode. Installs additional tools like `ncdu`, `nala`, `zoxide`.
- **Usage:**  
  ```bash
  curl -fsSL https://raw.githubusercontent.com/shephirt/helper_scripts/main/server/initial_config.sh | bash -s -- 2222 true
  ```

---

### 2. Mailcow Backup & Sync

#### [`mailcow/mailcow-backup.sh`](mailcow/mailcow-backup.sh)
- **Purpose:** Backs up a mailcow instance and synchronizes the backup to a remote server via rsync over SSH.
- **Config:** Set backup directory, remote host/user/port, destination path, SSH key, and logging.
- **Usage:**  
  ```bash
  ./mailcow/mailcow-backup.sh \
    --remote-host <host> \
    --remote-user <user> \
    --remote-port <port> \
    --remote-path <remote-path>
  ```
  Run with `--help` for comprehensive CLI options.

---

### 3. Paperless-ngx Utility Suite

#### [`paperless_utils/paperless_utils.sh`](paperless_utils/paperless_utils.sh)
- **Purpose:** Manage your Paperless-ngx Docker stack with the following commands:
  - `backup`: Export documents.
  - `import`: Import previously exported documents.
  - `training`: Re-train the document classifier.
  - `update`: Perform a safe update (with backup, safety checks, Docker prune).
- **Usage:**  
  ```bash
  ./paperless_utils/paperless_utils.sh {backup|import|training|update}
  ```

---

### 4. Caddyfile Auto-Updater

- **Purpose:** Dynamically update a Caddyfile with the current IP addresses of Docker containers.
- **Location:** See the [Wiki - Caddyfile Auto-Updater](https://github.com/shephirt/helper_scripts/wiki/2.-Caddyfile-Auto%E2%80%90Updater) for documentation, installation, and usage examples.

---

## Contribution

Contributions are always welcome! Feel free to open issues or PRs for bug fixes, new scripts, or improvements.

## License

MIT License. See [LICENSE](LICENSE).

---

_The above list is based on script files currently detected in the repository. For the most accurate and complete inventory, please review the [source tree](https://github.com/shephirt/helper_scripts/tree/main)._
