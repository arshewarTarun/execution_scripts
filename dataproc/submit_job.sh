#!/usr/bin/env bash
# submit_job.sh – Submit a Spark/PySpark/Hadoop job to a Google Cloud Dataproc cluster.
#
# Usage:
#   ./submit_job.sh [OPTIONS] -- [JOB_ARGS]
#
# Prerequisites:
#   - gcloud CLI authenticated
#   - Required variables: GCP_PROJECT, GCP_REGION (or pass via flags)
#
# Options:
#   -p, --project <id>            GCP project ID (default: $GCP_PROJECT)
#   -r, --region <region>         GCP region (default: $GCP_REGION)
#   -n, --cluster-name <name>     Target Dataproc cluster name (required)
#   -t, --job-type <type>         Job type: spark | pyspark | hadoop | hive | pig | presto | spark-r | spark-sql
#                                 (default: spark)
#   -a, --app <path>              JAR / Python / script file (gs:// or local path)
#   -c, --class <main-class>      Main class (required for spark JAR jobs)
#       --jars <paths>            Comma-separated list of additional JARs (optional)
#       --files <paths>           Comma-separated list of files to stage (optional)
#       --py-files <paths>        Comma-separated Python dependency files (optional)
#       --archives <paths>        Comma-separated archives to stage (optional)
#   -e, --executor-memory <mem>   spark.executor.memory, e.g. 4g (optional)
#   -x, --num-executors <n>       spark.executor.instances (optional)
#       --property <key=value>    Additional Spark/job property (repeatable)
#   -l, --labels <key=value>      Labels for this job (repeatable)
#   -w, --wait                    Block until the job finishes (default: true)
#       --async                   Submit and return immediately (don't wait)
#   -h, --help                    Show this help message
#
# Everything after -- is passed as job arguments.
#
# Examples:
#   # Submit a PySpark job
#   GCP_PROJECT=my-project GCP_REGION=us-central1 \
#   ./submit_job.sh \
#     --cluster-name my-cluster \
#     --job-type pyspark \
#     --app gs://my-bucket/etl.py \
#     -- --date 2024-01-01
#
#   # Submit a Spark JAR job
#   ./submit_job.sh \
#     --project my-project --region us-central1 \
#     --cluster-name my-cluster \
#     --job-type spark \
#     --app gs://my-bucket/myapp.jar \
#     --class com.example.Main \
#     --executor-memory 4g \
#     --num-executors 8 \
#     --property spark.sql.shuffle.partitions=200

set -euo pipefail

# ── defaults ───────────────────────────────────────────────────────────────────
JOB_TYPE="spark"
CLUSTER_NAME=""
APP=""
MAIN_CLASS=""
EXTRA_JARS=""
EXTRA_FILES=""
PY_FILES=""
ARCHIVES=""
EXECUTOR_MEMORY=""
NUM_EXECUTORS=""
PROPERTIES=()
LABELS=()
WAIT_MODE="--wait"
JOB_ARGS=()

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
    -p|--project)          GCP_PROJECT="$2";      shift 2 ;;
    -r|--region)           GCP_REGION="$2";       shift 2 ;;
    -n|--cluster-name)     CLUSTER_NAME="$2";     shift 2 ;;
    -t|--job-type)         JOB_TYPE="$2";         shift 2 ;;
    -a|--app)              APP="$2";              shift 2 ;;
    -c|--class)            MAIN_CLASS="$2";       shift 2 ;;
       --jars)             EXTRA_JARS="$2";       shift 2 ;;
       --files)            EXTRA_FILES="$2";      shift 2 ;;
       --py-files)         PY_FILES="$2";         shift 2 ;;
       --archives)         ARCHIVES="$2";         shift 2 ;;
    -e|--executor-memory)  EXECUTOR_MEMORY="$2";  shift 2 ;;
    -x|--num-executors)    NUM_EXECUTORS="$2";    shift 2 ;;
       --property)         PROPERTIES+=("$2");    shift 2 ;;
    -l|--labels)           LABELS+=("$2");        shift 2 ;;
    -w|--wait)             WAIT_MODE="--wait";    shift ;;
       --async)            WAIT_MODE="--async";   shift ;;
    -h|--help)             usage ;;
    --) shift; JOB_ARGS=("$@"); break ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── validation ─────────────────────────────────────────────────────────────────
require_cmd gcloud

: "${GCP_PROJECT:?GCP_PROJECT is not set. Use --project or export GCP_PROJECT.}"
: "${GCP_REGION:?GCP_REGION is not set.  Use --region  or export GCP_REGION.}"
[[ -z "$CLUSTER_NAME" ]] && die "--cluster-name is required."

VALID_TYPES=("spark" "pyspark" "hadoop" "hive" "pig" "presto" "spark-r" "spark-sql")
VALID=false
for t in "${VALID_TYPES[@]}"; do [[ "$t" == "$JOB_TYPE" ]] && VALID=true && break; done
[[ "$VALID" == "false" ]] && die "Invalid --job-type '${JOB_TYPE}'. Valid: ${VALID_TYPES[*]}"

# ── build gcloud command ───────────────────────────────────────────────────────
CMD=(
  gcloud dataproc jobs submit "$JOB_TYPE"
  --project "$GCP_PROJECT"
  --region "$GCP_REGION"
  --cluster "$CLUSTER_NAME"
  "$WAIT_MODE"
)

[[ -n "$APP" ]]          && CMD+=("$APP")
[[ -n "$MAIN_CLASS" ]]   && CMD+=(--class "$MAIN_CLASS")
[[ -n "$EXTRA_JARS" ]]   && CMD+=(--jars "$EXTRA_JARS")
[[ -n "$EXTRA_FILES" ]]  && CMD+=(--files "$EXTRA_FILES")
[[ -n "$PY_FILES" ]]     && CMD+=(--py-files "$PY_FILES")
[[ -n "$ARCHIVES" ]]     && CMD+=(--archives "$ARCHIVES")

if [[ -n "$EXECUTOR_MEMORY" || -n "$NUM_EXECUTORS" ]]; then
  SPARK_PROPS=""
  [[ -n "$EXECUTOR_MEMORY" ]] && SPARK_PROPS+="spark:spark.executor.memory=${EXECUTOR_MEMORY},"
  [[ -n "$NUM_EXECUTORS" ]]   && SPARK_PROPS+="spark:spark.executor.instances=${NUM_EXECUTORS},"
  SPARK_PROPS="${SPARK_PROPS%,}"
  CMD+=(--properties "$SPARK_PROPS")
fi

for prop in "${PROPERTIES[@]+"${PROPERTIES[@]}"}"; do
  CMD+=(--properties "$prop")
done

if [[ ${#LABELS[@]} -gt 0 ]]; then
  LABEL_STR=$(IFS=,; echo "${LABELS[*]}")
  CMD+=(--labels "$LABEL_STR")
fi

if [[ ${#JOB_ARGS[@]} -gt 0 ]]; then
  CMD+=(-- "${JOB_ARGS[@]}")
fi

# ── print and run ──────────────────────────────────────────────────────────────
echo "Submitting ${JOB_TYPE} job to Dataproc cluster '${CLUSTER_NAME}' …"
echo "  Project: ${GCP_PROJECT}"
echo "  Region:  ${GCP_REGION}"
[[ -n "$APP" ]] && echo "  App:     ${APP}"
[[ -n "$MAIN_CLASS" ]] && echo "  Class:   ${MAIN_CLASS}"
echo ""
echo "Running: ${CMD[*]}"
echo ""
exec "${CMD[@]}"
