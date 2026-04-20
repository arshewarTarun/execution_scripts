#!/usr/bin/env bash
# delete_cluster.sh – Delete a Google Cloud Dataproc cluster.
#
# Usage:
#   ./delete_cluster.sh [OPTIONS]
#
# Options:
#   -p, --project <id>          GCP project ID (default: $GCP_PROJECT)
#   -r, --region <region>       GCP region (default: $GCP_REGION)
#   -n, --cluster-name <name>   Cluster name to delete (required)
#   -y, --yes                   Skip confirmation prompt
#   -h, --help                  Show this help message
#
# Examples:
#   GCP_PROJECT=my-project GCP_REGION=us-central1 \
#   ./delete_cluster.sh --cluster-name my-cluster --yes

set -euo pipefail

# ── defaults ───────────────────────────────────────────────────────────────────
CLUSTER_NAME=""
SKIP_CONFIRM=false

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
    -p|--project)       GCP_PROJECT="$2";  shift 2 ;;
    -r|--region)        GCP_REGION="$2";   shift 2 ;;
    -n|--cluster-name)  CLUSTER_NAME="$2"; shift 2 ;;
    -y|--yes)           SKIP_CONFIRM=true; shift ;;
    -h|--help)          usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── validation ─────────────────────────────────────────────────────────────────
require_cmd gcloud

: "${GCP_PROJECT:?GCP_PROJECT is not set. Use --project or export GCP_PROJECT.}"
: "${GCP_REGION:?GCP_REGION is not set.  Use --region  or export GCP_REGION.}"
[[ -z "$CLUSTER_NAME" ]] && die "--cluster-name is required."

# ── confirmation ───────────────────────────────────────────────────────────────
if [[ "$SKIP_CONFIRM" == "false" ]]; then
  read -r -p "Delete Dataproc cluster '${CLUSTER_NAME}' in ${GCP_PROJECT}/${GCP_REGION}? [y/N] " REPLY
  [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

# ── delete cluster ─────────────────────────────────────────────────────────────
echo "Deleting cluster '${CLUSTER_NAME}' …"
exec gcloud dataproc clusters delete "$CLUSTER_NAME" \
  --project "$GCP_PROJECT" \
  --region "$GCP_REGION" \
  --quiet
