#!/bin/bash

# Check if Network Name has been provided
if [ -z "$1" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Error: No Docker Network provided" | tee -a "/var/log/caddy_ip_changes.log"
    echo "Usage: $0 <Docker-Network-Name>"
    exit 1
fi

# Provide Network name as parameter
NETWORK=$1

# Path to Caddyfile
CADDYFILE="/etc/caddy/Caddyfile"
LOGFILE="/var/log/caddy_ip_changes.log"

# Create a backup of the Caddyfile
cp "$CADDYFILE" "$CADDYFILE.bak"
if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Error while creating backup of Caddyfile" | tee -a "$LOGFILE"
    exit 1
fi

# Dynamically extract services from the Docker network
SERVICES=($(docker network inspect "$NETWORK" -f '{{range .Containers}}{{.Name}} {{end}}'))
if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Error retrieving containers in network $NETWORK." | tee -a "$LOGFILE"
    exit 1
fi

# Extract the current IPs from the Caddyfile
declare -A CADDY_IPS
while IFS= read -r line; do
    if [[ "$line" =~ @([a-zA-Z0-9_-]+).* ]]; then
        CURRENT_SERVICE=${BASH_REMATCH[1]}
    fi
    if [[ "$line" =~ reverse_proxy[[:space:]]+([0-9\.]+):([0-9]+) ]]; then
        CADDY_IPS[$CURRENT_SERVICE]="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
    fi
done < "$CADDYFILE"

# Create a new Caddyfile based on the current state
cp "$CADDYFILE.bak" "$CADDYFILE.tmp"
if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Error creating a temporary Caddyfile." | tee -a "$LOGFILE"
    exit 1
fi

for SERVICE in "${SERVICES[@]}"; do
    # Retrieve the container's IP address in the network
    IP=$(docker network inspect "$NETWORK" -f '{{range .Containers}}{{if eq .Name "'$SERVICE'"}}{{.IPv4Address}}{{end}}{{end}}' | cut -d'/' -f1)
    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Error retrieving IP for container '$SERVICE'." | tee -a "$LOGFILE"
        continue
    fi
    
    PORT=$(echo "${CADDY_IPS[$SERVICE]}" | cut -d':' -f2)

    if [ -n "$IP" ] && [ -n "$PORT" ]; then
        CURRENT_CADDY_IP=$(echo "${CADDY_IPS[$SERVICE]}" | cut -d':' -f1)
        if [[ "$CURRENT_CADDY_IP" != "$IP" ]]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') IP for $SERVICE has changed: $CURRENT_CADDY_IP -> $IP" | tee -a "$LOGFILE"
            sed -i -E "/@${SERVICE} host/,/reverse_proxy/s|(reverse_proxy )[0-9\.]+(:[0-9]+)|\1$IP\2|" "$CADDYFILE.tmp"
            if [ $? -ne 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') Error updating the Caddyfile for service '$SERVICE'." | tee -a "$LOGFILE"
                continue
            fi
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') Warning: Container '$SERVICE' is running in the '$NETWORK' network but is not defined in the Caddyfile." | tee -a "$LOGFILE"
    fi
done

# Only replace the original Caddyfile if changes were made
if ! diff -q "$CADDYFILE" "$CADDYFILE.tmp" >/dev/null; then
    mv "$CADDYFILE.tmp" "$CADDYFILE"
    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Error replacing the Caddyfile." | tee -a "$LOGFILE"
        exit 1
    fi
    systemctl reload caddy.service
    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Error reloading the Caddy service." | tee -a "$LOGFILE"
        exit 1
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') Caddyfile update completed." | tee -a "$LOGFILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') No changes to the Caddyfile required." | tee -a "$LOGFILE"
    rm "$CADDYFILE.tmp"
fi
