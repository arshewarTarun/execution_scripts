# execution_scripts

Shell scripts for submitting and managing Spark workloads across multiple execution engines.

## Supported Engines

| Engine | Directory | Description |
|--------|-----------|-------------|
| **Databricks** | [`databricks/`](databricks/) | Trigger existing jobs or run notebooks via the Databricks Jobs API 2.1 |
| **Spark Standalone** | [`spark-standalone/`](spark-standalone/) | Start/stop a local Spark cluster and submit jobs via `spark-submit` |
| **Google Cloud Dataproc** | [`dataproc/`](dataproc/) | Create/delete Dataproc clusters and submit Spark/PySpark/Hadoop jobs via `gcloud` |

## Quick Start

### Databricks

```bash
export DATABRICKS_HOST="https://<workspace>.azuredatabricks.net"
export DATABRICKS_TOKEN="dapi..."

# Trigger an existing job and wait for completion
./databricks/run_job.sh --job-id 42 --wait

# Run a notebook once on an existing cluster
./databricks/submit_notebook.sh \
  --notebook-path /Shared/etl/my_notebook \
  --cluster-id <cluster-id> \
  --wait
```

### Spark Standalone

```bash
export SPARK_HOME=/opt/spark

# Start master + 2 workers
./spark-standalone/start_cluster.sh --workers 2 --worker-cores 4 --worker-memory 8g

# Submit a PySpark job
./spark-standalone/submit_job.sh --app /path/to/etl.py

# Stop the cluster
./spark-standalone/stop_cluster.sh
```

### Google Cloud Dataproc

```bash
export GCP_PROJECT="my-gcp-project"
export GCP_REGION="us-central1"

# Create a cluster
./dataproc/create_cluster.sh --cluster-name my-cluster --num-workers 4

# Submit a PySpark job
./dataproc/submit_job.sh \
  --cluster-name my-cluster \
  --job-type pyspark \
  --app gs://my-bucket/etl.py \
  -- --date 2024-01-01

# Delete the cluster
./dataproc/delete_cluster.sh --cluster-name my-cluster --yes
```

## Repository Structure

```
execution_scripts/
├── databricks/
│   ├── README.md
│   ├── run_job.sh          # Trigger an existing Databricks job
│   └── submit_notebook.sh  # Run a notebook as a one-time run
├── spark-standalone/
│   ├── README.md
│   ├── start_cluster.sh    # Start Spark master + workers
│   ├── stop_cluster.sh     # Stop the cluster
│   └── submit_job.sh       # Submit a job via spark-submit
└── dataproc/
    ├── README.md
    ├── create_cluster.sh   # Create a Dataproc cluster
    ├── delete_cluster.sh   # Delete a Dataproc cluster
    └── submit_job.sh       # Submit a job to Dataproc
```

For engine-specific usage and options, refer to the README in each subdirectory.