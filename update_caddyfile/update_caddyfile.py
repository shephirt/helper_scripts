import docker
import re
import os
import argparse
import subprocess
from datetime import datetime

# Paths
CADDYFILE = "/etc/caddy/Caddyfile"
LOGFILE = "/var/log/caddy_ip_changes.log"

# Initialize Docker client
docker_client = docker.from_env()

# Get containers running in a specified network
def get_containers_in_network(network_name):
    network = docker_client.networks.get(network_name)
    return {container.name: container.attrs['NetworkSettings']['Networks'][network_name]['IPAddress']
            for container in network.containers}

# Extract current IPs from Caddyfile
def parse_caddyfile():
    caddy_ips = {}
    with open(CADDYFILE, "r") as f:
        content = f.readlines()
    
    current_service = None
    for line in content:
        host_match = re.match(r"@([a-zA-Z0-9_-]+) host", line)
        if host_match:
            current_service = host_match.group(1)
        
        proxy_match = re.match(r"\s*reverse_proxy\s+([0-9\.]+):([0-9]+)", line)
        if proxy_match and current_service:
            caddy_ips[current_service] = f"{proxy_match.group(1)}:{proxy_match.group(2)}"
    
    return caddy_ips

# Ping Test
def is_ip_reachable(ip):
    try:
        subprocess.run(["ping", "-c", "1", "-W", "1", ip], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False

# Update Caddyfile
def update_caddyfile(caddy_ips, docker_ips):
    updated = False
    with open(CADDYFILE, "r") as f:
        content = f.readlines()
    
    new_content = []
    current_service = None
    for line in content:
        host_match = re.match(r"@([a-zA-Z0-9_-]+) host", line)
        if host_match:
            current_service = host_match.group(1)
        
        if current_service and current_service in caddy_ips:
            ip, port = caddy_ips[current_service].split(":")
            if not is_ip_reachable(ip):
                if current_service in docker_ips:
                    new_ip = docker_ips[current_service]
                    proxy_match = re.match(r"(\s*reverse_proxy\s+)([0-9\.]+)(:[0-9]+)", line)
                    if proxy_match:
                        old_ip = proxy_match.group(2)
                        if old_ip != new_ip:
                            updated = True
                            line = f"{proxy_match.group(1)}{new_ip}{proxy_match.group(3)}\n"
                            log_change(current_service, old_ip, new_ip)
        
        new_content.append(line)
    
    if updated:
        with open(CADDYFILE, "w") as f:
            f.writelines(new_content)
        os.system("systemctl reload caddy.service")
        log_message("Caddyfile update completed.")
    else:
        log_message("No changes to Caddyfile were necessary.")

# Log changes
def log_change(service, old_ip, new_ip):
    log_message(f"IP for {service} has changed: {old_ip} -> {new_ip}")

def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOGFILE, "a") as log:
        log.write(f"[{timestamp}] {message}\n")
    print(f"[{timestamp}] {message}")

# Main logic
def main():
    parser = argparse.ArgumentParser(description="Update Caddyfile with Docker container IPs.")
    parser.add_argument("network", type=str, help="The name of the Docker network to inspect.")
    args = parser.parse_args()
    
    caddy_ips = parse_caddyfile()
    docker_ips = get_containers_in_network(args.network)
    update_caddyfile(caddy_ips, docker_ips)
    
    # Warnings for containers not defined in Caddyfile
    for service in docker_ips.keys():
        if service not in caddy_ips:
            log_message(f"Warning: Container '{service}' is running in the '{args.network}' network but is not defined in the Caddyfile.")

if __name__ == "__main__":
    main()
