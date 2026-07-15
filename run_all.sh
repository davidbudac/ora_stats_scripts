#!/usr/bin/env bash
# ============================================================================
# run_all.sh
# Oracle Optimizer Statistics Analysis Toolkit
# Runs every script for one schema and saves a combined report file.
# ============================================================================
# Usage:
#   ./run_all.sh "<connect_string>" <schema> [table_pattern] [days_back]
#
# Examples:
#   ./run_all.sh "/ as sysdba" HR
#   ./run_all.sh "system/oracle@//db-host:1521/pdb1" SALES % 14
#
# The scripts' interactive prompts are answered automatically; output goes to
# stats_report_<SCHEMA>_<timestamp>.txt in the current directory.
# ============================================================================
set -u

if [ $# -lt 2 ]; then
    sed -n '5,15p' "$0"
    exit 1
fi

CONNECT="$1"
SCHEMA="$2"
TABLE_PATTERN="${3:-%}"
DAYS_BACK="${4:-7}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="stats_report_${SCHEMA}_${STAMP}.txt"

if ! command -v sqlplus >/dev/null 2>&1; then
    echo "ERROR: sqlplus not found in PATH" >&2
    exit 1
fi

# run_script <script> [answer]... - feeds answers to the script's ACCEPT prompts
run_script() {
    local script="$1"
    shift
    echo "Running ${script}..."
    {
        echo "=============================================================================="
        echo "==  ${script}"
        echo "=============================================================================="
        printf '%s\n' "$@" | sqlplus -S -L "$CONNECT" "@${SCRIPT_DIR}/${script}"
        echo
    } >> "$REPORT" 2>&1
}

echo "Writing report to ${REPORT}"

run_script 01_table_stats_overview.sql   "$SCHEMA"
run_script 02_column_stats_analysis.sql  "$SCHEMA" "$TABLE_PATTERN"
run_script 03_stats_preferences.sql      "$SCHEMA"
run_script 04_index_stats.sql            "$SCHEMA" "$TABLE_PATTERN"
run_script 05_partition_stats.sql        "$SCHEMA" "$TABLE_PATTERN"
run_script 06_extended_stats.sql         "$SCHEMA"
run_script 07_auto_stats_monitor.sql
run_script 08_stats_operations.sql       "$SCHEMA" "$DAYS_BACK"
run_script 09_stale_stats_report.sql     "$SCHEMA"
run_script 10_stats_health_check.sql     "$SCHEMA"
run_script 11_stats_history.sql          "$SCHEMA" "$TABLE_PATTERN"
run_script 12_pending_stats.sql          "$SCHEMA"
run_script 13_dictionary_system_stats.sql
run_script 14_realtime_hf_stats.sql      "$SCHEMA"

echo "Done. Report saved to ${REPORT}"

if grep -Eq 'ORA-[0-9]+|SP2-[0-9]+' "$REPORT"; then
    echo "WARNING: the report contains ORA-/SP2- errors:" >&2
    grep -Eno 'ORA-[0-9]+[^"]*|SP2-[0-9]+.*' "$REPORT" | sort -u | head -20 >&2
fi
