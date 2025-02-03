#!/bin/bash

# Überprüfen, ob ein Netzwerkparameter übergeben wurde
if [ -z "$1" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Fehler: Kein Docker-Netzwerk angegeben." | tee -a "/var/log/caddy_ip_changes.log"
    echo "Verwendung: $0 <Docker-Netzwerk-Name>"
    exit 1
fi

# Netzwerk als Parameter übergeben
NETWORK=$1

# Pfad zur Caddyfile
CADDYFILE="/etc/caddy/Caddyfile"
LOGFILE="/var/log/caddy_ip_changes.log"

# Backup der Caddyfile erstellen
cp "$CADDYFILE" "$CADDYFILE.bak"
if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Fehler beim Erstellen des Backups der Caddyfile." | tee -a "$LOGFILE"
    exit 1
fi

# Dienste dynamisch aus dem Docker-Netzwerk extrahieren
SERVICES=($(docker network inspect "$NETWORK" -f '{{range .Containers}}{{.Name}} {{end}}'))
if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Fehler beim Abrufen der Container im Netzwerk $NETWORK." | tee -a "$LOGFILE"
    exit 1
fi

# Extrahiere die aktuellen IPs aus der Caddyfile
declare -A CADDY_IPS
while IFS= read -r line; do
    if [[ "$line" =~ @([a-zA-Z0-9_-]+).* ]]; then
        CURRENT_SERVICE=${BASH_REMATCH[1]}
    fi
    if [[ "$line" =~ reverse_proxy[[:space:]]+([0-9\.]+):([0-9]+) ]]; then
        CADDY_IPS[$CURRENT_SERVICE]="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
    fi
done < "$CADDYFILE"

# Neue Caddyfile basierend auf dem aktuellen Stand erstellen
cp "$CADDYFILE.bak" "$CADDYFILE.tmp"
if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Fehler beim Erstellen einer temporären Caddyfile." | tee -a "$LOGFILE"
    exit 1
fi

for SERVICE in "${SERVICES[@]}"; do
    # IP-Adresse des Containers im Netzwerk abrufen
    IP=$(docker network inspect "$NETWORK" -f '{{range .Containers}}{{if eq .Name "'$SERVICE'"}}{{.IPv4Address}}{{end}}{{end}}' | cut -d'/' -f1)
    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Fehler beim Abrufen der IP für Container '$SERVICE'." | tee -a "$LOGFILE"
        continue
    fi
    
    PORT=$(echo "${CADDY_IPS[$SERVICE]}" | cut -d':' -f2)

    if [ -n "$IP" ] && [ -n "$PORT" ]; then
        CURRENT_CADDY_IP=$(echo "${CADDY_IPS[$SERVICE]}" | cut -d':' -f1)
        if [[ "$CURRENT_CADDY_IP" != "$IP" ]]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') IP für $SERVICE hat sich geändert: $CURRENT_CADDY_IP -> $IP" | tee -a "$LOGFILE"
            sed -i -E "/@${SERVICE} host/,/reverse_proxy/s|(reverse_proxy )[0-9\.]+(:[0-9]+)|\1$IP\2|" "$CADDYFILE.tmp"
            if [ $? -ne 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') Fehler beim Aktualisieren der Caddyfile für Service '$SERVICE'." | tee -a "$LOGFILE"
                continue
            fi
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') Warning: Container '$SERVICE' läuft im '$NETWORK'-Netzwerk, ist aber nicht im Caddyfile definiert." | tee -a "$LOGFILE"
    fi
done

# Originale Caddyfile nur ersetzen, wenn Änderungen gemacht wurden
if ! diff -q "$CADDYFILE" "$CADDYFILE.tmp" >/dev/null; then
    mv "$CADDYFILE.tmp" "$CADDYFILE"
    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Fehler beim Ersetzen der Caddyfile." | tee -a "$LOGFILE"
        exit 1
    fi
    systemctl reload caddy.service
    if [ $? -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') Fehler beim Neuladen des Caddy-Dienstes." | tee -a "$LOGFILE"
        exit 1
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') Caddyfile update completed." | tee -a "$LOGFILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') Keine Änderungen an der Caddyfile erforderlich." | tee -a "$LOGFILE"
    rm "$CADDYFILE.tmp"
fi
