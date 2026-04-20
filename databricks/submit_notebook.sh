#!/usr/bin/env bash
# submit_notebook.sh – Run a Databricks notebook as a one-time job run.
#
# Usage:
#   ./submit_notebook.sh [OPTIONS]
#
# Required environment variables (or pass via flags):
#   DATABRICKS_HOST   – Workspace URL, e.g. https://<workspace>.azuredatabricks.net
#   DATABRICKS_TOKEN  – Personal-access token (or SP OAuth token)
#
# Options:
#   -n, --notebook-path <path>     Absolute workspace path to the notebook (required)
#   -c, --cluster-id <id>          Existing cluster ID to run on
#       --new-cluster <json>       New-cluster spec JSON (mutually exclusive with -c)
#   -p, --params <json>            Notebook parameters as a JSON object (optional)
#   -r, --run-name <name>          Human-readable run name (optional)
#   -w, --wait                     Block until the run finishes and exit with its result code
#   -t, --timeout <seconds>        Polling timeout when --wait is set (default: 3600)
#   -h, --help                     Show this help message
#
# Examples:
#   DATABRICKS_HOST=https://adb-xxx.azuredatabricks.net \
#   DATABRICKS_TOKEN=dapi... \
#   ./submit_notebook.sh \
#     --notebook-path /Shared/etl/my_notebook \
#     --cluster-id 1234-567890-abc12345 \
#     --params '{"env":"prod","date":"2024-01-01"}' \
#     --wait

set -euo pipefail

# ── defaults ───────────────────────────────────────────────────────────────────
WAIT=false
TIMEOUT=3600
POLL_INTERVAL=15
NOTEBOOK_PATH=""
CLUSTER_ID=""
NEW_CLUSTER_JSON=""
PARAMS=""
RUN_NAME="notebook_run_$(date +%Y%m%d_%H%M%S)"

# ── helpers ────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed."; }

api_call() {
  local method="$1" path="$2" data="${3:-}"
  local url="${DATABRICKS_HOST%/}/api/2.1${path}"
  if [[ -n "$data" ]]; then
    curl -sSf -X "$method" \
      -H "Authorization: Bearer ${DATABRICKS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$data" "$url"
  else
    curl -sSf -X "$method" \
      -H "Authorization: Bearer ${DATABRICKS_TOKEN}" \
      "$url"
  fi
}

# ── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--notebook-path)  NOTEBOOK_PATH="$2";    shift 2 ;;
    -c|--cluster-id)     CLUSTER_ID="$2";       shift 2 ;;
       --new-cluster)    NEW_CLUSTER_JSON="$2"; shift 2 ;;
    -p|--params)         PARAMS="$2";           shift 2 ;;
    -r|--run-name)       RUN_NAME="$2";         shift 2 ;;
    -w|--wait)           WAIT=true;             shift   ;;
    -t|--timeout)        TIMEOUT="$2";          shift 2 ;;
    -h|--help)           usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── validation ─────────────────────────────────────────────────────────────────
require_cmd curl
require_cmd jq

[[ -z "${DATABRICKS_HOST:-}" ]]  && die "DATABRICKS_HOST is not set."
[[ -z "${DATABRICKS_TOKEN:-}" ]] && die "DATABRICKS_TOKEN is not set."
[[ -z "$NOTEBOOK_PATH" ]] && die "--notebook-path is required."
[[ -n "$CLUSTER_ID" && -n "$NEW_CLUSTER_JSON" ]] && die "--cluster-id and --new-cluster are mutually exclusive."
[[ -z "$CLUSTER_ID" && -z "$NEW_CLUSTER_JSON" ]] && die "Provide --cluster-id or --new-cluster."

# ── build cluster spec ─────────────────────────────────────────────────────────
if [[ -n "$CLUSTER_ID" ]]; then
  CLUSTER_SPEC="{\"existing_cluster_id\": \"${CLUSTER_ID}\"}"
else
  CLUSTER_SPEC="{\"new_cluster\": ${NEW_CLUSTER_JSON}}"
fi

# ── build notebook task ────────────────────────────────────────────────────────
NOTEBOOK_TASK="{\"notebook_path\": \"${NOTEBOOK_PATH}\""
if [[ -n "$PARAMS" ]]; then
  NOTEBOOK_TASK="${NOTEBOOK_TASK}, \"base_parameters\": ${PARAMS}"
fi
NOTEBOOK_TASK="${NOTEBOOK_TASK}}"

# ── assemble payload ───────────────────────────────────────────────────────────
PAYLOAD=$(jq -n \
  --arg run_name "$RUN_NAME" \
  --argjson cluster_spec "$CLUSTER_SPEC" \
  --argjson notebook_task "$NOTEBOOK_TASK" \
  '$cluster_spec + {run_name: $run_name, notebook_task: $notebook_task}')

# ── submit run ─────────────────────────────────────────────────────────────────
echo "Submitting notebook run: '${RUN_NAME}' …"
echo "  Notebook: ${NOTEBOOK_PATH}"
RUN_RESPONSE=$(api_call POST "/jobs/runs/submit" "$PAYLOAD")
RUN_ID=$(echo "$RUN_RESPONSE" | jq -r '.run_id')
echo "Run ID: ${RUN_ID}"
echo "Run URL: ${DATABRICKS_HOST%/}/#job/runs/${RUN_ID}"

# ── optional wait ──────────────────────────────────────────────────────────────
if [[ "$WAIT" == "true" ]]; then
  echo "Waiting for run ${RUN_ID} to complete (timeout: ${TIMEOUT}s) …"
  ELAPSED=0
  while true; do
    RUN_STATE=$(api_call GET "/jobs/runs/get?run_id=${RUN_ID}" | jq -r '.state')
    LIFE_CYCLE=$(echo "$RUN_STATE" | jq -r '.life_cycle_state')
    RESULT_STATE=$(echo "$RUN_STATE" | jq -r '.result_state // "N/A"')
    echo "  [${ELAPSED}s] lifecycle=${LIFE_CYCLE}  result=${RESULT_STATE}"

    if [[ "$LIFE_CYCLE" == "TERMINATED" || "$LIFE_CYCLE" == "SKIPPED" || "$LIFE_CYCLE" == "INTERNAL_ERROR" ]]; then
      echo "Run finished with result state: ${RESULT_STATE}"
      [[ "$RESULT_STATE" == "SUCCESS" ]] && exit 0
      exit 1
    fi

    if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
      die "Timed out after ${TIMEOUT}s waiting for run ${RUN_ID}."
    fi

    sleep "$POLL_INTERVAL"
    ELAPSED=$(( ELAPSED + POLL_INTERVAL ))
  done
fi
