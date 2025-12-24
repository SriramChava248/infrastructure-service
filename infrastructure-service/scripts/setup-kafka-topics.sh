#!/bin/bash

# Script to create Kafka topics
# This script is idempotent - safe to run multiple times

set -e  # Exit on error

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

LOG_PREFIX="[Kafka Setup]"
KAFKA_HOST="localhost"
KAFKA_PORT="9092"
BOOTSTRAP_SERVER="${KAFKA_HOST}:${KAFKA_PORT}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $1"
}

log "Starting Kafka topics setup..."

# Wait for Kafka to be ready
log "Waiting for Kafka to be accessible..."
MAX_WAIT=60
WAIT_COUNT=0

while ! $DOCKER_CMD exec kafka kafka-broker-api-versions --bootstrap-server ${BOOTSTRAP_SERVER} > /dev/null 2>&1; do
    WAIT_COUNT=$((WAIT_COUNT + 5))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        log "ERROR: Kafka did not become ready within ${MAX_WAIT} seconds"
        exit 1
    fi
    log "Waiting for Kafka... (${WAIT_COUNT}s/${MAX_WAIT}s)"
    sleep 5
done

log "Kafka is ready!"

# Function to create topic if it doesn't exist
create_topic_if_not_exists() {
    local TOPIC_NAME=$1
    local PARTITIONS=$2
    
    log "Checking topic '${TOPIC_NAME}'..."
    
    # Check if topic exists
    if $DOCKER_CMD exec kafka kafka-topics --list --bootstrap-server ${BOOTSTRAP_SERVER} 2>/dev/null | grep -q "^${TOPIC_NAME}$"; then
        log "Topic '${TOPIC_NAME}' already exists, skipping creation"
    else
        log "Creating topic '${TOPIC_NAME}' with ${PARTITIONS} partitions..."
        $DOCKER_CMD exec kafka kafka-topics --create \
            --bootstrap-server ${BOOTSTRAP_SERVER} \
            --topic ${TOPIC_NAME} \
            --partitions ${PARTITIONS} \
            --replication-factor 1
        
        if [ $? -eq 0 ]; then
            log "Topic '${TOPIC_NAME}' created successfully"
        else
            log "ERROR: Failed to create topic '${TOPIC_NAME}'"
            exit 1
        fi
    fi
}

# Create all topics
create_topic_if_not_exists "order-events" 3
create_topic_if_not_exists "payment-events" 3
create_topic_if_not_exists "delivery-events" 3
create_topic_if_not_exists "notification-events" 3

log "Kafka topics setup completed successfully!"
