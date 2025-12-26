#!/bin/bash

# Stop script for Infrastructure Service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Ensure Docker is in PATH (for credential helper)
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# Find docker command
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
elif [ -f "/usr/local/bin/docker" ]; then
    DOCKER_CMD="/usr/local/bin/docker"
elif [ -f "/Applications/Docker.app/Contents/Resources/bin/docker" ]; then
    DOCKER_CMD="/Applications/Docker.app/Contents/Resources/bin/docker"
    export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
else
    echo "ERROR: Docker not found"
    exit 1
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [Infrastructure] $1"
}

log "Stopping Infrastructure Service..."

cd "$PROJECT_DIR"

$DOCKER_CMD compose down

log "Infrastructure Service stopped"
log ""
log "Note: Data is preserved in Docker volumes"
log "To remove data: $DOCKER_CMD compose down -v"


