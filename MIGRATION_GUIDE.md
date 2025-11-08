# Apache Metron Migration Guide
## From Legacy (0.7.2) to Modern (2.0.0)

This guide provides step-by-step instructions for migrating from the archived Apache Metron 0.7.2 to the modernized 2.0.0 release.

---

## Table of Contents

1. [Pre-Migration Assessment](#pre-migration-assessment)
2. [Backup Strategy](#backup-strategy)
3. [Component-by-Component Migration](#component-by-component-migration)
4. [Data Migration](#data-migration)
5. [Testing Strategy](#testing-strategy)
6. [Rollback Plan](#rollback-plan)
7. [Post-Migration Validation](#post-migration-validation)

---

## Pre-Migration Assessment

### 1. Document Current State

```bash
# Capture current topology information
storm list > current-topologies.txt

# Export Kafka topics
kafka-topics.sh --list --bootstrap-server localhost:9092 > kafka-topics.txt

# Document HBase tables
echo "list" | hbase shell > hbase-tables.txt

# Capture Elasticsearch indices
curl -XGET 'localhost:9200/_cat/indices?v' > es-indices.txt

# Export configurations from ZooKeeper
/usr/metron/0.7.2/bin/zk_load_configs.sh --mode DUMP --output-dir /tmp/metron-configs
```

### 2. Measure Current Performance

```bash
# Kafka consumer lag
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group enrichments

# Storm topology stats
storm metrics | tee storm-metrics-baseline.txt

# Elasticsearch indexing rate
curl -XGET 'localhost:9200/_stats/indexing' | jq .
```

### 3. Identify Custom Components

- Custom parsers
- Custom enrichments
- Custom Stellar functions
- Custom UI modifications
- Custom PCAP filters

---

## Backup Strategy

### 1. Elasticsearch Backup

```bash
# Create snapshot repository
curl -X PUT "localhost:9200/_snapshot/metron_backup" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/mnt/backups/elasticsearch"
  }
}'

# Take snapshot of all indices
curl -X PUT "localhost:9200/_snapshot/metron_backup/snapshot_$(date +%Y%m%d)" -H 'Content-Type: application/json' -d'
{
  "indices": "metron-*",
  "ignore_unavailable": true,
  "include_global_state": false
}'

# Monitor snapshot progress
curl -X GET "localhost:9200/_snapshot/metron_backup/snapshot_$(date +%Y%m%d)/_status"
```

### 2. HBase Backup

```bash
# Create snapshots of all Metron tables
hbase shell <<EOF
snapshot 'enrichment', 'enrichment_backup_$(date +%Y%m%d)'
snapshot 'threatintel', 'threatintel_backup_$(date +%Y%m%d)'
snapshot 'profiler', 'profiler_backup_$(date +%Y%m%d)'
EOF

# Export snapshots to HDFS
hbase org.apache.hadoop.hbase.snapshot.ExportSnapshot \
  -snapshot enrichment_backup_$(date +%Y%m%d) \
  -copy-to hdfs://namenode:8020/metron-backups/hbase/enrichment

hbase org.apache.hadoop.hbase.snapshot.ExportSnapshot \
  -snapshot threatintel_backup_$(date +%Y%m%d) \
  -copy-to hdfs://namenode:8020/metron-backups/hbase/threatintel
```

### 3. Kafka Topic Backup

```bash
# Export Kafka topics to files (using kafka-consumer)
for topic in $(kafka-topics.sh --list --bootstrap-server localhost:9092 | grep metron); do
  kafka-console-consumer.sh --bootstrap-server localhost:9092 \
    --topic $topic --from-beginning \
    --timeout-ms 30000 > /mnt/backups/kafka/${topic}_backup.json 2>/dev/null
done
```

### 4. Configuration Backup

```bash
# ZooKeeper configurations
/usr/metron/0.7.2/bin/zk_load_configs.sh \
  --mode DUMP \
  --output-dir /mnt/backups/configs

# Sensor configurations
cp -r /usr/metron/0.7.2/config /mnt/backups/metron-config

# Parser configurations
cp -r /etc/metron/parsers /mnt/backups/parsers
```

---

## Component-by-Component Migration

### Phase 1: Infrastructure (Weeks 1-4)

#### Step 1: Deploy Kubernetes Cluster

```bash
# Option 1: AWS EKS
eksctl create cluster \
  --name metron-prod \
  --version 1.28 \
  --region us-east-1 \
  --nodegroup-name metron-nodes \
  --node-type m5.2xlarge \
  --nodes 5 \
  --nodes-min 3 \
  --nodes-max 10 \
  --managed

# Option 2: GCP GKE
gcloud container clusters create metron-prod \
  --region us-central1 \
  --machine-type n1-standard-8 \
  --num-nodes 5 \
  --enable-autoscaling \
  --min-nodes 3 \
  --max-nodes 10

# Option 3: On-premise (kubeadm)
# Follow official Kubernetes documentation
```

#### Step 2: Install Operators

```bash
# Install Strimzi Kafka Operator
kubectl create namespace kafka
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

# Install Flink Kubernetes Operator
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.7.0/
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator

# Install ECK (Elastic Cloud on Kubernetes)
kubectl create -f https://download.elastic.co/downloads/eck/2.10.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.10.0/operator.yaml

# Install K8ssandra (Cassandra Operator)
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm install k8ssandra-operator k8ssandra/k8ssandra-operator -n k8ssandra --create-namespace
```

#### Step 3: Deploy Kafka 3.x

```bash
# Apply Kafka cluster manifest
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: metron-kafka
  namespace: metron
spec:
  kafka:
    version: 3.6.0
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
      inter.broker.protocol.version: "3.6"
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        deleteClaim: false
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 10Gi
      deleteClaim: false
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF

# Wait for Kafka to be ready
kubectl wait kafka/metron-kafka --for=condition=Ready --timeout=600s -n metron
```

#### Step 4: Migrate Kafka Topics

```bash
# Create topics in new Kafka cluster
for topic in $(cat kafka-topics.txt); do
  kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: $topic
  namespace: metron
  labels:
    strimzi.io/cluster: metron-kafka
spec:
  partitions: 30
  replicas: 3
  config:
    retention.ms: 604800000  # 7 days
    compression.type: snappy
EOF
done

# Use MirrorMaker 2 for data migration
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaMirrorMaker2
metadata:
  name: metron-mirror
  namespace: metron
spec:
  version: 3.6.0
  replicas: 3
  connectCluster: "target"
  clusters:
  - alias: "source"
    bootstrapServers: old-kafka:9092
  - alias: "target"
    bootstrapServers: metron-kafka-kafka-bootstrap:9092
    config:
      config.storage.replication.factor: 3
      offset.storage.replication.factor: 3
      status.storage.replication.factor: 3
  mirrors:
  - sourceCluster: "source"
    targetCluster: "target"
    sourceConnector:
      config:
        replication.factor: 3
        offset-syncs.topic.replication.factor: 3
        sync.topic.acls.enabled: "false"
    heartbeatConnector:
      config:
        heartbeats.topic.replication.factor: 3
    checkpointConnector:
      config:
        checkpoints.topic.replication.factor: 3
    topicsPattern: ".*"
    groupsPattern: ".*"
EOF
```

### Phase 2: Storage Layer (Weeks 5-8)

#### Step 5: Deploy Cassandra

```bash
# Deploy Cassandra cluster
kubectl apply -f - <<EOF
apiVersion: k8ssandra.io/v1alpha1
kind: K8ssandraCluster
metadata:
  name: metron-cassandra
  namespace: metron
spec:
  cassandra:
    serverVersion: 4.1.0
    datacenters:
      - metadata:
          name: dc1
        size: 3
        storageConfig:
          cassandraDataVolumeClaimSpec:
            storageClassName: fast-ssd
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 500Gi
        config:
          jvmOptions:
            heapSize: 8G
        resources:
          requests:
            memory: 16Gi
            cpu: 4
          limits:
            memory: 16Gi
            cpu: 4
EOF

# Wait for Cassandra to be ready
kubectl wait k8ssandracluster/metron-cassandra --for=condition=Ready --timeout=900s -n metron
```

#### Step 6: Migrate HBase Data to Cassandra

```bash
# Create Cassandra schema
kubectl exec -it metron-cassandra-dc1-default-sts-0 -n metron -- cqlsh -e "
CREATE KEYSPACE IF NOT EXISTS metron
  WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3};

-- Threat Intelligence Table
CREATE TABLE IF NOT EXISTS metron.threat_intel (
  indicator_type text,
  indicator_value text,
  timestamp timestamp,
  threat_score int,
  source text,
  metadata map<text, text>,
  PRIMARY KEY ((indicator_type, indicator_value), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND compaction = {'class': 'LeveledCompactionStrategy'}
  AND gc_grace_seconds = 86400;

-- Enrichment Data Table
CREATE TABLE IF NOT EXISTS metron.enrichment_data (
  enrichment_type text,
  indicator text,
  timestamp timestamp,
  data map<text, text>,
  PRIMARY KEY ((enrichment_type, indicator), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC);

-- Profiler Data Table
CREATE TABLE IF NOT EXISTS metron.profiler_data (
  profile text,
  entity text,
  period text,
  timestamp timestamp,
  measurements map<text, double>,
  PRIMARY KEY ((profile, entity, period), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 2592000;  -- 30 days
"

# Run Spark migration job
spark-submit --master yarn \
  --class org.apache.metron.migration.HBaseToCassandraMigration \
  --conf spark.cassandra.connection.host=metron-cassandra-dc1-service.metron.svc.cluster.local \
  metron-migration.jar \
  --hbase-table enrichment \
  --cassandra-table metron.enrichment_data \
  --batch-size 10000
```

#### Step 7: Deploy Elasticsearch 8.x

```bash
# Deploy Elasticsearch cluster
kubectl apply -f - <<EOF
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: metron-elasticsearch
  namespace: metron
spec:
  version: 8.11.0
  nodeSets:
  # Master nodes
  - name: master
    count: 3
    config:
      node.roles: ["master"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 50Gi
        storageClassName: fast-ssd
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 4Gi
              cpu: 2
            limits:
              memory: 4Gi
              cpu: 2
  # Data nodes
  - name: data
    count: 3
    config:
      node.roles: ["data", "ingest"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Ti
        storageClassName: fast-ssd
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 16Gi
              cpu: 4
            limits:
              memory: 16Gi
              cpu: 4
  http:
    tls:
      selfSignedCertificate:
        disabled: false
EOF

# Wait for Elasticsearch to be ready
kubectl wait elasticsearch/metron-elasticsearch --for=condition=Ready --timeout=600s -n metron
```

#### Step 8: Migrate Elasticsearch Data

```bash
# Get Elasticsearch credentials
ES_PASSWORD=$(kubectl get secret metron-elasticsearch-es-elastic-user -n metron -o jsonpath='{.data.elastic}' | base64 -d)

# Restore from snapshot
kubectl exec -it metron-elasticsearch-es-data-0 -n metron -- \
  curl -X POST -u elastic:$ES_PASSWORD https://localhost:9200/_snapshot/metron_backup/snapshot_$(date +%Y%m%d)/_restore -H 'Content-Type: application/json' -d '{
    "indices": "metron-*",
    "ignore_unavailable": true,
    "include_global_state": false,
    "rename_pattern": "(.+)",
    "rename_replacement": "restored_$1"
  }'

# Reindex to new format (if schema changes)
kubectl exec -it metron-elasticsearch-es-data-0 -n metron -- \
  curl -X POST -u elastic:$ES_PASSWORD https://localhost:9200/_reindex -H 'Content-Type: application/json' -d '{
    "source": {
      "index": "restored_metron-bro-*"
    },
    "dest": {
      "index": "metron-bro-2.0"
    }
  }'
```

### Phase 3: Processing Layer (Weeks 9-14)

#### Step 9: Deploy Flink Jobs

```bash
# Deploy parsing job
kubectl apply -f metron-deployment/kubernetes/manifests/flink-parsing-job.yaml

# Deploy enrichment job
kubectl apply -f metron-deployment/kubernetes/manifests/flink-enrichment-job.yaml

# Deploy indexing job
kubectl apply -f metron-deployment/kubernetes/manifests/flink-indexing-job.yaml

# Wait for all jobs to start
kubectl get flinkdeployment -n metron
kubectl wait flinkdeployment/metron-parsing --for=condition=Running --timeout=300s -n metron
kubectl wait flinkdeployment/metron-enrichment --for=condition=Running --timeout=300s -n metron
kubectl wait flinkdeployment/metron-indexing --for=condition=Running --timeout=300s -n metron
```

#### Step 10: Parallel Running (Storm + Flink)

```bash
# Configure Flink jobs to use different consumer groups
# This allows both Storm and Flink to process the same data in parallel

# Edit Flink job configs
kubectl edit flinkdeployment metron-parsing -n metron

# In the env variables, ensure:
# KAFKA_GROUP_ID: metron-parsing-flink  # Different from Storm's group

# Monitor both systems
watch -n 5 'echo "=== Storm ===" && storm list && echo "\n=== Flink ===" && kubectl get flinkdeployment -n metron'
```

#### Step 11: Cutover from Storm to Flink

```bash
# Step 1: Pause Storm topologies (stop consuming new data)
storm deactivate enrichments
storm deactivate indexing
storm deactivate parsing

# Step 2: Wait for Storm to finish processing in-flight messages
# Monitor Storm UI until all tuples are processed

# Step 3: Update Flink jobs to use original consumer groups
kubectl patch flinkdeployment metron-parsing -n metron --type merge -p '{
  "spec": {
    "flinkConfiguration": {
      "env.java.opts.all": "-DKAFKA_GROUP_ID=metron-parsing"
    }
  }
}'

# Step 4: Restart Flink jobs with new consumer groups
kubectl delete flinkdeployment metron-parsing -n metron
kubectl apply -f metron-deployment/kubernetes/manifests/flink-parsing-job.yaml

# Step 5: Verify Flink is consuming
kubectl logs -n metron deployment/metron-parsing -f

# Step 6: Kill Storm topologies
storm kill enrichments
storm kill indexing
storm kill parsing
```

### Phase 4: UI and API (Weeks 15-16)

#### Step 12: Deploy Metron REST API

```bash
kubectl apply -f metron-deployment/kubernetes/manifests/metron-rest-deployment.yaml

# Wait for REST API to be ready
kubectl wait deployment/metron-rest --for=condition=Available --timeout=300s -n metron

# Test REST API
kubectl port-forward -n metron svc/metron-rest 8082:8082 &
curl http://localhost:8082/actuator/health
```

#### Step 13: Deploy Modern UIs

```bash
# Deploy Kibana
kubectl apply -f metron-deployment/kubernetes/manifests/kibana-deployment.yaml

# Deploy Superset
helm install superset apache-superset/superset -n metron \
  --values metron-deployment/kubernetes/helm/superset-values.yaml

# Deploy Streamlit apps
kubectl apply -f metron-deployment/kubernetes/manifests/streamlit-apps.yaml
```

---

## Data Migration

### Threat Intelligence Data

```python
# Python script to migrate threat intel from HBase to Cassandra
from cassandra.cluster import Cluster
import happybase

# Connect to HBase
hbase_conn = happybase.Connection('old-hbase-host')
threat_intel_table = hbase_conn.table('threatintel')

# Connect to Cassandra
cluster = Cluster(['metron-cassandra-dc1-service.metron.svc.cluster.local'])
session = cluster.connect('metron')

# Prepare insert statement
insert_stmt = session.prepare("""
    INSERT INTO threat_intel (indicator_type, indicator_value, timestamp, threat_score, source, metadata)
    VALUES (?, ?, ?, ?, ?, ?)
""")

# Migrate data
batch_size = 1000
batch = []

for key, data in threat_intel_table.scan():
    indicator_type, indicator_value = key.decode().split(':', 1)

    row = {
        'indicator_type': indicator_type,
        'indicator_value': indicator_value,
        'timestamp': data[b'cf:timestamp'].decode(),
        'threat_score': int(data[b'cf:score']),
        'source': data[b'cf:source'].decode(),
        'metadata': {k.decode(): v.decode() for k, v in data.items() if k.startswith(b'cf:meta')}
    }

    batch.append(row)

    if len(batch) >= batch_size:
        for row in batch:
            session.execute(insert_stmt, (
                row['indicator_type'],
                row['indicator_value'],
                row['timestamp'],
                row['threat_score'],
                row['source'],
                row['metadata']
            ))
        batch = []
        print(f"Migrated {batch_size} records")

# Flush remaining
for row in batch:
    session.execute(insert_stmt, (row['indicator_type'], row['indicator_value'], row['timestamp'], row['threat_score'], row['source'], row['metadata']))

print("Migration complete")
```

---

## Testing Strategy

### 1. Unit Testing

```bash
# Run unit tests for new Flink modules
cd metron-platform/metron-flink
mvn test

# Check coverage
mvn jacoco:report
```

### 2. Integration Testing

```bash
# Deploy test environment
kubectl create namespace metron-test
helm install metron-test ./metron-deployment/kubernetes/helm/metron-platform \
  --namespace metron-test \
  --set kafka.cluster.replicas=1 \
  --set elasticsearch.data.replicas=1

# Run integration tests
mvn verify -Pintegration-tests

# Inject test data
kubectl run kafka-producer --rm -it --image=confluentinc/cp-kafka:7.5.0 -- \
  kafka-console-producer --broker-list metron-kafka-kafka-bootstrap.metron-test:9092 --topic raw_bro < test-data/bro-sample.json
```

### 3. Performance Testing

```bash
# Inject high-volume test data
kubectl apply -f metron-deployment/kubernetes/examples/load-test-job.yaml

# Monitor performance
kubectl top pods -n metron
kubectl exec -it -n metron prometheus-0 -- promtool query instant \
  'rate(flink_taskmanager_job_task_numRecordsInPerSecond[5m])'
```

### 4. Chaos Testing

```bash
# Install Chaos Mesh
kubectl apply -f https://mirrors.chaos-mesh.org/v2.5.1/certs.yaml
kubectl apply -f https://mirrors.chaos-mesh.org/v2.5.1/chaos-mesh.yaml

# Inject pod failures
kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: kill-flink-taskmanager
  namespace: metron
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - metron
    labelSelectors:
      "component": "taskmanager"
  scheduler:
    cron: "@every 15m"
EOF
```

---

## Rollback Plan

### If Migration Fails

```bash
# Step 1: Stop new system
kubectl scale deployment --all --replicas=0 -n metron

# Step 2: Restart Storm topologies
storm activate enrichments
storm activate indexing
storm activate parsing

# Step 3: Restore Elasticsearch from snapshot
curl -X POST "localhost:9200/_snapshot/metron_backup/snapshot_$(date +%Y%m%d)/_restore"

# Step 4: Restore HBase from snapshot
hbase shell <<EOF
restore_snapshot 'enrichment_backup_$(date +%Y%m%d)'
restore_snapshot 'threatintel_backup_$(date +%Y%m%d)'
EOF

# Step 5: Verify old system is operational
curl http://localhost:8082/api/v1/about
```

---

## Post-Migration Validation

### 1. Data Integrity Checks

```bash
# Compare record counts
# Old Elasticsearch
curl -XGET 'old-es:9200/metron-*/_count'

# New Elasticsearch
NEW_ES_PASSWORD=$(kubectl get secret metron-elasticsearch-es-elastic-user -n metron -o jsonpath='{.data.elastic}' | base64 -d)
kubectl exec -it metron-elasticsearch-es-data-0 -n metron -- \
  curl -u elastic:$NEW_ES_PASSWORD https://localhost:9200/metron-*/_count

# Compare sample records
# (Manual spot-checking of parsed/enriched data)
```

### 2. Performance Validation

```bash
# Kafka consumer lag should be low
kubectl exec -it metron-kafka-kafka-0 -n metron -- \
  kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group metron-parsing-flink

# Flink metrics
kubectl port-forward -n metron svc/metron-parsing-rest 8081:8081 &
curl http://localhost:8081/jobs

# Elasticsearch indexing rate
kubectl exec -it metron-elasticsearch-es-data-0 -n metron -- \
  curl -u elastic:$NEW_ES_PASSWORD https://localhost:9200/_stats/indexing
```

### 3. Functional Testing

```bash
# Test end-to-end flow
# 1. Inject test message to Kafka
# 2. Verify parsing in enrichments topic
# 3. Verify enrichment in indexing topic
# 4. Verify document in Elasticsearch
# 5. Verify alert in Kibana

kubectl run test-producer --rm -it --image=confluentinc/cp-kafka:7.5.0 -- bash
# Inside pod:
echo '{"message": "test message", "timestamp": '$(date +%s)'}' | \
  kafka-console-producer --broker-list metron-kafka-kafka-bootstrap:9092 --topic raw_test
```

---

## Troubleshooting

### Common Issues

#### 1. Flink Job Won't Start

```bash
# Check logs
kubectl logs -n metron deployment/metron-parsing

# Common fixes:
# - Increase resources
# - Check Kafka connectivity
# - Verify JARs are loaded
```

#### 2. High Consumer Lag

```bash
# Increase parallelism
kubectl patch flinkdeployment metron-parsing -n metron --type merge -p '{
  "spec": {
    "job": {
      "parallelism": 8
    }
  }
}'

# Scale task managers
kubectl patch flinkdeployment metron-parsing -n metron --type merge -p '{
  "spec": {
    "taskManager": {
      "replicas": 10
    }
  }
}'
```

#### 3. Elasticsearch Indexing Slow

```bash
# Increase bulk size
# Update indexing job configuration

# Increase refresh interval
kubectl exec -it metron-elasticsearch-es-data-0 -n metron -- \
  curl -X PUT -u elastic:$ES_PASSWORD https://localhost:9200/metron-*/_settings -H 'Content-Type: application/json' -d '{
    "index": {
      "refresh_interval": "30s"
    }
  }'
```

---

## Timeline Summary

| Phase | Duration | Key Activities |
|-------|----------|----------------|
| 1: Infrastructure | 4 weeks | K8s cluster, operators, Kafka 3.x |
| 2: Storage | 4 weeks | Cassandra, ES 8.x, data migration |
| 3: Processing | 6 weeks | Flink deployment, parallel running, cutover |
| 4: UI/API | 2 weeks | Modern UIs, REST API migration |
| **Total** | **16 weeks** | Full migration with buffer time |

---

## Success Criteria

- ✅ All data migrated with <0.1% loss
- ✅ Performance improved by 2-5x (throughput and latency)
- ✅ No alerts missed during cutover
- ✅ All custom components migrated
- ✅ Monitoring and alerting operational
- ✅ Team trained on new platform

---

## Support

For migration support:
- GitHub Issues: https://github.com/apache/metron/issues
- Mailing List: dev@metron.apache.org
- Slack: #metron-migration
