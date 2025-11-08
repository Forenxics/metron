# Metron Kubernetes Deployment

This directory contains Kubernetes deployment configurations for modernized Apache Metron.

## Directory Structure

```
kubernetes/
├── helm/
│   └── metron-platform/        # Main Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       │   ├── namespace.yaml
│       │   ├── flink-jobs.yaml
│       │   └── metron-rest-deployment.yaml
│       └── README.md
├── manifests/                   # Raw Kubernetes manifests
│   ├── kafka-cluster.yaml
│   ├── cassandra-cluster.yaml
│   └── elasticsearch-cluster.yaml
├── operators/                   # Kubernetes operator configurations
│   ├── strimzi-kafka/
│   ├── flink-operator/
│   └── eck-operator/
└── examples/                    # Example configurations
    ├── sample-data-job.yaml
    └── threat-intel-import.yaml
```

## Prerequisites

- Kubernetes 1.25+
- Helm 3.x
- kubectl configured
- Sufficient cluster resources (minimum: 16 CPU, 64GB RAM)

## Quick Start

### 1. Install CRDs and Operators

```bash
# Install Strimzi Kafka Operator
kubectl create namespace kafka
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

# Install Flink Kubernetes Operator
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.7.0/
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator

# Install Elastic Cloud on Kubernetes (ECK)
kubectl create -f https://download.elastic.co/downloads/eck/2.10.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.10.0/operator.yaml

# Install K8ssandra Operator (Cassandra)
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm install k8ssandra-operator k8ssandra/k8ssandra-operator
```

### 2. Install Metron Platform

```bash
# Add Metron Helm repository (after publication)
helm repo add metron https://metron.apache.org/helm-charts
helm repo update

# Install with default values
helm install metron metron/metron-platform \
  --namespace metron \
  --create-namespace

# Or install from local chart
cd metron-deployment/kubernetes/helm
helm install metron ./metron-platform \
  --namespace metron \
  --create-namespace
```

### 3. Customize Installation

```bash
# Create custom values file
cat > my-values.yaml <<EOF
kafka:
  cluster:
    replicas: 5
    storage:
      size: 200Gi

flink:
  taskmanager:
    replicas: 10

elasticsearch:
  data:
    replicas: 5
    storage:
      size: 2Ti
EOF

# Install with custom values
helm install metron metron/metron-platform \
  --namespace metron \
  --create-namespace \
  --values my-values.yaml
```

### 4. Access UIs

```bash
# Port-forward for local access
kubectl port-forward -n metron svc/superset 8088:8088
kubectl port-forward -n metron svc/kibana 5601:5601
kubectl port-forward -n metron svc/airflow-webserver 8080:8080
kubectl port-forward -n metron svc/grafana 3000:3000

# Access at:
# - Superset: http://localhost:8088
# - Kibana: http://localhost:5601
# - Airflow: http://localhost:8080
# - Grafana: http://localhost:3000
```

## Component-Specific Deployment

### Kafka

```bash
kubectl apply -f manifests/kafka-cluster.yaml -n metron

# Wait for Kafka to be ready
kubectl wait kafka/metron-kafka --for=condition=Ready --timeout=300s -n metron

# Create topics
kubectl apply -f examples/kafka-topics.yaml -n metron
```

### Flink Jobs

```bash
# Deploy parsing job
kubectl apply -f manifests/flink-parsing-job.yaml -n metron

# Check job status
kubectl get flinkdeployment -n metron

# View logs
kubectl logs -n metron deployment/metron-parsing -f
```

### Cassandra

```bash
kubectl apply -f manifests/cassandra-cluster.yaml -n metron

# Wait for Cassandra to be ready
kubectl wait k8ssandracluster/metron-cassandra --for=condition=Ready --timeout=600s -n metron

# Initialize schema
kubectl exec -it -n metron metron-cassandra-dc1-default-sts-0 -- cqlsh -f /schema/metron-schema.cql
```

### Elasticsearch

```bash
kubectl apply -f manifests/elasticsearch-cluster.yaml -n metron

# Wait for Elasticsearch to be ready
kubectl wait elasticsearch/metron-elasticsearch --for=condition=Ready --timeout=300s -n metron

# Get credentials
kubectl get secret metron-elasticsearch-es-elastic-user -n metron -o jsonpath='{.data.elastic}' | base64 -d
```

## Scaling

### Horizontal Scaling

```bash
# Scale Flink task managers
kubectl scale flinkdeployment metron-parsing --replicas=10 -n metron

# Scale Cassandra nodes
kubectl patch k8ssandracluster metron-cassandra -n metron \
  --type merge -p '{"spec":{"cassandra":{"datacenters":[{"size":5}]}}}'

# Scale Elasticsearch data nodes
kubectl patch elasticsearch metron-elasticsearch -n metron \
  --type merge -p '{"spec":{"nodeSets":[{"name":"data","count":5}]}}'
```

### Vertical Scaling

```bash
# Update resource limits
helm upgrade metron metron/metron-platform \
  --namespace metron \
  --reuse-values \
  --set flink.taskmanager.resources.limits.memory=16Gi
```

## Monitoring

### Prometheus Metrics

```bash
# Access Prometheus
kubectl port-forward -n metron svc/prometheus-operated 9090:9090

# Example queries:
# - Flink backpressure: flink_taskmanager_job_task_backPressuredTimeMsPerSecond
# - Kafka lag: kafka_consumergroup_lag
# - Cassandra read latency: cassandra_table_readlatency
```

### Grafana Dashboards

```bash
# Access Grafana
kubectl port-forward -n metron svc/grafana 3000:3000

# Default credentials:
# - Username: admin
# - Password: (from secret)
kubectl get secret metron-grafana -n metron -o jsonpath='{.data.admin-password}' | base64 -d
```

## Troubleshooting

### Flink Jobs Not Starting

```bash
# Check Flink operator logs
kubectl logs -n flink-system deployment/flink-kubernetes-operator

# Check job events
kubectl describe flinkdeployment metron-parsing -n metron

# Check task manager logs
kubectl logs -n metron -l app=metron-parsing,component=taskmanager
```

### Kafka Connection Issues

```bash
# Test Kafka connectivity
kubectl run kafka-test --rm -it --image=confluentinc/cp-kafka:7.5.0 -- \
  kafka-broker-api-versions --bootstrap-server metron-kafka-bootstrap:9092

# Check Kafka cluster status
kubectl get kafka metron-kafka -n metron -o yaml
```

### Cassandra Performance Issues

```bash
# Check Cassandra metrics
kubectl exec -it -n metron metron-cassandra-dc1-default-sts-0 -- nodetool status
kubectl exec -it -n metron metron-cassandra-dc1-default-sts-0 -- nodetool tpstats

# Check resource usage
kubectl top pods -n metron -l app.kubernetes.io/name=cassandra
```

### Elasticsearch Indexing Slow

```bash
# Check cluster health
kubectl exec -it -n metron metron-elasticsearch-es-default-0 -- \
  curl -u elastic:$PASSWORD https://localhost:9200/_cluster/health?pretty

# Check pending tasks
kubectl exec -it -n metron metron-elasticsearch-es-default-0 -- \
  curl -u elastic:$PASSWORD https://localhost:9200/_cluster/pending_tasks?pretty

# Increase refresh interval for high-throughput indexing
kubectl exec -it -n metron metron-elasticsearch-es-default-0 -- \
  curl -X PUT -u elastic:$PASSWORD https://localhost:9200/metron-*/_settings -H 'Content-Type: application/json' -d '{"index":{"refresh_interval":"30s"}}'
```

## Backup and Recovery

### Velero Backup

```bash
# Install Velero
velero install --provider aws --bucket metron-backups --backup-location-config region=us-east-1

# Create backup
velero backup create metron-backup-$(date +%Y%m%d) --include-namespaces metron

# Restore from backup
velero restore create --from-backup metron-backup-20250101
```

### Cassandra Backup

```bash
# Take snapshot
kubectl exec -it -n metron metron-cassandra-dc1-default-sts-0 -- \
  nodetool snapshot metron

# Medusa backup (via K8ssandra)
kubectl apply -f examples/cassandra-backup.yaml -n metron
```

### Elasticsearch Snapshot

```bash
# Create snapshot repository
kubectl exec -it -n metron metron-elasticsearch-es-default-0 -- \
  curl -X PUT -u elastic:$PASSWORD https://localhost:9200/_snapshot/metron_backup -H 'Content-Type: application/json' -d '{
    "type": "s3",
    "settings": {
      "bucket": "metron-es-snapshots",
      "region": "us-east-1"
    }
  }'

# Take snapshot
kubectl exec -it -n metron metron-elasticsearch-es-default-0 -- \
  curl -X PUT -u elastic:$PASSWORD https://localhost:9200/_snapshot/metron_backup/snapshot_$(date +%Y%m%d)?wait_for_completion=true
```

## Upgrading

### Upgrade Metron

```bash
# Update Helm repository
helm repo update

# Check for updates
helm search repo metron/metron-platform

# Upgrade
helm upgrade metron metron/metron-platform \
  --namespace metron \
  --reuse-values
```

### Rolling Updates

```bash
# Update Flink job with savepoint
kubectl patch flinkdeployment metron-parsing -n metron \
  --type merge -p '{"spec":{"job":{"upgradeMode":"savepoint"}}}'

# Update image
kubectl set image deployment/metron-rest metron-rest=metron/metron-rest:2.1.0 -n metron
```

## Security

### TLS Configuration

```bash
# Generate TLS certificates (using cert-manager)
kubectl apply -f manifests/certificates.yaml -n metron

# Verify certificates
kubectl get certificate -n metron
```

### Network Policies

```bash
# Apply network policies
kubectl apply -f manifests/network-policies.yaml -n metron

# Test connectivity
kubectl run test-pod --rm -it --image=busybox -n metron -- wget -O- metron-kafka-bootstrap:9092
```

### RBAC

```bash
# Create service accounts
kubectl apply -f manifests/service-accounts.yaml -n metron

# Bind roles
kubectl apply -f manifests/role-bindings.yaml -n metron
```

## Performance Tuning

### Flink

- **Parallelism:** Set based on data volume (typically 1-2x number of Kafka partitions)
- **Checkpointing:** 1-5 minutes for most use cases
- **State Backend:** RocksDB for large state, heap for small state
- **Task Slots:** 2-4 per task manager

### Kafka

- **Partitions:** 30-50 per topic for high throughput
- **Replication Factor:** 3 for production
- **Compression:** LZ4 or Snappy
- **Retention:** Based on storage capacity (typically 7-30 days)

### Cassandra

- **Replication Strategy:** NetworkTopologyStrategy with RF=3
- **Compaction:** LeveledCompactionStrategy for read-heavy, SizeTieredCompactionStrategy for write-heavy
- **Heap Size:** 8-16GB (50% of RAM, max 31GB)

### Elasticsearch

- **Shards:** 20-40GB per shard
- **Replicas:** 1-2 for production
- **Refresh Interval:** 30s for high-throughput indexing
- **Merge Policy:** TieredMergePolicy

## Cost Optimization

### Resource Right-Sizing

```bash
# View resource usage
kubectl top nodes
kubectl top pods -n metron --containers

# Analyze with VPA recommendations
kubectl get vpa -n metron
```

### Auto-Scaling

```bash
# Enable HPA for Metron REST API
kubectl autoscale deployment metron-rest --cpu-percent=70 --min=2 --max=10 -n metron

# Enable cluster autoscaler (cloud-specific)
# AWS: eksctl create cluster --asg-access
# GCP: gcloud container clusters create --enable-autoscaling
```

### Spot/Preemptible Instances

```bash
# Label task managers for spot instances
kubectl label nodes <node-name> workload-type=spot

# Use node affinity in Flink deployments
# (see examples/flink-spot-instances.yaml)
```

## Migration from Legacy Metron

See [MIGRATION.md](../MIGRATION.md) for detailed migration guide.

## Additional Resources

- [Metron Modernization Guide](../../MODERNIZATION_GUIDE.md)
- [Flink Documentation](https://nightlies.apache.org/flink/flink-docs-release-1.18/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Cassandra Documentation](https://cassandra.apache.org/doc/latest/)
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/8.11/index.html)

## Support

- GitHub Issues: https://github.com/apache/metron/issues
- Mailing List: dev@metron.apache.org
- Slack: #metron-modernization
