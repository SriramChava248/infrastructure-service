#!/bin/bash

# Master startup script for Infrastructure Service
# Automatically starts all services and runs setup scripts

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

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
    echo "ERROR: Docker not found. Please ensure Docker Desktop is running."
    exit 1
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [Infrastructure] $1"
}

log "=========================================="
log "Starting Infrastructure Service"
log "=========================================="

# Check if Docker is running
if ! $DOCKER_CMD info > /dev/null 2>&1; then
    log "ERROR: Docker is not running. Please start Docker Desktop."
    exit 1
fi

log "Using Docker: $DOCKER_CMD"

# Navigate to project directory
cd "$PROJECT_DIR"

# Start Docker Compose services
log "Starting Docker Compose services (Couchbase, Zookeeper, Kafka)..."
log "This may take a few minutes on first run as images are downloaded..."
$DOCKER_CMD compose up -d --pull always

if [ $? -ne 0 ]; then
    log "ERROR: Failed to start Docker Compose services"
    log "Try running manually: $DOCKER_CMD compose up -d"
    exit 1
fi

log "Waiting 10 seconds for containers to initialize..."
sleep 10

log "Docker Compose services started"
log "Waiting for services to initialize..."

# Wait for Couchbase to be ready (check if web server is responding)
log "Waiting for Couchbase to be ready..."
MAX_WAIT=180
WAIT_COUNT=0

# Check if Couchbase web server is responding (more reliable than health check status)
while ! $DOCKER_CMD exec couchbase curl -s -f "http://localhost:8091" > /dev/null 2>&1; do
    WAIT_COUNT=$((WAIT_COUNT + 5))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        log "WARNING: Couchbase did not become ready within ${MAX_WAIT} seconds"
        log "Continuing anyway..."
        break
    fi
    log "Waiting for Couchbase to be ready... (${WAIT_COUNT}s/${MAX_WAIT}s)"
    sleep 5
done

if [ $WAIT_COUNT -lt $MAX_WAIT ]; then
    log "Couchbase web server is responding!"
    log "Waiting additional 15 seconds for Couchbase to fully initialize..."
    sleep 15
else
    log "Proceeding with setup (Couchbase may still be initializing)..."
fi

# Run Couchbase setup
log "=========================================="
log "Setting up Couchbase..."
log "=========================================="
"$SCRIPT_DIR/scripts/setup-couchbase.sh"

if [ $? -ne 0 ]; then
    log "ERROR: Couchbase setup failed"
    exit 1
fi

# Wait for Kafka to be healthy
log "Waiting for Kafka to be healthy..."
WAIT_COUNT=0

while [ "$($DOCKER_CMD inspect -f '{{.State.Health.Status}}' kafka 2>/dev/null)" != "healthy" ]; do
    WAIT_COUNT=$((WAIT_COUNT + 5))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        log "WARNING: Kafka did not become healthy within ${MAX_WAIT} seconds"
        log "Continuing anyway..."
        break
    fi
    log "Waiting for Kafka health check... (${WAIT_COUNT}s/${MAX_WAIT}s)"
    sleep 5
done

log "Kafka is ready!"

# Run Kafka setup
log "=========================================="
log "Setting up Kafka topics..."
log "=========================================="
"$SCRIPT_DIR/scripts/setup-kafka-topics.sh"

if [ $? -ne 0 ]; then
    log "ERROR: Kafka setup failed"
    exit 1
fi

log "=========================================="
log "Infrastructure Service Started Successfully!"
log "=========================================="
log ""

# Print service ports in green
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================="
echo -e "Service Access Points:"
echo -e "==========================================${NC}"
echo -e "${GREEN}  📊 Couchbase UI:${NC}     http://localhost:8091"
echo -e "${GREEN}     Username:${NC}         Administrator"
echo -e "${GREEN}     Password:${NC}         password"
echo -e ""
echo -e "${GREEN}  📨 Kafka Broker:${NC}     localhost:9092"
echo -e ""
echo -e "${GREEN}  🖥️  Kafka UI:${NC}        http://localhost:8080"
echo -e ""
echo -e "${GREEN}  🔗 Zookeeper:${NC}        localhost:2181"
echo -e "${GREEN}==========================================${NC}"
echo ""
log "To stop services: $DOCKER_CMD compose down"
log "To view logs: $DOCKER_CMD compose logs -f"
log ""


