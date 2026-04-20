#!/usr/bin/env bash
# stop_cluster.sh – Stop a running Spark Standalone cluster (workers + master).
#
# Usage:
#   ./stop_cluster.sh [OPTIONS]
#
# Options:
#   -s, --spark-home <path>   SPARK_HOME directory (default: $SPARK_HOME env var)
#   -h, --help                Show this help message
#
# Examples:
#   SPARK_HOME=/opt/spark ./stop_cluster.sh
#   ./stop_cluster.sh --spark-home /opt/spark

set -euo pipefail

# ── helpers ────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

# ── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--spark-home) SPARK_HOME="$2"; shift 2 ;;
    -h|--help)       usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# ── resolve SPARK_HOME ─────────────────────────────────────────────────────────
: "${SPARK_HOME:?SPARK_HOME is not set. Use --spark-home or export SPARK_HOME.}"
[[ -d "$SPARK_HOME" ]] || die "SPARK_HOME does not exist: $SPARK_HOME"

SBIN="${SPARK_HOME}/sbin"

# ── stop workers first, then master ────────────────────────────────────────────
echo "Stopping all Spark workers …"
if [[ -x "${SBIN}/stop-worker.sh" ]]; then
  "${SBIN}/stop-worker.sh" || true
else
  echo "  stop-worker.sh not found, skipping."
fi

echo "Stopping Spark master …"
if [[ -x "${SBIN}/stop-master.sh" ]]; then
  "${SBIN}/stop-master.sh" || true
else
  echo "  stop-master.sh not found, skipping."
fi

echo "Spark standalone cluster stopped."
