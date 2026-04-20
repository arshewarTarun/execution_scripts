#!/usr/bin/env bash
# start_cluster.sh – Start a Spark Standalone cluster (master + one or more workers).
#
# Usage:
#   ./start_cluster.sh [OPTIONS]
#
# Options:
#   -m, --master-host <host>      Hostname/IP to bind the master to (default: localhost)
#   -M, --master-port <port>      Port for the Spark master service (default: 7077)
#   -u, --master-ui-port <port>   Port for the master Web UI (default: 8080)
#   -w, --workers <n>             Number of worker processes to start locally (default: 1)
#   -c, --worker-cores <n>        CPU cores per worker (default: all available)
#   -r, --worker-memory <mem>     Memory per worker, e.g. 4g (default: system decides)
#   -s, --spark-home <path>       SPARK_HOME directory (default: $SPARK_HOME env var)
#   -h, --help                    Show this help message
#
# Examples:
#   # Start master + 2 workers with 4 cores and 8 GB each
#   SPARK_HOME=/opt/spark ./start_cluster.sh --workers 2 --worker-cores 4 --worker-memory 8g
#
#   # Start master on a specific host
#   ./start_cluster.sh --master-host 192.168.1.10 --workers 1

set -euo pipefail

# ── defaults ───────────────────────────────────────────────────────────────────
MASTER_HOST="localhost"
MASTER_PORT=7077
MASTER_UI_PORT=8080
NUM_WORKERS=1
WORKER_CORES=""
WORKER_MEMORY=""

# ── helpers ────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

# ── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--master-host)     MASTER_HOST="$2";    shift 2 ;;
    -M|--master-port)     MASTER_PORT="$2";    shift 2 ;;
    -u|--master-ui-port)  MASTER_UI_PORT="$2"; shift 2 ;;
    -w|--workers)         NUM_WORKERS="$2";    shift 2 ;;
    -c|--worker-cores)    WORKER_CORES="$2";   shift 2 ;;
    -r|--worker-memory)   WORKER_MEMORY="$2";  shift 2 ;;
    -s|--spark-home)      SPARK_HOME="$2";     shift 2 ;;
    -h|--help)            usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── resolve SPARK_HOME ─────────────────────────────────────────────────────────
: "${SPARK_HOME:?SPARK_HOME is not set. Use --spark-home or export SPARK_HOME.}"
[[ -d "$SPARK_HOME" ]] || die "SPARK_HOME does not exist: $SPARK_HOME"

SBIN="${SPARK_HOME}/sbin"
[[ -x "${SBIN}/start-master.sh" ]] || die "Spark sbin scripts not found in ${SBIN}"

# ── start master ───────────────────────────────────────────────────────────────
echo "Starting Spark master on ${MASTER_HOST}:${MASTER_PORT} (UI: ${MASTER_UI_PORT}) …"
SPARK_MASTER_HOST="$MASTER_HOST" \
SPARK_MASTER_PORT="$MASTER_PORT" \
SPARK_MASTER_WEBUI_PORT="$MASTER_UI_PORT" \
"${SBIN}/start-master.sh"

MASTER_URL="spark://${MASTER_HOST}:${MASTER_PORT}"
echo "Master URL: ${MASTER_URL}"
echo "Master UI:  http://${MASTER_HOST}:${MASTER_UI_PORT}"

# ── start workers ──────────────────────────────────────────────────────────────
WORKER_OPTS=()
[[ -n "$WORKER_CORES" ]]  && WORKER_OPTS+=(-c "$WORKER_CORES")
[[ -n "$WORKER_MEMORY" ]] && WORKER_OPTS+=(-m "$WORKER_MEMORY")

echo "Starting ${NUM_WORKERS} worker(s) …"
for i in $(seq 1 "$NUM_WORKERS"); do
  echo "  Starting worker ${i}/${NUM_WORKERS} …"
  SPARK_WORKER_WEBUI_PORT=$(( 8081 + i - 1 )) \
  "${SBIN}/start-worker.sh" "${WORKER_OPTS[@]+"${WORKER_OPTS[@]}"}" "$MASTER_URL"
done

echo ""
echo "Spark standalone cluster is running."
echo "  Master:  ${MASTER_URL}"
echo "  Workers: ${NUM_WORKERS}"
echo ""
echo "To stop the cluster, run: ./stop_cluster.sh --spark-home ${SPARK_HOME}"
