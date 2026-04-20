#!/usr/bin/env bash
# run_job.sh – Submit and optionally wait for a Databricks job run.
#
# Usage:
#   ./run_job.sh [OPTIONS]
#
# Required environment variables (or pass via flags):
#   DATABRICKS_HOST   – Workspace URL, e.g. https://<workspace>.azuredatabricks.net
#   DATABRICKS_TOKEN  – Personal-access token (or SP OAuth token)
#
# Options:
#   -j, --job-id <id>         Existing job ID to trigger a run
#   -n, --job-name <name>     Look up job ID by name (mutually exclusive with -j)
#   -p, --params <json>       Notebook/task parameters as a JSON string (optional)
#   -w, --wait                Block until the run finishes and exit with its result code
#   -t, --timeout <seconds>   Polling timeout when --wait is set (default: 3600)
#   -h, --help                Show this help message
#
# Examples:
#   DATABRICKS_HOST=https://adb-xxx.azuredatabricks.net \
#   DATABRICKS_TOKEN=dapi... \
#   ./run_job.sh --job-id 42 --wait
#
#   ./run_job.sh --job-name "nightly_etl" --params '{"date":"2024-01-01"}' --wait

set -euo pipefail

# ── defaults ───────────────────────────────────────────────────────────────────
WAIT=false
TIMEOUT=3600
POLL_INTERVAL=15
JOB_ID=""
JOB_NAME=""
PARAMS=""

# ── helpers ────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed."; }

urlencode() { python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"; }

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
    -j|--job-id)    JOB_ID="$2";   shift 2 ;;
    -n|--job-name)  JOB_NAME="$2"; shift 2 ;;
    -p|--params)    PARAMS="$2";   shift 2 ;;
    -w|--wait)      WAIT=true;     shift   ;;
    -t|--timeout)   TIMEOUT="$2";  shift 2 ;;
    -h|--help)      usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── validation ─────────────────────────────────────────────────────────────────
require_cmd curl
require_cmd jq
require_cmd python3

[[ -z "${DATABRICKS_HOST:-}" ]]  && die "DATABRICKS_HOST is not set."
[[ -z "${DATABRICKS_TOKEN:-}" ]] && die "DATABRICKS_TOKEN is not set."
[[ -z "$JOB_ID" && -z "$JOB_NAME" ]] && die "Provide --job-id or --job-name."
[[ -n "$JOB_ID" && -n "$JOB_NAME" ]] && die "--job-id and --job-name are mutually exclusive."

# ── resolve job name → job ID ──────────────────────────────────────────────────
if [[ -n "$JOB_NAME" ]]; then
  echo "Looking up job ID for name: '${JOB_NAME}' …"
  JOBS_JSON=$(api_call GET "/jobs/list?name=$(urlencode "$JOB_NAME")")
  JOB_ID=$(echo "$JOBS_JSON" | jq -r '.jobs[0].job_id // empty')
  [[ -z "$JOB_ID" ]] && die "No job found with name '${JOB_NAME}'."
  echo "Resolved job ID: ${JOB_ID}"
fi

# ── trigger run ────────────────────────────────────────────────────────────────
PAYLOAD="{\"job_id\": ${JOB_ID}}"
if [[ -n "$PARAMS" ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | jq --argjson p "$PARAMS" '. + {notebook_params: $p}')
fi

echo "Triggering run for job ID ${JOB_ID} …"
RUN_RESPONSE=$(api_call POST "/jobs/run-now" "$PAYLOAD")
RUN_ID=$(echo "$RUN_RESPONSE" | jq -r '.run_id')
echo "Run ID: ${RUN_ID}"
echo "Run URL: ${DATABRICKS_HOST%/}/#job/${JOB_ID}/run/${RUN_ID}"

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
