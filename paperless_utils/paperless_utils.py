import argparse
import subprocess
from loguru import logger

def run_docker_command(command, raw=False, detach=True):
    """Executes a Docker command, either as a raw command or within the webserver container."""
    try:
        if raw:
            logger.info(f"Executing raw Docker command: {command}")
            subprocess.run(command.split(), check=True, capture_output=True, text=True)
        else:
            base_command = ["docker", "compose", "exec", "-T", "webserver"]
            full_command = base_command + command.split()
            logger.info(f"Executing Docker command: {' '.join(full_command)}")
            subprocess.run(full_command, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {e}")
        if e.stderr:
            logger.error(f"Error output: {e.stderr}")
        raise

def backup():
    """Backup documents from Paperless."""
    logger.info("Starting document backup...")
    try:
        run_docker_command("document_exporter ../export")
        logger.info("Export completed successfully.")
    except Exception as e:
        logger.error(f"Export failed: {e}")

def import_documents():
    """Imports documents into Paperless."""
    logger.info("Starting document import...")
    try:
        run_docker_command("document_importer ../export")
        logger.info("Import completed successfully.")
    except Exception as e:
        logger.error(f"Import failed: {e}")

def training():
    """Triggers the classifier training process."""
    logger.info("Starting classifier training...")
    try:
        run_docker_command("document_create_classifier")
        logger.info("Training completed successfully.")
    except Exception as e:
        logger.error(f"Training failed: {e}")

def update():
    """Updates the Paperless container by pulling the latest version and restarting it."""
    logger.info("Starting update process...")
    try:
        logger.info("Creating backup via export...")
        backup()
        
        logger.info("Stopping container...")
        run_docker_command("docker compose down", raw=True)
        
        logger.info("Pulling new version...")
        run_docker_command("docker compose pull", raw=True)
        
        logger.info("Starting container in foreground mode...")
        run_docker_command("docker compose up", raw=True, detach=False)

        # Prompt user to confirm functionality
        user_input = input("Verify functionality. Enter 'yes' to confirm, 'no' to stop: ")
        if user_input.lower() != 'yes':
            logger.warning("User reported issues. Stopping container...")
            run_docker_command("docker compose down", raw=True)
            logger.info("Update aborted by user.")
            return
        
        logger.info("Restarting container in detached mode...")
        run_docker_command("docker compose up -d", raw=True)
        
        logger.info("Cleaning up unused Docker resources...")
        subprocess.run(["docker", "system", "prune", "-f"], check=True)
        logger.info("Update process completed successfully.")
    except Exception as e:
        logger.error(f"Update process failed: {e}")

def main():
    # Configure logging
    logger.add("paperless.log", rotation="1 MB", level="INFO")
    
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Paperless Docker Helper')
    subparsers = parser.add_subparsers(dest='command')
    
    subparsers.add_parser('backup', help='Export documents')
    subparsers.add_parser('import', help='Import documents')
    subparsers.add_parser('training', help='Train classifier')
    subparsers.add_parser('update', help='Update the Paperless container')
    
    args = parser.parse_args()
    
    try:
        if args.command == 'backup':
            backup()
        elif args.command == 'import':
            import_documents()
        elif args.command == 'training':
            training()
        elif args.command == 'update':
            update()
        else:
            parser.print_help()
    except Exception as e:
        logger.error(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
