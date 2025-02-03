# Helper Scripts
## Introduction
This repository holds a variety of helper scripts designed to save time and reduce repetitive tasks. These scripts may be useful for automating common workflows, working with systems, or managing configurations.

## Installation
To get started with the scripts, clone the repository:

```bash
git clone https://github.com/your-username/helper-scripts.git
cd helper-scripts
```

## Scripts
### Docker Caddyfile IP Updater
This script dynamically updates the Caddyfile with the current IP addresses of Docker containers connected to a specified Docker network. It works by:

1.  Taking the Docker network name as an argument.
2.  Creating a backup of the Caddyfile to prevent data loss.
3.  Extracting the list of containers in the specified Docker network.
4.  Comparing the current IP addresses of the containers with those in the Caddyfile.
5.  If any IP address changes are detected, it updates the corresponding service's reverse proxy configuration in the Caddyfile.
6.  After updates, the script reloads the Caddy service to apply the changes.

The script also logs all actions and errors, and ensures that the Caddyfile is only updated if there are actual changes. This allows for seamless management of dynamic IP changes in a Docker-based environment.
