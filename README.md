# Infrastructure Service

## Overview
This service manages shared infrastructure for all microservices:
- Couchbase Database
- Kafka Message Broker
- Zookeeper (for Kafka)
- Redis Cache (for caching and idempotency)

## Purpose
- Centralized infrastructure management
- Shared by all microservices
- Independent from business services

## Quick Start (Automated)

### Start Everything (Recommended)
```bash
./start.sh
```

This single command will:
1. Start all Docker containers (Couchbase, Zookeeper, Kafka, Redis)
2. Wait for services to be healthy
3. Automatically set up Couchbase (bucket + index)
4. Automatically set up Kafka topics
5. Show status and connection details

### Manual Start (Alternative)
If you prefer manual control:

```bash
# 1. Start containers
docker compose up -d

# 2. Wait for services, then setup
./scripts/setup-couchbase.sh
./scripts/setup-kafka-topics.sh
```

## Stop Services
```bash
./stop.sh
```

## Connection Details

### Couchbase
- URL: `couchbase://localhost`
- Port: 8091 (Web UI), 11210 (API)
- Username: Administrator
- Password: password
- Bucket: `customer-data` (created automatically)

### Kafka
- Bootstrap Servers: `localhost:9092`
- Port: 9092
- Topics: `order-events`, `payment-events`, `delivery-events`, `notification-events` (created automatically)

### Redis
- Host: `localhost`
- Port: `6379`
- Max Memory: `512MB`
- Eviction Policy: `allkeys-lru` (Least Recently Used)
- Persistence: AOF (Append-Only File) enabled
- Purpose:
  - **Caching**: Cache Couchbase documents to reduce database hits
  - **Idempotency**: Store idempotency keys (TTL: 15-30 minutes)

## Usage by Microservices

All microservices connect to this infrastructure:
- Customer Service → connects to localhost:8091 (Couchbase), localhost:9092 (Kafka), localhost:6379 (Redis)
- Restaurant-Order Service → connects to localhost:8091, localhost:9092, localhost:6379
- Payment Service → connects to localhost:8091, localhost:9092, localhost:6379
- etc.

## Logs

View logs:
```bash
docker compose logs -f
```

View specific service logs:
```bash
docker compose logs -f couchbase
docker compose logs -f kafka
docker compose logs -f redis
```

