import docker
import re
import os
import argparse
from loguru import logger

# Default Paths
DEFAULT_CADDYFILE = "/etc/caddy/Caddyfile"
LOGFILE = "/var/log/caddy_ip_changes.log"

# Initialize Docker client
docker_client = docker.from_env()

# Configure logger
def configure_logger(debug_mode, simulate_mode):
    logger.remove()
    level = "DEBUG" if debug_mode else "INFO"
    logger.add(lambda msg: print(msg, end=""), format="[{time}] [{level}] {message}", level=level)
    if not simulate_mode:
        logger.add(LOGFILE, format="[{time}] [{level}] {message}", level=level, enqueue=True)

# Get containers running in a specified network
def get_containers_in_network(network_name):
    try:
        network = docker_client.networks.get(network_name)
    except docker.errors.NotFound:
        logger.error(f"Network '{network_name}' not found.")
        exit(1)
    except Exception as e:
        logger.error(f"Error accessing Docker: {e}")
        exit(1)
    
    containers = {container.name: container.attrs['NetworkSettings']['Networks'][network_name]['IPAddress']
                  for container in network.containers}
    logger.debug(f"Docker containers in network '{network_name}': {containers}")
    return containers

# Extract reverse proxy lines from Caddyfile
def extract_reverse_proxy(line):
    return re.match(r"\s*reverse_proxy\s+([a-zA-Z0-9._-]+):([0-9]+)", line)

# Extract current proxy targets from Caddyfile
def parse_caddyfile(caddyfile_path):
    if not os.path.isfile(caddyfile_path):
        logger.error(f"Caddyfile not found at {caddyfile_path}")
        exit(1)
    
    caddy_proxies = {}
    with open(caddyfile_path, "r") as f:
        content = f.readlines()
    
    logger.debug(f"Parsing Caddyfile: {caddyfile_path}")
    
    current_service = None
    for line in content:
        host_match = re.match(r"\s*@([a-zA-Z0-9_-]+)\s+host\s+([a-zA-Z0-9._-]+)", line)
        if host_match:
            current_service = host_match.group(1)
        
        proxy_match = extract_reverse_proxy(line)
        if proxy_match and current_service:
            target, port = proxy_match.groups()
            caddy_proxies[current_service] = (target, port)
    
    logger.debug(f"Extracted proxies from Caddyfile: {caddy_proxies}")
    return caddy_proxies

# Update Caddyfile with new IPs
def update_caddyfile(caddyfile_path, caddy_proxies, docker_ips, simulation):
    updated = False
    with open(caddyfile_path, "r") as f:
        content = f.readlines()
    
    new_content = []
    current_service = None
    for line in content:
        host_match = re.match(r"\s*@([a-zA-Z0-9_-]+)\s+host\s+([a-zA-Z0-9._-]+)", line)
        if host_match:
            current_service = host_match.group(1)
        
        if current_service in caddy_proxies and current_service in docker_ips:
            old_target, port = caddy_proxies[current_service]
            if old_target == "localhost":
                new_ip = docker_ips[current_service]
                proxy_match = extract_reverse_proxy(line)
                if proxy_match:
                    updated = True
                    logger.info(f"Updating {current_service}: localhost -> {new_ip}")
                    if not simulation:
                        line = re.sub(r"localhost", new_ip, line)
        
        new_content.append(line)
    
    if updated and not simulation:
        with open(caddyfile_path, "w") as f:
            f.writelines(new_content)
        os.system("systemctl reload caddy.service")
        logger.info(f"Caddyfile updated at {caddyfile_path}")
    elif simulation:
        logger.info("Simulation mode: No changes were made.")
    else:
        logger.info("No updates needed.")

# Main logic
def main():
    parser = argparse.ArgumentParser(description="Update Caddyfile with Docker container IPs.")
    parser.add_argument("network", type=str, help="Docker network name.")
    parser.add_argument("--file", type=str, default=DEFAULT_CADDYFILE, help="Path to the Caddyfile.")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode.")
    parser.add_argument("--simulate", action="store_true", help="Enable simulation mode.")
    args = parser.parse_args()
    
    configure_logger(args.debug, args.simulate)
    caddy_proxies = parse_caddyfile(args.file)
    docker_ips = get_containers_in_network(args.network)
    update_caddyfile(args.file, caddy_proxies, docker_ips, args.simulate)
    
    for service in docker_ips:
        if service not in caddy_proxies:
            logger.debug(f"Warning: Container '{service}' is running but not in Caddyfile.")

if __name__ == "__main__":
    main()
