import docker
import re
import os
import argparse
from loguru import logger

# Paths
CADDYFILE = "/etc/caddy/Caddyfile"
LOGFILE = "/var/log/caddy_ip_changes.log"

# Initialize Docker client
docker_client = docker.from_env()

# Configure logger
def configure_logger(debug_mode, simulate_mode):
    logger.remove()
    level = "DEBUG" if debug_mode else "INFO"
    if simulate_mode:
        logger.add(lambda msg: print(msg, end=""), format="[{time}] [{level}] {message}", level=level)
    else:
        logger.add(LOGFILE, format="[{time}] [{level}] {message}", level=level, enqueue=True)

# Get containers running in a specified network
def get_containers_in_network(network_name):
    network = docker_client.networks.get(network_name)
    containers = {container.name: container.attrs['NetworkSettings']['Networks'][network_name]['IPAddress']
                  for container in network.containers}
    logger.debug(f"Docker containers in network: {containers}")
    return containers

# Extract current proxy targets from Caddyfile
def parse_caddyfile():
    caddy_proxies = {}
    with open(CADDYFILE, "r") as f:
        content = f.readlines()
    
    logger.debug(f"Caddyfile content: {content}")
    
    current_service = None
    for line in content:
        host_match = re.match(r"\s*@([a-zA-Z0-9_-]+)\s+host\s+([a-zA-Z0-9._-]+)", line)
        if host_match:
            current_service = host_match.group(1)
            logger.debug(f"Found host: {current_service}")
        
        proxy_match = re.match(r"\s*reverse_proxy\s+([a-zA-Z0-9._-]+):([0-9]+)", line)
        if proxy_match and current_service:
            target = proxy_match.group(1)
            port = proxy_match.group(2)
            caddy_proxies[current_service] = (target, port)
            logger.debug(f"Found reverse_proxy for {current_service}: {target}:{port}")
    
    logger.debug(f"Parsed Caddyfile proxies: {caddy_proxies}")
    return caddy_proxies

# Update Caddyfile with new IPs
def update_caddyfile(caddy_proxies, docker_ips, simulation):
    updated = False
    with open(CADDYFILE, "r") as f:
        content = f.readlines()
    
    new_content = []
    current_service = None
    for line in content:
        host_match = re.match(r"\s*@([a-zA-Z0-9_-]+)\s+host\s+([a-zA-Z0-9._-]+)", line)
        if host_match:
            current_service = host_match.group(1)
        
        if current_service and current_service in caddy_proxies:
            old_target, port = caddy_proxies[current_service]
            if old_target == "localhost" and current_service in docker_ips:
                new_ip = docker_ips[current_service]
                proxy_match = re.match(r"(\s*reverse_proxy\s+)([a-zA-Z0-9._-]+)(:[0-9]+)", line)
                if proxy_match:
                    if old_target != new_ip:
                        updated = True
                        logger.info(f"Updating {current_service}: localhost -> {new_ip}")
                        if not simulation:
                            line = f"{proxy_match.group(1)}{new_ip}{proxy_match.group(3)}\n"
        
        new_content.append(line)
    
    if updated and not simulation:
        with open(CADDYFILE, "w") as f:
            f.writelines(new_content)
        os.system("systemctl reload caddy.service")
        logger.info("Caddyfile update completed.")
    elif simulation:
        logger.info("Simulation mode enabled. No changes were made.")
    else:
        logger.info("No changes to Caddyfile were necessary.")

# Main logic
def main():
    parser = argparse.ArgumentParser(description="Update Caddyfile with Docker container IPs.")
    parser.add_argument("network", type=str, help="The name of the Docker network to inspect.")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode.")
    parser.add_argument("--simulate", action="store_true", help="Enable simulation mode (no changes will be made).")
    args = parser.parse_args()
    
    configure_logger(args.debug, args.simulate)
    
    caddy_proxies = parse_caddyfile()
    docker_ips = get_containers_in_network(args.network)
    update_caddyfile(caddy_proxies, docker_ips, args.simulate)
    
    # Warnings for containers not defined in Caddyfile
    for service in docker_ips.keys():
        if service not in caddy_proxies:
            logger.debug(f"Warning: Container '{service}' is running in the '{args.network}' network but is not defined in the Caddyfile.")

if __name__ == "__main__":
    main()
