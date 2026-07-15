-- ============================================================================
-- 14_realtime_hf_stats.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Real-time statistics and high-frequency automatic statistics (19c+)
-- ============================================================================
-- Usage: @14_realtime_hf_stats.sql
-- Parameters: Schema name (prompted)
-- Requires: DBA privileges, Oracle 19c or later
--           (real-time stats require Exadata / Enterprise Edition features
--            depending on version and platform)
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  REAL-TIME AND HIGH-FREQUENCY STATISTICS (19c+)
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '

PROMPT
PROMPT ============================================================================
PROMPT  HIGH-FREQUENCY AUTO STATS TASK CONFIGURATION
PROMPT ============================================================================

COLUMN setting FORMAT A30 HEADING "Setting"
COLUMN value   FORMAT A30 HEADING "Value"

SELECT
    'AUTO_TASK_STATUS' AS setting,
    DBMS_STATS.GET_PREFS('AUTO_TASK_STATUS') AS value
FROM dual
UNION ALL
SELECT
    'AUTO_TASK_MAX_RUN_TIME (secs)',
    DBMS_STATS.GET_PREFS('AUTO_TASK_MAX_RUN_TIME')
FROM dual
UNION ALL
SELECT
    'AUTO_TASK_INTERVAL (secs)',
    DBMS_STATS.GET_PREFS('AUTO_TASK_INTERVAL')
FROM dual;

PROMPT
PROMPT ============================================================================
PROMPT  AUTO STATS EXECUTIONS (Maintenance Window + High-Frequency, Last 7 Days)
PROMPT ============================================================================

COLUMN opid        FORMAT 999999 HEADING "Op ID"
COLUMN origin      FORMAT A22    HEADING "Origin"
COLUMN status      FORMAT A12    HEADING "Status"
COLUMN start_time  FORMAT A19    HEADING "Start Time"
COLUMN duration_mins FORMAT 9999.9 HEADING "Mins"
COLUMN completed   FORMAT 99999  HEADING "OK"
COLUMN failed      FORMAT 99999  HEADING "Fail"
COLUMN timed_out   FORMAT 99999  HEADING "T/Out"

SELECT
    opid,
    origin,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    ROUND((CAST(end_time AS DATE) - CAST(start_time AS DATE)) * 24 * 60, 1) AS duration_mins,
    completed,
    failed,
    timed_out
FROM
    dba_auto_stat_executions
WHERE
    start_time > SYSDATE - 7
ORDER BY
    start_time DESC;

PROMPT
PROMPT ============================================================================
PROMPT  TABLES WITH REAL-TIME STATISTICS (Schema: &schema_name)
PROMPT ============================================================================
PROMPT
PROMPT Table-level real-time stats (NOTES = STATS_ON_CONVENTIONAL_DML):

COLUMN table_name    FORMAT A30 HEADING "Table Name"
COLUMN num_rows      FORMAT 999,999,999,999 HEADING "Num Rows"
COLUMN last_analyzed FORMAT A19 HEADING "Last Analyzed"
COLUMN notes         FORMAT A30 HEADING "Notes"

SELECT
    table_name,
    num_rows,
    TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS last_analyzed,
    notes
FROM
    dba_tab_statistics
WHERE
    owner = UPPER('&schema_name')
    AND notes = 'STATS_ON_CONVENTIONAL_DML'
ORDER BY
    table_name;

PROMPT
PROMPT Column-level real-time stats:

COLUMN column_name FORMAT A30 HEADING "Column Name"

SELECT
    table_name,
    column_name,
    TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS last_analyzed,
    notes
FROM
    dba_tab_col_statistics
WHERE
    owner = UPPER('&schema_name')
    AND notes = 'STATS_ON_CONVENTIONAL_DML'
ORDER BY
    table_name,
    column_name;

PROMPT
PROMPT ============================================================================
PROMPT  USEFUL COMMANDS
PROMPT ============================================================================
PROMPT
PROMPT -- Enable the high-frequency automatic statistics task:
PROMPT EXEC DBMS_STATS.SET_GLOBAL_PREFS('AUTO_TASK_STATUS', 'ON');
PROMPT
PROMPT -- Limit each high-frequency run to 10 minutes, every 5 minutes:
PROMPT EXEC DBMS_STATS.SET_GLOBAL_PREFS('AUTO_TASK_MAX_RUN_TIME', '600');
PROMPT EXEC DBMS_STATS.SET_GLOBAL_PREFS('AUTO_TASK_INTERVAL', '300');
PROMPT
PROMPT -- Disable real-time statistics for a session (testing):
PROMPT ALTER SESSION SET "_optimizer_gather_stats_on_conventional_dml" = FALSE;
PROMPT
PROMPT Notes:
PROMPT   - The high-frequency task gathers stale stats between maintenance
PROMPT     windows; it complements (not replaces) the nightly auto task.
PROMPT   - Real-time statistics extend conventional DML to update basic stats
PROMPT     (row counts, min/max) as data changes; shown via the NOTES column.
PROMPT   - Both features are 19c+; this script will error on older releases.
PROMPT

UNDEFINE schema_name

SET FEEDBACK ON
SET VERIFY ON
