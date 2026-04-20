#!/usr/bin/env bash
# create_cluster.sh – Create a Google Cloud Dataproc cluster.
#
# Usage:
#   ./create_cluster.sh [OPTIONS]
#
# Prerequisites:
#   - gcloud CLI authenticated (run: gcloud auth login or use a service account)
#   - Required variables: GCP_PROJECT, GCP_REGION (or pass via flags)
#
# Options:
#   -p, --project <id>            GCP project ID (default: $GCP_PROJECT)
#   -r, --region <region>         GCP region, e.g. us-central1 (default: $GCP_REGION)
#   -z, --zone <zone>             GCP zone (optional; if omitted, auto-selected)
#   -n, --cluster-name <name>     Cluster name (required)
#   -i, --image-version <ver>     Dataproc image version (default: 2.1-debian11)
#   -m, --master-machine <type>   Master machine type (default: n1-standard-4)
#   -M, --master-disk-size <gb>   Master boot disk size in GB (default: 100)
#   -w, --num-workers <n>         Number of worker nodes (default: 2)
#       --worker-machine <type>   Worker machine type (default: n1-standard-4)
#       --worker-disk-size <gb>   Worker boot disk size in GB (default: 100)
#   -b, --bucket <name>           GCS staging bucket (optional)
#       --max-idle <duration>     Auto-delete after idle, e.g. 30m (optional)
#       --max-age <duration>      Max cluster age, e.g. 4h (optional)
#       --label <key=value>       Label to attach to the cluster (repeatable)
#       --property <key=value>    Dataproc/Spark property, e.g. spark:spark.executor.memory=4g (repeatable)
#   -h, --help                    Show this help message
#
# Examples:
#   GCP_PROJECT=my-project GCP_REGION=us-central1 \
#   ./create_cluster.sh --cluster-name my-cluster --num-workers 4
#
#   ./create_cluster.sh \
#     --project my-project --region us-central1 \
#     --cluster-name etl-cluster \
#     --image-version 2.1-debian11 \
#     --num-workers 4 \
#     --max-idle 30m \
#     --label env=prod --label team=data-eng \
#     --property spark:spark.executor.memory=4g

set -euo pipefail

# ── defaults ───────────────────────────────────────────────────────────────────
IMAGE_VERSION="2.1-debian11"
MASTER_MACHINE="n1-standard-4"
MASTER_DISK_SIZE=100
NUM_WORKERS=2
WORKER_MACHINE="n1-standard-4"
WORKER_DISK_SIZE=100
CLUSTER_NAME=""
BUCKET=""
ZONE=""
MAX_IDLE=""
MAX_AGE=""
LABELS=()
PROPERTIES=()

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
    -z|--zone)             ZONE="$2";             shift 2 ;;
    -n|--cluster-name)     CLUSTER_NAME="$2";     shift 2 ;;
    -i|--image-version)    IMAGE_VERSION="$2";    shift 2 ;;
    -m|--master-machine)   MASTER_MACHINE="$2";   shift 2 ;;
    -M|--master-disk-size) MASTER_DISK_SIZE="$2"; shift 2 ;;
    -w|--num-workers)      NUM_WORKERS="$2";      shift 2 ;;
       --worker-machine)   WORKER_MACHINE="$2";   shift 2 ;;
       --worker-disk-size) WORKER_DISK_SIZE="$2"; shift 2 ;;
    -b|--bucket)           BUCKET="$2";           shift 2 ;;
       --max-idle)         MAX_IDLE="$2";         shift 2 ;;
       --max-age)          MAX_AGE="$2";          shift 2 ;;
       --label)            LABELS+=("$2");        shift 2 ;;
       --property)         PROPERTIES+=("$2");    shift 2 ;;
    -h|--help)             usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── validation ─────────────────────────────────────────────────────────────────
require_cmd gcloud

: "${GCP_PROJECT:?GCP_PROJECT is not set. Use --project or export GCP_PROJECT.}"
: "${GCP_REGION:?GCP_REGION is not set.  Use --region  or export GCP_REGION.}"
[[ -z "$CLUSTER_NAME" ]] && die "--cluster-name is required."

# ── build gcloud command ───────────────────────────────────────────────────────
CMD=(
  gcloud dataproc clusters create "$CLUSTER_NAME"
  --project "$GCP_PROJECT"
  --region "$GCP_REGION"
  --image-version "$IMAGE_VERSION"
  --master-machine-type "$MASTER_MACHINE"
  --master-boot-disk-size "${MASTER_DISK_SIZE}GB"
  --num-workers "$NUM_WORKERS"
  --worker-machine-type "$WORKER_MACHINE"
  --worker-boot-disk-size "${WORKER_DISK_SIZE}GB"
)

[[ -n "$ZONE" ]]    && CMD+=(--zone "$ZONE")
[[ -n "$BUCKET" ]]  && CMD+=(--bucket "$BUCKET")
[[ -n "$MAX_IDLE" ]] && CMD+=(--max-idle "$MAX_IDLE")
[[ -n "$MAX_AGE" ]]  && CMD+=(--max-age "$MAX_AGE")

if [[ ${#LABELS[@]} -gt 0 ]]; then
  LABEL_STR=$(IFS=,; echo "${LABELS[*]}")
  CMD+=(--labels "$LABEL_STR")
fi

if [[ ${#PROPERTIES[@]} -gt 0 ]]; then
  PROP_STR=$(IFS=,; echo "${PROPERTIES[*]}")
  CMD+=(--properties "$PROP_STR")
fi

# ── print and run ──────────────────────────────────────────────────────────────
echo "Creating Dataproc cluster '${CLUSTER_NAME}' in ${GCP_PROJECT}/${GCP_REGION} …"
echo "  Image:   ${IMAGE_VERSION}"
echo "  Master:  ${MASTER_MACHINE} / ${MASTER_DISK_SIZE} GB"
echo "  Workers: ${NUM_WORKERS} × ${WORKER_MACHINE} / ${WORKER_DISK_SIZE} GB"
[[ -n "$MAX_IDLE" ]] && echo "  Max idle: ${MAX_IDLE}"
[[ -n "$MAX_AGE" ]]  && echo "  Max age:  ${MAX_AGE}"
echo ""
echo "Running: ${CMD[*]}"
echo ""
exec "${CMD[@]}"
