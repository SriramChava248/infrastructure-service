#!/bin/bash

# Script to set up Couchbase bucket and indexes
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

LOG_PREFIX="[Couchbase Setup]"
BUCKET_NAME="customer-data"
COUCHBASE_HOST="localhost"
COUCHBASE_PORT="8091"
USERNAME="Administrator"
PASSWORD="password"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $1"
}

log "Starting Couchbase setup..."

# Wait for Couchbase to be ready
log "Waiting for Couchbase to be accessible..."
MAX_WAIT=120
WAIT_COUNT=0

# Check if Couchbase web server is responding (root endpoint works without auth)
while ! curl -s -f "http://${COUCHBASE_HOST}:${COUCHBASE_PORT}" > /dev/null 2>&1; do
    WAIT_COUNT=$((WAIT_COUNT + 5))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        log "ERROR: Couchbase web server did not become ready within ${MAX_WAIT} seconds"
        exit 1
    fi
    log "Waiting for Couchbase web server... (${WAIT_COUNT}s/${MAX_WAIT}s)"
    sleep 5
done

log "Couchbase web server is ready!"
log "Waiting additional 10 seconds for Couchbase to fully initialize..."
sleep 10

# Initialize cluster if not already initialized
log "Checking if cluster is initialized..."
CLUSTER_INIT_CHECK=$($DOCKER_CMD exec couchbase couchbase-cli bucket-list -c ${COUCHBASE_HOST}:${COUCHBASE_PORT} -u ${USERNAME} -p ${PASSWORD} 2>&1)
if echo "$CLUSTER_INIT_CHECK" | grep -q "not initialized"; then
    log "Initializing Couchbase cluster..."
    $DOCKER_CMD exec couchbase couchbase-cli cluster-init \
        -c ${COUCHBASE_HOST}:${COUCHBASE_PORT} \
        --cluster-username ${USERNAME} \
        --cluster-password ${PASSWORD} \
        --cluster-ramsize 512 \
        --cluster-index-ramsize 256 \
        --cluster-fts-ramsize 256 \
        --services data,index,query,fts
    
    if [ $? -eq 0 ]; then
        log "Cluster initialized successfully"
        log "Waiting 15 seconds for cluster to be ready..."
        sleep 15
    else
        log "ERROR: Failed to initialize cluster"
        exit 1
    fi
else
    log "Cluster already initialized"
fi

# Check if bucket already exists
if $DOCKER_CMD exec couchbase couchbase-cli bucket-list -c ${COUCHBASE_HOST}:${COUCHBASE_PORT} -u ${USERNAME} -p ${PASSWORD} 2>/dev/null | grep -q "^${BUCKET_NAME}$"; then
    log "Bucket '${BUCKET_NAME}' already exists, skipping creation"
else
    log "Creating bucket '${BUCKET_NAME}'..."
    $DOCKER_CMD exec couchbase couchbase-cli bucket-create \
        -c ${COUCHBASE_HOST}:${COUCHBASE_PORT} \
        -u ${USERNAME} \
        -p ${PASSWORD} \
        --bucket ${BUCKET_NAME} \
        --bucket-type couchbase \
        --bucket-ramsize 256
    
    if [ $? -eq 0 ]; then
        log "Bucket '${BUCKET_NAME}' created successfully"
    else
        log "ERROR: Failed to create bucket"
        exit 1
    fi
fi

# Wait a bit for bucket to be fully ready
sleep 5

# Check if primary index already exists
log "Checking for primary index..."
INDEX_EXISTS=$($DOCKER_CMD exec couchbase cbq -u ${USERNAME} -p ${PASSWORD} -e "http://${COUCHBASE_HOST}:${COUCHBASE_PORT}" \
    -s "SELECT COUNT(*) as count FROM system:indexes WHERE keyspace_id = '${BUCKET_NAME}' AND name = '#primary';" 2>/dev/null | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0")

if [ "$INDEX_EXISTS" = "1" ]; then
    log "Primary index already exists, skipping creation"
else
    log "Creating primary index on '${BUCKET_NAME}'..."
    $DOCKER_CMD exec couchbase cbq -u ${USERNAME} -p ${PASSWORD} -e "http://${COUCHBASE_HOST}:${COUCHBASE_PORT}" \
        -s "CREATE PRIMARY INDEX ON \`${BUCKET_NAME}\`;" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log "Primary index created successfully"
    else
        log "WARNING: Index creation may have failed (it might already exist)"
    fi
fi

log "Couchbase setup completed successfully!"
