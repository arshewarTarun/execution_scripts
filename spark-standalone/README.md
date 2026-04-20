# Spark Standalone Execution Scripts

Shell scripts to manage a local/single-node **Spark Standalone** cluster and submit Spark applications.

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Apache Spark | Set `SPARK_HOME` to the Spark installation directory |
| Java 8 / 11 / 17 | Required by Spark |

Set `SPARK_HOME` before running any script:

```bash
export SPARK_HOME=/opt/spark   # or wherever Spark is installed
```

---

## Scripts

### `start_cluster.sh` – Start master + workers

Starts a Spark master process and one or more local worker processes.

```
Usage: ./start_cluster.sh [OPTIONS]

Options:
  -m, --master-host <host>      Hostname/IP for the master (default: localhost)
  -M, --master-port <port>      Master service port (default: 7077)
  -u, --master-ui-port <port>   Master Web UI port (default: 8080)
  -w, --workers <n>             Number of local workers (default: 1)
  -c, --worker-cores <n>        CPU cores per worker (default: all available)
  -r, --worker-memory <mem>     Memory per worker, e.g. 4g
  -s, --spark-home <path>       Override SPARK_HOME
  -h, --help                    Show help
```

**Examples:**

```bash
# Start 1 master + 2 workers (4 cores, 8 GB each)
./start_cluster.sh --workers 2 --worker-cores 4 --worker-memory 8g

# Bind master to a specific IP
./start_cluster.sh --master-host 192.168.1.10
```

---

### `stop_cluster.sh` – Stop all workers and master

```
Usage: ./stop_cluster.sh [OPTIONS]

Options:
  -s, --spark-home <path>   Override SPARK_HOME
  -h, --help                Show help
```

**Example:**

```bash
./stop_cluster.sh
```

---

### `submit_job.sh` – Submit a Spark application

Wraps `spark-submit` with sensible defaults for standalone mode.

```
Usage: ./submit_job.sh [OPTIONS] -- [APP_ARGS]

Options:
  -m, --master <url>              Spark master URL (default: spark://localhost:7077)
  -a, --app <path>                JAR or Python file (required)
  -c, --class <main-class>        Main class (required for JAR jobs)
  -n, --name <app-name>           Application name
  -e, --executor-cores <n>        Cores per executor (default: 1)
  -r, --executor-memory <mem>     Memory per executor (default: 1g)
  -x, --num-executors <n>         Number of executors (default: 2)
  -d, --deploy-mode <mode>        client | cluster (default: client)
  -s, --spark-home <path>         Override SPARK_HOME
      --conf <key=value>          Additional Spark conf (repeatable)
  -h, --help                      Show help
```

**Examples:**

```bash
# Submit a Python job
./submit_job.sh --app /path/to/etl.py

# Submit a JAR job with application arguments
./submit_job.sh \
  --app /path/to/myapp.jar \
  --class com.example.Main \
  --executor-memory 4g \
  --num-executors 4 \
  -- --date 2024-01-01 --env prod

# Extra Spark configuration
./submit_job.sh --app etl.py \
  --conf spark.sql.shuffle.partitions=200 \
  --conf spark.executor.extraJavaOptions="-XX:+UseG1GC"
```
