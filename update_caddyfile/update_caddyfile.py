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
    containers = {container.name: container.attrs['NetworkSettings']['Networks'][network_name]['IPAddress']
                  for container in network.containers}
    print("Docker containers in network:", containers)
    return containers

# Extract current IPs from Caddyfile
def parse_caddyfile():
    caddy_ips = {}
    with open(CADDYFILE, "r") as f:
        content = f.readlines()
    
    print("Caddyfile content:", content)
    
    current_service = None
    for line in content:
        host_match = re.match(r"\s*@([a-zA-Z0-9_-]+)\s+host\s+([a-zA-Z0-9._-]+)", line)
        if host_match:
            current_service = host_match.group(1)
            print(f"Found host: {current_service}")
        
        proxy_match = re.match(r"\s*reverse_proxy\s+([0-9\.]+):([0-9]+)", line)
        if proxy_match and current_service:
            caddy_ips[current_service] = f"{proxy_match.group(1)}:{proxy_match.group(2)}"
            print(f"Found reverse_proxy for {current_service}: {proxy_match.group(1)}:{proxy_match.group(2)}")
    
    print("Parsed Caddyfile IPs:", caddy_ips)
    return caddy_ips

# Port Check
def is_ip_port_reachable(ip, port):
    try:
        result = subprocess.run(["/bin/bash", "-c", f"echo > /dev/tcp/{ip}/{port}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"Port check for {ip}:{port}: {'reachable' if result.returncode == 0 else 'unreachable'}")
        return result.returncode == 0
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
        host_match = re.match(r"\s*@([a-zA-Z0-9_-]+)\s+host\s+([a-zA-Z0-9._-]+)", line)
        if host_match:
            current_service = host_match.group(1)
        
        if current_service and current_service in caddy_ips:
            ip_port = caddy_ips[current_service]
            ip, port = ip_port.split(":")
            if not is_ip_port_reachable(ip, port):
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
            print(f"Warning: Container '{service}' is running in the '{args.network}' network but is not found in the parsed Caddyfile services: {list(caddy_ips.keys())}")

if __name__ == "__main__":
    main()
