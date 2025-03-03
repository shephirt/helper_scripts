#!/bin/bash

set -e  # Beende das Skript bei Fehlern

log_file="paperless.log"
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

run_docker_command() {
    local command="$1"
    log "Executing: docker compose exec -T webserver $command"
    docker compose exec -T webserver $command
}

backup() {
    log "Starting document backup..."
    run_docker_command "document_exporter ../export"
    log "Export completed successfully."
}

import_documents() {
    log "Starting document import..."
    run_docker_command "document_importer ../export"
    log "Import completed successfully."
}

training() {
    log "Starting classifier training..."
    run_docker_command "document_create_classifier"
    log "Training completed successfully."
}

update() {
    log "Starting update process..."
    backup
    
    log "Stopping container..."
    docker compose down
    
    log "Pulling new version..."
    docker compose pull
    
    log "Starting container in foreground mode..."
    docker compose up

    read -p "Verify functionality. Enter 'yes' to confirm, 'no' to stop: " user_input
    if [[ "$user_input" != "yes" ]]; then
        log "User reported issues. Stopping container..."
        docker compose down
        log "Update aborted by user."
        exit 1
    fi
    
    log "Restarting container in detached mode..."
    docker compose up -d
    
    log "Cleaning up unused Docker resources..."
    docker system prune -f
    log "Update process completed successfully."
}

case "$1" in
    backup)
        backup
        ;;
    import)
        import_documents
        ;;
    training)
        training
        ;;
    update)
        update
        ;;
    *)
        echo "Usage: $0 {backup|import|training|update}"
        exit 1
        ;;
esac
