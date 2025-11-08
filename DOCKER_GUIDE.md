# Metron Docker Deployment Guide

Complete guide for running modernized Apache Metron using Docker and Docker Compose.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Services](#services)
7. [Development Setup](#development-setup)
8. [Troubleshooting](#troubleshooting)
9. [Production Deployment](#production-deployment)

---

## Quick Start

Get Metron running in under 5 minutes:

```bash
# Clone repository
git clone https://github.com/apache/metron.git
cd metron

# Start all services (requires 16GB RAM, 8 CPUs)
docker-compose up -d

# Wait for services to be healthy (2-3 minutes)
docker-compose ps

# Access UIs
open http://localhost:4200      # Metron Alerts UI
open http://localhost:4201      # Metron Config UI
open http://localhost:5601      # Kibana
open http://localhost:8088      # Superset
open http://localhost:8089      # Airflow
open http://localhost:3000      # Grafana
open http://localhost:8501      # Streamlit Threat Hunting
```

**Default Credentials:**
- Superset: admin/admin
- Airflow: admin/admin
- Grafana: admin/admin
- Neo4j: neo4j/metron123

---

## Prerequisites

### System Requirements

**Minimum:**
- Docker Engine 24.0+
- Docker Compose 2.20+
- 16 GB RAM
- 4 CPU cores
- 50 GB disk space

**Recommended:**
- Docker Engine 24.0+
- Docker Compose 2.20+
- 32 GB RAM
- 8 CPU cores
- 100 GB disk space (SSD preferred)

### Install Docker

**macOS:**
```bash
# Install Docker Desktop
brew install --cask docker
```

**Ubuntu/Debian:**
```bash
# Install Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

**Verify Installation:**
```bash
docker --version
docker-compose --version
```

---

## Architecture Overview

### Service Stack

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer (Ports)                       │
│  Alerts UI (4200) | Config UI (4201) | Kibana (5601)       │
│  Superset (8088) | Streamlit (8501) | Grafana (3000)       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    API Layer (Port)                         │
│               Metron REST API (8080)                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Processing Layer (Ports)                   │
│  Flink JobManager (8082) | Flink TaskManagers              │
│  Airflow (8089) | MLflow (5000)                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Data Layer (Ports)                        │
│  Kafka (9092) | Elasticsearch (9200) | Cassandra (9042)    │
│  Neo4j (7474, 7687) | PostgreSQL (5432)                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 Monitoring (Ports)                          │
│     Prometheus (9090) | Grafana (3000)                     │
└─────────────────────────────────────────────────────────────┘
```

### Volumes

Persistent data stored in Docker volumes:
- `kafka-data`: Kafka message storage
- `cassandra-data`: Cassandra database
- `elasticsearch-data`: Elasticsearch indices
- `neo4j-data`: Neo4j graph database
- `flink-checkpoints`: Flink state checkpoints
- `airflow-logs`: Airflow execution logs
- `mlflow-artifacts`: ML model artifacts

---

## Installation

### 1. Full Production Stack

Deploy all Metron components:

```bash
# Start all services
docker-compose up -d

# Follow logs
docker-compose logs -f

# Check service health
docker-compose ps

# Expected output: all services showing "healthy" or "running"
```

### 2. Development Stack

Lightweight setup for development:

```bash
# Start minimal services
docker-compose -f docker-compose-dev.yml up -d

# Services included:
# - Kafka, ZooKeeper
# - Cassandra
# - Elasticsearch + Kibana
# - Flink (JobManager + TaskManager)
# - Kafka UI (management interface)
# - ElasticHQ (Elasticsearch management)
```

### 3. Selective Services

Start only specific services:

```bash
# Core data platform only
docker-compose up -d kafka cassandra elasticsearch

# Add Flink processing
docker-compose up -d flink-jobmanager flink-taskmanager

# Add UIs
docker-compose up -d metron-alerts-ui kibana superset
```

---

## Configuration

### Environment Variables

Create `.env` file in the project root:

```bash
# Copy example
cp .env.example .env

# Edit configuration
nano .env
```

**Example `.env` file:**

```bash
# Kafka Configuration
KAFKA_HEAP_OPTS=-Xmx2g -Xms2g

# Elasticsearch Configuration
ES_JAVA_OPTS=-Xms4g -Xmx4g

# Cassandra Configuration
MAX_HEAP_SIZE=2G
HEAP_NEWSIZE=400M

# Metron REST API
METRON_REST_PORT=8080
SPRING_PROFILES_ACTIVE=docker

# Security
SUPERSET_SECRET_KEY=change-me-in-production
AIRFLOW_FERNET_KEY=change-me-in-production

# Monitoring
GRAFANA_ADMIN_PASSWORD=admin
```

### Resource Limits

Adjust resource limits in `docker-compose.yml`:

```yaml
services:
  elasticsearch:
    deploy:
      resources:
        limits:
          memory: 8g
          cpus: '4'
        reservations:
          memory: 4g
          cpus: '2'
```

---

## Services

### Kafka (Message Streaming)

**Ports:**
- 9092: Kafka broker (internal)
- 9093: Kafka broker (external)
- 2181: ZooKeeper

**Management:**
```bash
# List topics
docker exec -it metron-kafka kafka-topics --list --bootstrap-server localhost:9092

# Create topic
docker exec -it metron-kafka kafka-topics --create --topic test --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092

# Produce messages
docker exec -it metron-kafka kafka-console-producer --broker-list localhost:9092 --topic test

# Consume messages
docker exec -it metron-kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic test --from-beginning
```

### Cassandra (Storage)

**Port:** 9042

**Management:**
```bash
# Access CQL shell
docker exec -it metron-cassandra cqlsh

# View keyspaces
docker exec -it metron-cassandra cqlsh -e "DESCRIBE KEYSPACES"

# Query threat intel
docker exec -it metron-cassandra cqlsh -e "SELECT * FROM metron.threat_intel LIMIT 10"

# Check cluster status
docker exec -it metron-cassandra nodetool status
```

### Elasticsearch (Search)

**Ports:**
- 9200: REST API
- 9300: Transport

**Management:**
```bash
# Check cluster health
curl http://localhost:9200/_cluster/health?pretty

# List indices
curl http://localhost:9200/_cat/indices?v

# Search alerts
curl -XGET 'http://localhost:9200/metron-*/_search?pretty' -H 'Content-Type: application/json' -d'
{
  "query": {
    "match_all": {}
  },
  "size": 10
}'

# Check disk usage
curl http://localhost:9200/_cat/allocation?v
```

### Flink (Stream Processing)

**Port:** 8082 (Web UI)

**Management:**
```bash
# Submit parsing job
docker exec -it metron-flink-jobmanager flink run \
  -c org.apache.metron.flink.parsing.ParsingJob \
  /opt/flink/usrlib/metron-flink-parsing.jar

# List jobs
docker exec -it metron-flink-jobmanager flink list

# Cancel job
docker exec -it metron-flink-jobmanager flink cancel <job-id>

# Check logs
docker logs -f metron-flink-taskmanager
```

### Kibana (Visualization)

**Port:** 5601

**Features:**
- Dashboard creation
- Index pattern management
- Saved searches
- Machine learning jobs

**Access:** http://localhost:5601

### Superset (BI Dashboards)

**Port:** 8088

**Features:**
- SQL Lab for ad-hoc queries
- Dashboard builder
- Chart types (40+)
- Scheduled reports

**Access:** http://localhost:8088
**Credentials:** admin/admin

### Airflow (Workflow Orchestration)

**Port:** 8089

**Features:**
- DAG management
- Task scheduling
- Execution history
- Log viewing

**Access:** http://localhost:8089
**Credentials:** admin/admin

### Grafana (Monitoring)

**Port:** 3000

**Features:**
- Pre-configured dashboards
- Prometheus integration
- Alerting
- Annotations

**Access:** http://localhost:3000
**Credentials:** admin/admin

---

## Development Setup

### Building Custom Images

```bash
# Build all custom images
docker-compose build

# Build specific service
docker-compose build metron-rest

# Build with no cache
docker-compose build --no-cache
```

### Hot Reload Development

```bash
# Mount local code
docker-compose -f docker-compose-dev.yml up -d

# The dev compose file mounts:
# - ./metron-platform/metron-flink/target -> /opt/flink/usrlib
# - ./metron-analytics/notebooks -> /home/jovyan/work

# Rebuild and restart service
mvn clean package -DskipTests
docker-compose restart metron-rest
```

### Running Tests

```bash
# Unit tests
docker-compose run --rm metron-rest mvn test

# Integration tests (requires services)
docker-compose up -d kafka cassandra elasticsearch
docker-compose run --rm metron-rest mvn verify -Pintegration-tests
```

### Debugging

```bash
# Enable debug logging
docker-compose -f docker-compose.yml -f docker-compose.debug.yml up -d

# View logs
docker-compose logs -f metron-rest

# Attach debugger (port 5005)
# Add to docker-compose.yml:
# JAVA_TOOL_OPTIONS: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
```

---

## Troubleshooting

### Common Issues

#### 1. Services Won't Start

```bash
# Check logs
docker-compose logs <service-name>

# Common fixes:
# - Insufficient memory: Increase Docker memory limit
# - Port conflicts: Change ports in docker-compose.yml
# - Missing dependencies: Run `docker-compose up -d` to start dependencies first
```

#### 2. Out of Memory

```bash
# Increase Docker Desktop memory (macOS)
# Docker Desktop > Settings > Resources > Memory > 16GB

# For Linux, edit /etc/docker/daemon.json
{
  "default-ulimits": {
    "memlock": {
      "Name": "memlock",
      "Hard": -1,
      "Soft": -1
    }
  }
}

# Restart Docker
sudo systemctl restart docker
```

#### 3. Kafka Connection Issues

```bash
# Test connectivity
docker run --rm --network metron_metron-network confluentinc/cp-kafka:7.5.0 \
  kafka-broker-api-versions --bootstrap-server kafka:9092

# Check broker is running
docker exec -it metron-kafka kafka-broker-api-versions --bootstrap-server localhost:9092
```

#### 4. Elasticsearch Errors

```bash
# Check cluster health
curl http://localhost:9200/_cluster/health?pretty

# Common fixes:
# - Yellow status: Normal for single-node (no replicas)
# - Red status: Check disk space
# - Connection refused: Wait for startup (2-3 minutes)
```

#### 5. Flink Jobs Failing

```bash
# Check TaskManager logs
docker logs metron-flink-taskmanager

# Increase memory
# Edit docker-compose.yml:
# taskmanager.memory.process.size: 4096m

# Restart Flink
docker-compose restart flink-taskmanager
```

### Performance Tuning

#### Elasticsearch

```bash
# Increase heap size
ES_JAVA_OPTS=-Xms8g -Xmx8g

# Disable swapping
bootstrap.memory_lock: true
```

#### Kafka

```bash
# Increase retention
KAFKA_LOG_RETENTION_HOURS=336  # 14 days

# Increase segment size
KAFKA_LOG_SEGMENT_BYTES=1073741824  # 1GB
```

#### Cassandra

```bash
# Increase heap
MAX_HEAP_SIZE=4G
HEAP_NEWSIZE=800M

# Enable JMX monitoring
LOCAL_JMX=no
```

### Health Checks

```bash
# Check all services
docker-compose ps

# Detailed health check
docker inspect metron-kafka | grep -A 10 Health

# Test endpoints
curl -f http://localhost:8080/actuator/health  # Metron REST
curl -f http://localhost:9200/_cluster/health  # Elasticsearch
curl -f http://localhost:8082/overview         # Flink
```

---

## Production Deployment

### Security Hardening

#### 1. Enable TLS/SSL

```yaml
# docker-compose.prod.yml
elasticsearch:
  environment:
    - xpack.security.enabled=true
    - xpack.security.transport.ssl.enabled=true
    - xpack.security.http.ssl.enabled=true
```

#### 2. Change Default Passwords

```bash
# Generate strong passwords
openssl rand -base64 32

# Update .env file
SUPERSET_SECRET_KEY=$(openssl rand -base64 32)
AIRFLOW_FERNET_KEY=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 16)
```

#### 3. Network Security

```yaml
# docker-compose.prod.yml
networks:
  metron-network:
    driver: bridge
    internal: true  # No external access

  metron-public:
    driver: bridge  # Only for reverse proxy
```

### Resource Management

```yaml
# docker-compose.prod.yml
services:
  elasticsearch:
    deploy:
      resources:
        limits:
          memory: 16g
          cpus: '8'
      replicas: 3
      placement:
        constraints:
          - node.role == worker
```

### Backup Strategy

```bash
# Elasticsearch snapshots
docker exec -it metron-elasticsearch curl -X PUT \
  http://localhost:9200/_snapshot/metron_backup -d '{
    "type": "fs",
    "settings": {
      "location": "/mnt/backups/elasticsearch"
    }
  }'

# Cassandra snapshots
docker exec -it metron-cassandra nodetool snapshot metron

# Volume backups
docker run --rm -v metron_cassandra-data:/data -v /backup:/backup \
  alpine tar czf /backup/cassandra-$(date +%Y%m%d).tar.gz /data
```

### Monitoring

```bash
# Export Prometheus metrics
curl http://localhost:9090/metrics

# Grafana alerting
# Configure in docker/grafana/dashboards/

# Health checks
docker-compose exec prometheus promtool check health
```

### Scaling

```bash
# Scale Flink TaskManagers
docker-compose up -d --scale flink-taskmanager=5

# Scale Kafka brokers
docker-compose up -d --scale kafka=3

# Scale Cassandra nodes
docker-compose up -d --scale cassandra=3
```

---

## Container Management

### Start/Stop

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: data loss)
docker-compose down -v

# Restart specific service
docker-compose restart metron-rest
```

### Logs

```bash
# View all logs
docker-compose logs

# Follow specific service
docker-compose logs -f metron-rest

# Last 100 lines
docker-compose logs --tail=100 kafka

# Search logs
docker-compose logs metron-rest | grep ERROR
```

### Updates

```bash
# Pull latest images
docker-compose pull

# Rebuild custom images
docker-compose build --pull

# Restart with new images
docker-compose up -d --force-recreate
```

### Cleanup

```bash
# Remove stopped containers
docker-compose down

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Full cleanup (WARNING: removes all Docker data)
docker system prune -a --volumes
```

---

## Advanced Topics

### Multi-Node Deployment

Use Docker Swarm for multi-node deployment:

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml metron

# Scale services
docker service scale metron_flink-taskmanager=10
```

### Custom Networks

```yaml
# docker-compose.yml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

services:
  metron-rest:
    networks:
      - frontend
      - backend
```

### External Services

Connect to external Kafka, Elasticsearch, etc.:

```yaml
# docker-compose.external.yml
services:
  metron-rest:
    environment:
      KAFKA_BOOTSTRAP_SERVERS: external-kafka:9092
      ELASTICSEARCH_URL: http://external-es:9200

# Remove internal services
# kafka:
# elasticsearch:
```

---

## FAQ

**Q: How much RAM do I need?**
A: Minimum 16GB for full stack, 8GB for dev stack.

**Q: Can I run this in production?**
A: Yes, but follow the production deployment section for security hardening.

**Q: How do I persist data?**
A: Data is persisted in Docker volumes automatically.

**Q: Can I use external Kafka/ES?**
A: Yes, use docker-compose.external.yml and configure connection strings.

**Q: How do I upgrade?**
A: Pull latest images, rebuild custom images, restart services.

**Q: Where are logs stored?**
A: Use `docker-compose logs` or check `/var/log` inside containers.

---

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Metron Modernization Guide](MODERNIZATION_GUIDE.md)
- [Metron Migration Guide](MIGRATION_GUIDE.md)
- [Kubernetes Deployment](metron-deployment/kubernetes/README.md)

---

## Support

- GitHub Issues: https://github.com/apache/metron/issues
- Mailing List: dev@metron.apache.org
- Slack: #metron-docker

---

**Version:** 2.0.0
**Last Updated:** 2025-01-08
