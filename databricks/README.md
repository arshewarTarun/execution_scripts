# Databricks Execution Scripts

Shell scripts to interact with Databricks workspaces via the **Jobs API 2.1** and the `runs/submit` endpoint.

## Prerequisites

| Tool | Purpose |
|------|---------|
| `curl` | HTTP calls to the Databricks REST API |
| `jq` | JSON parsing / construction |
| `python3` | URL-encoding job names in `run_job.sh` |

Set the following environment variables before running any script:

```bash
export DATABRICKS_HOST="https://<workspace>.azuredatabricks.net"
export DATABRICKS_TOKEN="dapi..."          # personal-access token or SP OAuth token
```

---

## Scripts

### `run_job.sh` – Trigger an existing job

Triggers a run for an existing Databricks job (by ID or name) and optionally waits for completion.

```
Usage: ./run_job.sh [OPTIONS]

Options:
  -j, --job-id <id>         Existing job ID to trigger
  -n, --job-name <name>     Look up job ID by name
  -p, --params <json>       Notebook/task parameters as a JSON string
  -w, --wait                Block until the run finishes
  -t, --timeout <seconds>   Polling timeout (default: 3600)
  -h, --help                Show help
```

**Examples:**

```bash
# Trigger job by ID and wait
./run_job.sh --job-id 42 --wait

# Trigger job by name with parameters
./run_job.sh --job-name "nightly_etl" \
             --params '{"date":"2024-01-01","env":"prod"}' \
             --wait
```

---

### `submit_notebook.sh` – Run a notebook as a one-time run

Submits a notebook to run immediately on an existing or a new ephemeral cluster.

```
Usage: ./submit_notebook.sh [OPTIONS]

Options:
  -n, --notebook-path <path>     Workspace path to the notebook (required)
  -c, --cluster-id <id>          Existing cluster ID
      --new-cluster <json>       New-cluster specification JSON
  -p, --params <json>            Notebook base parameters
  -r, --run-name <name>          Human-readable run name
  -w, --wait                     Block until the run finishes
  -t, --timeout <seconds>        Polling timeout (default: 3600)
  -h, --help                     Show help
```

**Examples:**

```bash
# Run a notebook on an existing cluster
./submit_notebook.sh \
  --notebook-path /Shared/etl/transform \
  --cluster-id 1234-567890-abc12345 \
  --params '{"date":"2024-01-01"}' \
  --wait

# Run a notebook on a new ephemeral cluster
./submit_notebook.sh \
  --notebook-path /Shared/etl/transform \
  --new-cluster '{"num_workers":4,"spark_version":"14.3.x-scala2.12","node_type_id":"m5d.xlarge"}' \
  --wait
```
