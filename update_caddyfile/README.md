# Docker Caddyfile IP Updater

This script dynamically updates your Caddyfile by retrieving the current IP addresses of Docker containers in a specified Docker network. It ensures that the Caddyfile reflects the up-to-date IPs and reloads the Caddy service if changes are detected.

## Features
- Automatically updates the Caddyfile with the current IP addresses of Docker containers in a specified network.
- Creates a backup of the original Caddyfile before making changes.
- Logs all actions and errors to `/var/log/caddy_ip_changes.log`.
- Reloads the Caddy service after making changes to the Caddyfile.
- Supports dynamic detection of containers and services, adjusting the reverse proxy configuration.

## Requirements
- Docker: The script interacts with Docker to retrieve the IP addresses of containers.
- Caddy: The script assumes you are using Caddy as your reverse proxy server.
- Bash: The script is written in Bash and should work on most Linux-based systems.

## Installation
1. Clone the repository:
    ```bash
    git clone https://github.com/shephirt/helper_scripts.git
    cd helper_scripts/update_caddyfile
    ```

2. Ensure the script is executable:
    ```bash
    chmod +x update_caddyfile.sh
    ```

3. Optionally, place the script in a directory that's included in your `PATH` for easier execution.

## Usage

### Running the Script
To run the script, specify the Docker network name as an argument:
```bash
./update_caddyfile.sh <Docker-Network-Name>
```
For example:
```bash
./update_caddyfile.sh my_docker_network
```

### Parameters:
- `<Docker-Network-Name>`: The name of the Docker network that your containers are connected to.

### Log Output:
The script logs actions and errors to `/var/log/caddy_ip_changes.log`.

## How It Works
1. The script checks if a network name is provided as an argument.
2. It creates a backup of your Caddyfile before proceeding.
3. The script retrieves the list of containers connected to the specified Docker network.
4. It checks if the IP addresses of the services in the Caddyfile match the current IPs of the containers. If a change is detected, it updates the Caddyfile.
5. If any changes were made, the Caddy service is reloaded to apply the new configuration.
6. If no changes are needed, the script exits without modifying the Caddyfile.

## Backup and Rollback
Before making any changes to the Caddyfile, the script creates a backup with the `.bak` extension. If something goes wrong, you can manually revert to the backup by copying it back over the original Caddyfile:
```bash
cp /etc/caddy/Caddyfile.bak /etc/caddy/Caddyfile
```

## Troubleshooting
- Ensure Docker is running and accessible.
- Check the log file `/var/log/caddy_ip_changes.log` for detailed error messages.
- If Caddy fails to reload, try manually reloading it with `systemctl reload caddy.service`.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
