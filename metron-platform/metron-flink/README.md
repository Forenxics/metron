# Metron Flink Integration

This module provides Apache Flink-based stream processing for Metron, replacing the legacy Storm implementation.

## Overview

Apache Flink offers several advantages over Storm:

- **Exactly-once semantics**: End-to-end consistency guarantees
- **Lower latency**: Sub-second processing with high throughput
- **Advanced state management**: RocksDB-backed state for large workloads
- **SQL/Table API**: Declarative stream processing
- **Built-in ML**: Flink ML for real-time anomaly detection
- **Kubernetes-native**: First-class support for cloud deployment
- **Active community**: Regular updates and security patches

## Modules

### metron-flink-common
Core abstractions, utilities, and shared code for all Flink jobs.

**Key Components:**
- `MetronDeserializationSchema`: Kafka to Metron message deserialization
- `MetronSerializationSchema`: Metron message to Kafka serialization
- `StellarProcessFunction`: Stellar DSL integration for Flink
- `MetronKeyedProcessFunction`: Base class for stateful processing

### metron-flink-parsing
Parsing layer that consumes raw sensor data from Kafka and produces normalized messages.

**Features:**
- All legacy parsers supported (Bro/Zeek, Snort, ASA, etc.)
- Parallel parsing with configurable parallelism
- Invalid message routing to error topics
- Metrics and monitoring

**Migration from Storm:**
- `ParserTopology` → `ParsingJob`
- Storm spouts → Flink Kafka sources
- Storm bolts → Flink map functions

### metron-flink-enrichment
Enrichment layer that augments parsed messages with threat intelligence, geo-location, and contextual data.

**Features:**
- Cassandra-backed threat intelligence (replaces HBase)
- Geo-IP enrichment via MaxMind
- DNS lookups with caching
- Stellar transformations
- Stateful enrichment with keyed state

**Migration from Storm:**
- `EnrichmentTopology` → `EnrichmentJob`
- HBase enrichment store → Cassandra enrichment store
- Storm state → Flink keyed state

### metron-flink-indexing
Indexing layer that writes enriched messages to Elasticsearch, HDFS, or other sinks.

**Features:**
- Elasticsearch 8.x bulk indexing
- HDFS writers (Parquet, ORC, JSON)
- Kafka output for downstream consumers
- Backpressure handling
- Index template management

**Migration from Storm:**
- `IndexingTopology` → `IndexingJob`
- Storm batching → Flink windowing
- Multiple sinks via Flink's SinkFunction interface

### metron-flink-profiler
Profiling layer that computes behavioral baselines and statistical profiles.

**Features:**
- Time-windowed aggregations
- Cassandra profile storage
- Flink ML anomaly detection
- Profile versioning
- Backfill support

**Migration from Storm:**
- `ProfilerTopology` → `ProfilerJob`
- Storm Tick Tuples → Flink timers
- Profile state → Flink value state

## Building

```bash
# Build all Flink modules
cd metron-platform/metron-flink
mvn clean package

# Build specific module
cd metron-flink-parsing
mvn clean package

# Skip tests
mvn clean package -DskipTests

# Build with Java 17
export JAVA_HOME=/path/to/java17
mvn clean package
```

## Running Locally

### Prerequisites
- Java 17+
- Apache Kafka 3.6+
- Flink 1.18+

### Start Flink Cluster

```bash
# Download Flink
wget https://dlcdn.apache.org/flink/flink-1.18.0/flink-1.18.0-bin-scala_2.12.tgz
tar -xzf flink-1.18.0-bin-scala_2.12.tgz
cd flink-1.18.0

# Start cluster
./bin/start-cluster.sh

# Verify (Web UI at http://localhost:8081)
./bin/flink list
```

### Submit Parsing Job

```bash
# Submit to local cluster
./bin/flink run \
  -c org.apache.metron.flink.parsing.ParsingJob \
  /path/to/metron-flink-parsing.jar \
  --kafka.bootstrap.servers localhost:9092 \
  --input.topic raw_bro \
  --output.topic enrichments \
  --parser.type bro \
  --parallelism 4

# Submit with custom configuration
./bin/flink run \
  -c org.apache.metron.flink.parsing.ParsingJob \
  /path/to/metron-flink-parsing.jar \
  --config /path/to/parsing-config.json
```

## Running on Kubernetes

### Deploy via Flink Kubernetes Operator

```bash
# Install operator
kubectl create -f https://github.com/apache/flink-kubernetes-operator/releases/download/release-1.7.0/flink-kubernetes-operator-1.7.0.yaml

# Deploy parsing job
kubectl apply -f kubernetes/flink-parsing-job.yaml

# Check status
kubectl get flinkdeployment
kubectl logs deployment/metron-parsing

# Scale task managers
kubectl patch flinkdeployment metron-parsing \
  --type merge -p '{"spec":{"taskManager":{"replicas":10}}}'
```

### Deploy via Helm

```bash
helm install metron-flink metron/metron-platform \
  --set flink.enabled=true \
  --set flink.jobs.parsing.parallelism=8
```

## Configuration

### Parsing Job Configuration

```json
{
  "kafka": {
    "bootstrap.servers": "kafka:9092",
    "group.id": "metron-parsing",
    "auto.offset.reset": "latest"
  },
  "input": {
    "topic": "raw_bro",
    "parallelism": 4
  },
  "output": {
    "topic": "enrichments",
    "parallelism": 4
  },
  "parser": {
    "type": "bro",
    "config": {
      "fieldTransformations": [
        {
          "input": "timestamp",
          "transformation": "STELLAR",
          "output": "timestamp",
          "config": {
            "expression": "TO_EPOCH_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss')"
          }
        }
      ]
    }
  },
  "errorTopic": "parser_errors",
  "metrics": {
    "enabled": true,
    "interval": 60
  }
}
```

### Enrichment Job Configuration

```json
{
  "kafka": {
    "bootstrap.servers": "kafka:9092",
    "group.id": "metron-enrichment"
  },
  "input": {
    "topic": "enrichments",
    "parallelism": 4
  },
  "output": {
    "topic": "indexing",
    "parallelism": 4
  },
  "enrichment": {
    "cassandra": {
      "contactPoints": ["cassandra:9042"],
      "keyspace": "metron",
      "threatIntelTable": "threat_intel",
      "enrichmentTable": "enrichment_data"
    },
    "geo": {
      "enabled": true,
      "database": "/opt/maxmind/GeoLite2-City.mmdb"
    },
    "stellar": {
      "config": {
        "expressions": [
          "is_alert := threat_score > 70",
          "severity := if is_alert then 'high' else 'low'"
        ]
      }
    }
  },
  "caching": {
    "enabled": true,
    "ttl": 3600,
    "maxSize": 100000
  }
}
```

### Indexing Job Configuration

```json
{
  "kafka": {
    "bootstrap.servers": "kafka:9092",
    "group.id": "metron-indexing"
  },
  "input": {
    "topic": "indexing",
    "parallelism": 4
  },
  "sinks": [
    {
      "type": "elasticsearch",
      "config": {
        "hosts": ["https://elasticsearch:9200"],
        "username": "elastic",
        "password": "${ES_PASSWORD}",
        "index": "metron-%{sensor_type}-%{+yyyy.MM.dd}",
        "bulkSize": 1000,
        "bulkFlushInterval": 5000,
        "parallelism": 4
      }
    },
    {
      "type": "hdfs",
      "config": {
        "path": "hdfs://namenode:9000/metron/indexed",
        "format": "parquet",
        "compression": "snappy",
        "rollingPolicy": {
          "type": "time",
          "interval": "1h"
        },
        "parallelism": 2
      }
    }
  ]
}
```

## Migration Guide

### Storm to Flink Mapping

| Storm Concept | Flink Equivalent | Notes |
|---------------|------------------|-------|
| Topology | Job/Application | Flink uses "job" terminology |
| Spout | SourceFunction | Flink sources are more flexible |
| Bolt | ProcessFunction | Flink has richer function types |
| Tuple | POJO/DataStream<T> | Flink uses type-safe objects |
| Tick Tuple | Timer | Flink timers are event/processing time based |
| State | Keyed State | Flink state is more robust (checkpointing) |
| Trident | Table API/SQL | Flink's Table API is more mature |
| Guaranteed Processing | Exactly-Once | Flink provides stronger guarantees |

### Code Migration Example

**Storm ParserBolt:**
```java
public class ParserBolt extends BaseRichBolt {
    @Override
    public void execute(Tuple input) {
        String raw = input.getStringByField("message");
        JSONObject parsed = parser.parse(raw);
        collector.emit(new Values(parsed));
        collector.ack(input);
    }
}
```

**Flink ParserFunction:**
```java
public class ParserFunction extends ProcessFunction<String, JSONObject> {
    @Override
    public void processElement(String raw, Context ctx, Collector<JSONObject> out) {
        try {
            JSONObject parsed = parser.parse(raw);
            out.collect(parsed);
        } catch (Exception e) {
            ctx.output(errorTag, raw);
        }
    }
}
```

### State Migration

**Storm State:**
```java
public class EnrichmentBolt extends BaseStatefulBolt<KeyValueState<String, String>> {
    @Override
    public void execute(Tuple input) {
        String key = input.getStringByField("ip");
        String cached = state.get(key);
        // ...
    }
}
```

**Flink Keyed State:**
```java
public class EnrichmentFunction extends KeyedProcessFunction<String, Message, Message> {
    private ValueState<String> cacheState;

    @Override
    public void open(Configuration parameters) {
        cacheState = getRuntimeContext().getState(
            new ValueStateDescriptor<>("cache", String.class));
    }

    @Override
    public void processElement(Message msg, Context ctx, Collector<Message> out) {
        String cached = cacheState.value();
        // ...
    }
}
```

## Performance Tuning

### Parallelism
- Set based on Kafka partition count (typically 1-2x partitions)
- Parsing: High parallelism (4-16)
- Enrichment: Medium parallelism (2-8)
- Indexing: Match sink capacity (2-8)

### Checkpointing
- Interval: 60-300 seconds for most workloads
- Timeout: 10 minutes
- Min pause between checkpoints: 30 seconds
- Aligned checkpoints for exactly-once

### State Backend
- RocksDB for large state (>1GB)
- Heap state for small state (<1GB)
- Incremental checkpoints for RocksDB

### Network Buffers
- Default: 2048 buffers
- High throughput: 4096-8192 buffers
- Memory per buffer: 32KB

### JVM Options
```bash
-Xmx4g -Xms4g  # Heap size (task manager)
-XX:+UseG1GC  # G1 garbage collector
-XX:MaxGCPauseMillis=200  # GC pause target
```

## Monitoring

### Flink Web UI
- Job graph visualization
- Task metrics (records/sec, latency)
- Backpressure monitoring
- Checkpoint statistics

### Prometheus Metrics
```yaml
# Example Prometheus query
rate(flink_taskmanager_job_task_numRecordsInPerSecond[5m])
```

### Grafana Dashboards
- Pre-built dashboards in `grafana/`
- Flink job overview
- Kafka consumer lag
- Task manager resources

### Logging
```properties
# log4j2.properties
rootLogger.level = INFO
logger.flink.name = org.apache.flink
logger.flink.level = INFO
logger.metron.name = org.apache.metron
logger.metron.level = DEBUG
```

## Testing

### Unit Tests
```bash
mvn test
```

### Integration Tests
```bash
# Requires Kafka and Flink
mvn verify -Pintegration-tests
```

### Local Testing with Mini Cluster
```java
@Test
public void testParsingJob() {
    StreamExecutionEnvironment env = StreamExecutionEnvironment.createLocalEnvironment();
    // ... configure job
    env.execute();
}
```

## Troubleshooting

### Job Not Starting
- Check Flink logs: `kubectl logs deployment/metron-parsing`
- Verify Kafka connectivity: `kafka-broker-api-versions --bootstrap-server kafka:9092`
- Check resource limits: `kubectl top pods`

### High Backpressure
- Increase parallelism
- Tune sink batch sizes
- Check downstream bottlenecks (Elasticsearch indexing rate)

### Checkpoint Failures
- Increase checkpoint timeout
- Check state size (large state → slow checkpoints)
- Verify checkpoint storage (S3/HDFS accessibility)

### Out of Memory
- Increase task manager memory
- Reduce state size (use timers to clean up old state)
- Enable RocksDB state backend

## FAQ

**Q: Can I run Storm and Flink jobs in parallel during migration?**
A: Yes, use separate Kafka consumer groups. This allows gradual cutover.

**Q: How do I migrate existing Storm state to Flink?**
A: Export Storm state to Kafka/Cassandra, then load into Flink state on startup.

**Q: What's the performance improvement?**
A: Typically 2-5x throughput with lower latency (p99 <100ms vs Storm's 500ms).

**Q: Is Stellar DSL supported?**
A: Yes, via `StellarProcessFunction` in metron-flink-common.

**Q: Can I use Flink SQL for parsing?**
A: Yes, Flink SQL is supported for simple parsing. Complex parsers use DataStream API.

## Resources

- [Flink Documentation](https://nightlies.apache.org/flink/flink-docs-release-1.18/)
- [Flink Training](https://flink.apache.org/training.html)
- [Metron Modernization Guide](../../MODERNIZATION_GUIDE.md)
- [Storm to Flink Migration](https://flink.apache.org/news/2015/01/21/storm-compatibility.html)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution guidelines.

## License

Apache License 2.0
