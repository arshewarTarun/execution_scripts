#!/usr/bin/env bash
# submit_job.sh – Submit a Spark application to a Standalone cluster via spark-submit.
#
# Usage:
#   ./submit_job.sh [OPTIONS] -- [EXTRA_SPARK_ARGS]
#
# Options:
#   -m, --master <url>              Spark master URL (default: spark://localhost:7077)
#   -a, --app <path>                Path to application JAR / Python file (required)
#   -c, --class <main-class>        Main class (required for JAR jobs)
#   -n, --name <app-name>           Application name (default: basename of app file)
#   -e, --executor-cores <n>        Cores per executor (default: 1)
#   -r, --executor-memory <mem>     Memory per executor, e.g. 2g (default: 1g)
#   -x, --num-executors <n>         Number of executors (default: 2)
#   -d, --deploy-mode <mode>        client | cluster (default: client)
#   -s, --spark-home <path>         SPARK_HOME directory (default: $SPARK_HOME)
#       --conf <key=value>          Additional Spark configuration (repeatable)
#   -h, --help                      Show this help message
#
# Everything after -- is passed verbatim to spark-submit (e.g. application args).
#
# Examples:
#   # Submit a Python app
#   ./submit_job.sh --app /path/to/my_etl.py --master spark://localhost:7077
#
#   # Submit a JAR with extra app arguments
#   ./submit_job.sh \
#     --app /path/to/myapp.jar \
#     --class com.example.Main \
#     --executor-memory 4g \
#     --num-executors 4 \
#     -- --date 2024-01-01 --env prod
#
#   # Pass extra Spark confs
#   ./submit_job.sh --app myapp.py \
#     --conf spark.sql.shuffle.partitions=200 \
#     --conf spark.executor.extraJavaOptions="-XX:+UseG1GC"

set -euo pipefail

# ── defaults ───────────────────────────────────────────────────────────────────
MASTER="spark://localhost:7077"
APP=""
MAIN_CLASS=""
APP_NAME=""
EXECUTOR_CORES=1
EXECUTOR_MEMORY="1g"
NUM_EXECUTORS=2
DEPLOY_MODE="client"
EXTRA_CONFS=()
APP_ARGS=()

# ── helpers ────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed."; }

# ── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--master)           MASTER="$2";          shift 2 ;;
    -a|--app)              APP="$2";             shift 2 ;;
    -c|--class)            MAIN_CLASS="$2";      shift 2 ;;
    -n|--name)             APP_NAME="$2";        shift 2 ;;
    -e|--executor-cores)   EXECUTOR_CORES="$2";  shift 2 ;;
    -r|--executor-memory)  EXECUTOR_MEMORY="$2"; shift 2 ;;
    -x|--num-executors)    NUM_EXECUTORS="$2";   shift 2 ;;
    -d|--deploy-mode)      DEPLOY_MODE="$2";     shift 2 ;;
    -s|--spark-home)       SPARK_HOME="$2";      shift 2 ;;
       --conf)             EXTRA_CONFS+=("$2");  shift 2 ;;
    -h|--help)             usage ;;
    --) shift; APP_ARGS=("$@"); break ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── resolve SPARK_HOME ─────────────────────────────────────────────────────────
: "${SPARK_HOME:?SPARK_HOME is not set. Use --spark-home or export SPARK_HOME.}"
[[ -d "$SPARK_HOME" ]] || die "SPARK_HOME does not exist: $SPARK_HOME"

SPARK_SUBMIT="${SPARK_HOME}/bin/spark-submit"
[[ -x "$SPARK_SUBMIT" ]] || die "spark-submit not found at: ${SPARK_SUBMIT}"

# ── validation ─────────────────────────────────────────────────────────────────
[[ -z "$APP" ]] && die "--app is required."
[[ "$DEPLOY_MODE" == "client" || "$DEPLOY_MODE" == "cluster" ]] \
  || die "--deploy-mode must be 'client' or 'cluster'."

[[ -z "$APP_NAME" ]] && APP_NAME="$(basename "$APP" | sed 's/\.[^.]*$//')"

# ── build spark-submit command ─────────────────────────────────────────────────
CMD=(
  "$SPARK_SUBMIT"
  --master "$MASTER"
  --deploy-mode "$DEPLOY_MODE"
  --name "$APP_NAME"
  --executor-cores "$EXECUTOR_CORES"
  --executor-memory "$EXECUTOR_MEMORY"
  --num-executors "$NUM_EXECUTORS"
)

[[ -n "$MAIN_CLASS" ]] && CMD+=(--class "$MAIN_CLASS")

for conf in "${EXTRA_CONFS[@]+"${EXTRA_CONFS[@]}"}"; do
  CMD+=(--conf "$conf")
done

CMD+=("$APP")
CMD+=("${APP_ARGS[@]+"${APP_ARGS[@]}"}")

# ── print and run ──────────────────────────────────────────────────────────────
echo "Submitting Spark job to ${MASTER} …"
echo "  App:     ${APP}"
[[ -n "$MAIN_CLASS" ]] && echo "  Class:   ${MAIN_CLASS}"
echo "  Name:    ${APP_NAME}"
echo "  Mode:    ${DEPLOY_MODE}"
echo "  Executors: ${NUM_EXECUTORS} × ${EXECUTOR_CORES} cores / ${EXECUTOR_MEMORY}"
echo ""
echo "Running: ${CMD[*]}"
echo ""
exec "${CMD[@]}"
