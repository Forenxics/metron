# Metron AI/ML Integration

This module provides AI/ML capabilities for advanced threat detection, anomaly analysis, and predictive security analytics.

## Overview

Modern Metron integrates multiple AI/ML frameworks to enhance threat detection:

- **TensorFlow**: Deep learning for sequential attack detection
- **PyTorch**: Neural networks for anomaly detection
- **Apache Spark MLlib**: Scalable ML for behavioral profiling
- **OpenCTI**: AI-powered threat intelligence enrichment
- **Flink ML**: Real-time anomaly detection in streams

## Use Cases

### 1. Anomaly Detection
- Network traffic anomalies
- User behavior anomalies (UEBA)
- Protocol anomalies
- DNS tunneling detection

### 2. Threat Classification
- Malware classification
- Phishing detection
- C2 communication detection
- DGA domain detection

### 3. Behavioral Profiling
- Baseline normal behavior
- Deviation scoring
- Peer group analysis
- Time-series forecasting

### 4. Predictive Analytics
- Attack path prediction
- Threat trend forecasting
- Risk scoring
- Incident prioritization

## Quick Examples

### Example 1: Real-Time Anomaly Detection with Flink ML

```java
// Flink job with isolation forest for anomaly detection
DataStream<NetworkEvent> events = env
    .addSource(new FlinkKafkaConsumer<>("network_events", schema, props));

// Feature extraction
DataStream<Features> features = events
    .map(event -> extractFeatures(event));

// Load pre-trained isolation forest model
IsolationForest model = IsolationForest.load("models/isolation_forest");

// Score events
DataStream<ScoredEvent> scored = features
    .map(f -> new ScoredEvent(f, model.score(f)));

// Alert on anomalies (score > threshold)
scored
    .filter(s -> s.score > 0.7)
    .addSink(new FlinkKafkaProducer<>("alerts", alertSchema, props));
```

### Example 2: LSTM for Sequential Attack Detection

```python
# Train LSTM model on sequence of events
import tensorflow as tf
from tensorflow import keras

# Model architecture
model = keras.Sequential([
    keras.layers.LSTM(128, return_sequences=True, input_shape=(None, 50)),
    keras.layers.Dropout(0.3),
    keras.layers.LSTM(64),
    keras.layers.Dropout(0.3),
    keras.layers.Dense(32, activation='relu'),
    keras.layers.Dense(1, activation='sigmoid')
])

model.compile(
    optimizer='adam',
    loss='binary_crossentropy',
    metrics=['accuracy', 'AUC']
)

# Train on historical attack sequences
model.fit(
    train_sequences,
    train_labels,
    epochs=50,
    batch_size=32,
    validation_split=0.2,
    callbacks=[
        keras.callbacks.EarlyStopping(patience=5),
        keras.callbacks.ModelCheckpoint('best_model.h5')
    ]
)

# Deploy to TensorFlow Serving
!saved_model_cli export --model_path ./best_model --export_dir ./serving_model
```

### Example 3: Spark MLlib for Behavioral Baselines

```python
# Spark job for building behavioral profiles
from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.clustering import KMeans

spark = SparkSession.builder.appName("ProfileBuilder").getOrCreate()

# Load historical data
df = spark.read.parquet("hdfs://namenode:9000/metron/enriched/*")

# Feature engineering
features = [
    'bytes_in', 'bytes_out', 'packets_in', 'packets_out',
    'connections_per_hour', 'unique_destinations',
    'port_diversity', 'protocol_diversity'
]

assembler = VectorAssembler(inputCols=features, outputCol="features")
feature_df = assembler.transform(df)

# Cluster entities into behavior groups
kmeans = KMeans(k=10, seed=42, featuresCol="features", predictionCol="cluster")
model = kmeans.fit(feature_df)

# Compute cluster statistics for anomaly detection
profiles = model.transform(feature_df) \
    .groupBy("cluster") \
    .agg({
        "bytes_in": "avg",
        "bytes_out": "avg",
        "connections_per_hour": "avg"
    })

# Save to Cassandra
profiles.write \
    .format("org.apache.spark.sql.cassandra") \
    .options(table="behavioral_profiles", keyspace="metron") \
    .mode("overwrite") \
    .save()
```

### Example 4: Autoencoder for Rare Event Detection

```python
# Autoencoder for detecting rare/novel attacks
import torch
import torch.nn as nn

class Autoencoder(nn.Module):
    def __init__(self, input_dim=100):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Linear(input_dim, 64),
            nn.ReLU(),
            nn.Linear(64, 32),
            nn.ReLU(),
            nn.Linear(32, 16)
        )
        self.decoder = nn.Sequential(
            nn.Linear(16, 32),
            nn.ReLU(),
            nn.Linear(32, 64),
            nn.ReLU(),
            nn.Linear(64, input_dim)
        )

    def forward(self, x):
        encoded = self.encoder(x)
        decoded = self.decoder(encoded)
        return decoded

# Train on normal data only
model = Autoencoder(input_dim=100)
criterion = nn.MSELoss()
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

for epoch in range(100):
    for batch in normal_data_loader:
        optimizer.zero_grad()
        reconstructed = model(batch)
        loss = criterion(reconstructed, batch)
        loss.backward()
        optimizer.step()

# Inference: high reconstruction error = anomaly
def detect_anomaly(event_features):
    reconstructed = model(event_features)
    error = torch.mean((reconstructed - event_features) ** 2)
    return error > threshold
```

### Example 5: OpenCTI AI-Powered Threat Intel

```python
# Integrate OpenCTI for AI-enhanced threat intelligence
from pycti import OpenCTIApiClient

# Connect to OpenCTI
opencti = OpenCTIApiClient(
    url='https://opencti.metron.local',
    token='your-api-token'
)

# Extract entities from unstructured threat report using NER
import spacy
nlp = spacy.load("en_core_web_lg")

threat_report = """
APT28 has been observed using domain example-malicious.com
for C2 communication on port 8443. The malware SHA256 is
abc123def456... and targets IP range 192.168.1.0/24.
"""

doc = nlp(threat_report)

# Extract IoCs
iocs = {
    'domains': [ent.text for ent in doc.ents if ent.label_ == 'DOMAIN'],
    'ips': [ent.text for ent in doc.ents if ent.label_ == 'IP'],
    'hashes': [ent.text for ent in doc.ents if ent.label_ == 'HASH']
}

# Create observables in OpenCTI
for domain in iocs['domains']:
    opencti.stix_domain_object.create(
        type="domain-name",
        value=domain,
        labels=["apt28", "c2"]
    )

# Query enrichment
threat_score = opencti.indicator.read(filters=[{
    "key": "pattern",
    "values": [f"domain-name:value = '{domain}'"]
}])
```

## Model Deployment

### TensorFlow Serving

```bash
# Deploy model to TensorFlow Serving
docker run -p 8501:8501 \
  --mount type=bind,source=/models/metron_lstm,target=/models/metron_lstm \
  -e MODEL_NAME=metron_lstm \
  tensorflow/serving

# Query model via REST
curl -X POST http://localhost:8501/v1/models/metron_lstm:predict \
  -d '{"instances": [[1.0, 2.0, 3.0, ...]]}'
```

### TorchServe

```bash
# Archive PyTorch model
torch-model-archiver \
  --model-name metron_autoencoder \
  --version 1.0 \
  --model-file model.py \
  --serialized-file autoencoder.pth \
  --handler custom_handler.py

# Start TorchServe
torchserve --start --model-store /models --models metron_autoencoder.mar

# Inference
curl -X POST http://localhost:8080/predictions/metron_autoencoder \
  -T input.json
```

### Kubeflow Deployment

```yaml
# KFServing InferenceService
apiVersion: serving.kubeflow.org/v1beta1
kind: InferenceService
metadata:
  name: metron-anomaly-detector
  namespace: metron
spec:
  predictor:
    tensorflow:
      storageUri: "s3://metron-models/isolation-forest"
      resources:
        requests:
          memory: 4Gi
          cpu: 2
        limits:
          memory: 8Gi
          cpu: 4
```

## Integration with Flink

```java
// Call TensorFlow Serving from Flink
public class MLScoringFunction extends AsyncFunction<Event, ScoredEvent> {

    private transient AsyncHttpClient httpClient;

    @Override
    public void asyncInvoke(Event event, ResultFuture<ScoredEvent> resultFuture) {
        String modelEndpoint = "http://tensorflow-serving:8501/v1/models/metron_lstm:predict";

        JSONObject payload = new JSONObject();
        payload.put("instances", extractFeatures(event));

        httpClient.preparePost(modelEndpoint)
            .setBody(payload.toString())
            .execute(new AsyncCompletionHandler<Response>() {
                @Override
                public Response onCompleted(Response response) {
                    double score = parseScore(response.getResponseBody());
                    resultFuture.complete(Collections.singleton(
                        new ScoredEvent(event, score)
                    ));
                    return response;
                }
            });
    }
}

// Use in Flink job
AsyncDataStream.unorderedWait(
    events,
    new MLScoringFunction(),
    10000,  // timeout
    TimeUnit.MILLISECONDS
)
```

## MLflow Experiment Tracking

```python
# Track experiments with MLflow
import mlflow
import mlflow.tensorflow

mlflow.set_tracking_uri("http://mlflow.metron.local:5000")
mlflow.set_experiment("threat-detection")

with mlflow.start_run():
    # Log parameters
    mlflow.log_param("model_type", "lstm")
    mlflow.log_param("hidden_units", 128)
    mlflow.log_param("learning_rate", 0.001)

    # Train model
    model.fit(train_data, train_labels, epochs=50)

    # Log metrics
    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("auc", auc)
    mlflow.log_metric("f1_score", f1)

    # Log model
    mlflow.tensorflow.log_model(model, "model")

    # Log artifacts
    mlflow.log_artifact("confusion_matrix.png")
```

## AutoML with Katib

```yaml
# Hyperparameter tuning with Katib
apiVersion: kubeflow.org/v1beta1
kind: Experiment
metadata:
  name: metron-lstm-tuning
  namespace: metron
spec:
  objective:
    type: maximize
    goal: 0.95
    objectiveMetricName: auc
  algorithm:
    algorithmName: random
  parameters:
    - name: learning_rate
      parameterType: double
      feasibleSpace:
        min: "0.0001"
        max: "0.01"
    - name: hidden_units
      parameterType: int
      feasibleSpace:
        min: "64"
        max: "256"
    - name: dropout
      parameterType: double
      feasibleSpace:
        min: "0.1"
        max: "0.5"
  trialTemplate:
    primaryContainerName: training
    trialSpec:
      apiVersion: batch/v1
      kind: Job
      spec:
        template:
          spec:
            containers:
              - name: training
                image: metron/lstm-training:latest
                command:
                  - "python"
                  - "train.py"
                  - "--learning-rate=${trialParameters.learningRate}"
                  - "--hidden-units=${trialParameters.hiddenUnits}"
                  - "--dropout=${trialParameters.dropout}"
```

## Explainability with SHAP

```python
# Explain model predictions
import shap

# Load model
model = keras.models.load_model('best_model.h5')

# Create SHAP explainer
explainer = shap.DeepExplainer(model, train_data[:100])

# Explain predictions for specific events
shap_values = explainer.shap_values(test_data[:10])

# Visualize
shap.summary_plot(shap_values, test_data[:10], feature_names=feature_names)
```

## Monitoring & Drift Detection

```python
# Monitor model performance and detect drift
from evidently import Dashboard
from evidently.tabs import DataDriftTab, CatTargetDriftTab

# Reference data (training set)
reference_data = pd.read_parquet("reference_data.parquet")

# Current production data
production_data = fetch_recent_predictions()

# Generate drift report
dashboard = Dashboard(tabs=[DataDriftTab(), CatTargetDriftTab()])
dashboard.calculate(reference_data, production_data, column_mapping=None)
dashboard.save("drift_report.html")

# Alert if drift detected
if dashboard.tabs[0].info.drift_detected:
    send_alert("Model drift detected - retraining recommended")
```

## Resources

- [TensorFlow Documentation](https://www.tensorflow.org/guide)
- [PyTorch Documentation](https://pytorch.org/docs/stable/index.html)
- [Spark MLlib Guide](https://spark.apache.org/docs/latest/ml-guide.html)
- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution guidelines.
