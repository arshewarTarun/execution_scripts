# Dataproc Execution Scripts

Shell scripts to manage **Google Cloud Dataproc** clusters and submit Spark/PySpark/Hadoop jobs via the `gcloud` CLI.

## Prerequisites

| Tool | Notes |
|------|-------|
| `gcloud` CLI | Install from https://cloud.google.com/sdk/docs/install |
| Authenticated session | Run `gcloud auth login` or use a service account via `GOOGLE_APPLICATION_CREDENTIALS` |

Set the following environment variables before running any script:

```bash
export GCP_PROJECT="my-gcp-project"
export GCP_REGION="us-central1"
```

---

## Scripts

### `create_cluster.sh` – Create a Dataproc cluster

```
Usage: ./create_cluster.sh [OPTIONS]

Options:
  -p, --project <id>            GCP project ID
  -r, --region <region>         GCP region
  -z, --zone <zone>             GCP zone (optional)
  -n, --cluster-name <name>     Cluster name (required)
  -i, --image-version <ver>     Dataproc image version (default: 2.1-debian11)
  -m, --master-machine <type>   Master machine type (default: n1-standard-4)
  -M, --master-disk-size <gb>   Master disk in GB (default: 100)
  -w, --num-workers <n>         Number of workers (default: 2)
      --worker-machine <type>   Worker machine type (default: n1-standard-4)
      --worker-disk-size <gb>   Worker disk in GB (default: 100)
  -b, --bucket <name>           GCS staging bucket
      --max-idle <duration>     Auto-delete after idle (e.g. 30m)
      --max-age <duration>      Max cluster lifetime (e.g. 4h)
      --label <key=value>       Cluster labels (repeatable)
      --property <key=value>    Dataproc/Spark properties (repeatable)
  -h, --help                    Show help
```

**Examples:**

```bash
# Create a basic 4-worker cluster that auto-deletes after 30 minutes idle
./create_cluster.sh \
  --cluster-name etl-cluster \
  --num-workers 4 \
  --max-idle 30m \
  --label env=prod

# Create a cluster with custom Spark properties
./create_cluster.sh \
  --cluster-name analytics \
  --num-workers 8 \
  --property spark:spark.executor.memory=8g \
  --property spark:spark.sql.shuffle.partitions=400
```

---

### `delete_cluster.sh` – Delete a Dataproc cluster

```
Usage: ./delete_cluster.sh [OPTIONS]

Options:
  -p, --project <id>          GCP project ID
  -r, --region <region>       GCP region
  -n, --cluster-name <name>   Cluster to delete (required)
  -y, --yes                   Skip confirmation prompt
  -h, --help                  Show help
```

**Example:**

```bash
./delete_cluster.sh --cluster-name etl-cluster --yes
```

---

### `submit_job.sh` – Submit a job to Dataproc

```
Usage: ./submit_job.sh [OPTIONS] -- [JOB_ARGS]

Options:
  -p, --project <id>            GCP project ID
  -r, --region <region>         GCP region
  -n, --cluster-name <name>     Target cluster (required)
  -t, --job-type <type>         spark | pyspark | hadoop | hive | pig | presto | spark-r | spark-sql
                                (default: spark)
  -a, --app <path>              JAR / Python / script path (gs:// or local)
  -c, --class <main-class>      Main class (required for spark JAR jobs)
      --jars <paths>            Additional JARs (comma-separated)
      --files <paths>           Files to stage (comma-separated)
      --py-files <paths>        Python dependency files (comma-separated)
      --archives <paths>        Archives to stage (comma-separated)
  -e, --executor-memory <mem>   spark.executor.memory (e.g. 4g)
  -x, --num-executors <n>       spark.executor.instances
      --property <key=value>    Additional job property (repeatable)
  -l, --labels <key=value>      Job labels (repeatable)
  -w, --wait                    Wait for job completion (default)
      --async                   Submit and return immediately
  -h, --help                    Show help
```

**Examples:**

```bash
# Submit a PySpark job
./submit_job.sh \
  --cluster-name my-cluster \
  --job-type pyspark \
  --app gs://my-bucket/etl.py \
  -- --date 2024-01-01

# Submit a Spark JAR job
./submit_job.sh \
  --cluster-name my-cluster \
  --job-type spark \
  --app gs://my-bucket/myapp.jar \
  --class com.example.Main \
  --executor-memory 4g \
  --num-executors 8

# Submit a Hive query
./submit_job.sh \
  --cluster-name my-cluster \
  --job-type hive \
  --app gs://my-bucket/query.hql
```
