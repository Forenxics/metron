# Metron Docker Files

This directory contains Dockerfiles and configuration files for all Metron components.

## Directory Structure

```
docker/
├── cassandra/
│   └── init-scripts/          # Cassandra schema initialization
│       └── 01-create-schema.cql
├── grafana/
│   ├── dashboards/            # Pre-configured Grafana dashboards
│   └── datasources/           # Grafana datasource configurations
│       └── datasources.yml
├── prometheus/
│   └── prometheus.yml         # Prometheus scrape configuration
├── superset/
│   └── superset_config.py     # Superset configuration
├── metron-rest/
│   └── Dockerfile             # Metron REST API container
├── metron-alerts-ui/
│   ├── Dockerfile             # Metron Alerts UI container
│   └── nginx.conf             # Nginx configuration
├── metron-config-ui/
│   ├── Dockerfile             # Metron Config UI container
│   └── nginx.conf             # Nginx configuration
├── metron-flink-parsing/
│   └── Dockerfile             # Flink parsing job container
├── metron-flink-enrichment/
│   └── Dockerfile             # Flink enrichment job container
├── metron-flink-indexing/
│   └── Dockerfile             # Flink indexing job container
└── streamlit-threat-hunting/
    ├── Dockerfile             # Streamlit threat hunting app
    ├── requirements.txt       # Python dependencies
    └── app.py                 # Streamlit application
```

## Component Overview

### Infrastructure Services

- **Kafka + ZooKeeper**: Message streaming platform
- **Cassandra**: NoSQL database for threat intelligence and profiling
- **Elasticsearch**: Search and analytics engine
- **Neo4j**: Graph database for threat intelligence relationships

### Processing Services

- **Flink**: Stream processing (JobManager + TaskManagers)
- **Airflow**: Workflow orchestration
- **MLflow**: ML experiment tracking

### Application Services

- **Metron REST API**: Backend API (Spring Boot)
- **Metron Alerts UI**: Alert management interface (Angular)
- **Metron Config UI**: Configuration interface (Angular)
- **Streamlit**: Interactive threat hunting application

### Visualization & Monitoring

- **Kibana**: Elasticsearch visualization
- **Superset**: BI dashboards
- **Grafana**: Monitoring dashboards
- **Prometheus**: Metrics collection

## Building Images

### Build All Images

```bash
cd /path/to/metron
docker-compose build
```

### Build Specific Image

```bash
# Build REST API
docker-compose build metron-rest

# Build Alerts UI
docker-compose build metron-alerts-ui

# Build Streamlit app
docker-compose build streamlit-threat-hunting
```

### Build Without Cache

```bash
docker-compose build --no-cache
```

## Image Sizes

Approximate image sizes after build:

| Image | Size |
|-------|------|
| metron-rest | ~350 MB |
| metron-alerts-ui | ~50 MB |
| metron-config-ui | ~50 MB |
| streamlit-threat-hunting | ~800 MB |
| flink-parsing | ~600 MB |

## Configuration

### Environment Variables

See [.env.example](../.env.example) for all available environment variables.

### Volume Mounts

Development volume mounts (for hot reload):

```yaml
metron-rest:
  volumes:
    - ../metron-interface/metron-rest/target/metron-rest.jar:/app/metron-rest.jar

flink-taskmanager:
  volumes:
    - ../metron-platform/metron-flink/target:/opt/flink/usrlib
```

## Customization

### Adding Custom Parsers

1. Build your parser JAR
2. Mount to Flink TaskManager:
   ```yaml
   flink-taskmanager:
     volumes:
       - ./my-custom-parser.jar:/opt/flink/usrlib/my-custom-parser.jar
   ```

### Custom Dashboards

Place dashboard JSON files in:
- Grafana: `docker/grafana/dashboards/`
- Superset: Import via UI

### Custom Enrichments

Add to Cassandra init scripts:
```bash
docker/cassandra/init-scripts/02-my-enrichments.cql
```

## Troubleshooting

### Image Build Fails

```bash
# Clear Docker cache
docker builder prune -a

# Rebuild from scratch
docker-compose build --no-cache
```

### Container Starts But Crashes

```bash
# Check logs
docker logs metron-<service-name>

# Common issues:
# - Missing dependencies: Check Dockerfile COPY statements
# - Wrong paths: Verify volume mounts
# - Insufficient memory: Increase Docker memory limit
```

### Connection Issues Between Services

```bash
# Test network connectivity
docker run --rm --network metron_metron-network alpine ping kafka

# Check if service is running
docker-compose ps

# Verify environment variables
docker-compose config
```

## Best Practices

### Development

1. Use volume mounts for code (hot reload)
2. Use docker-compose-dev.yml for lighter stack
3. Enable debug logging for troubleshooting
4. Use `make` commands for common operations

### Production

1. Build optimized images (multi-stage builds)
2. Use specific image tags (not `latest`)
3. Set resource limits
4. Enable health checks
5. Use secrets management (Docker secrets, Vault)
6. Enable TLS/SSL
7. Scan images for vulnerabilities

## Security

### Image Scanning

```bash
# Scan with Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image metron/metron-rest:latest

# Scan with Snyk
snyk container test metron/metron-rest:latest
```

### Running as Non-Root

All Metron images run as non-root user (UID 1001):

```dockerfile
RUN adduser -D -u 1001 metron
USER metron
```

### Minimal Base Images

We use minimal base images:
- Alpine Linux for small footprint
- Distroless for production (future)

## Contributing

When adding new Dockerfiles:

1. Use multi-stage builds
2. Minimize layers
3. Run as non-root
4. Add health checks
5. Document environment variables
6. Include .dockerignore

## Related Documentation

- [Docker Deployment Guide](../DOCKER_GUIDE.md)
- [Modernization Guide](../MODERNIZATION_GUIDE.md)
- [Kubernetes Deployment](../metron-deployment/kubernetes/README.md)

## Support

- GitHub Issues: https://github.com/apache/metron/issues
- Docker Hub: https://hub.docker.com/u/metron
- Mailing List: dev@metron.apache.org
