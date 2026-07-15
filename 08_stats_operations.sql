-- ============================================================================
-- 08_stats_operations.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Statistics operations history
-- ============================================================================
-- Usage: @08_stats_operations.sql
-- Parameters: Schema name (optional, % for all), Days back (default 7)
-- Requires: DBA privileges
-- Notes: START_TIME/END_TIME in DBA_OPTSTAT_OPERATIONS are TIMESTAMP WITH
--        TIME ZONE; durations are computed via CAST(... AS DATE) so the
--        arithmetic yields a NUMBER instead of an INTERVAL.
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  STATISTICS OPERATIONS HISTORY
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name (or % for all): ' DEFAULT '%'
ACCEPT days_back NUMBER PROMPT 'Enter number of days to look back [7]: ' DEFAULT 7

COLUMN operation          FORMAT A25        HEADING "Operation"
COLUMN target             FORMAT A40        HEADING "Target"
COLUMN start_time         FORMAT A19        HEADING "Start Time"
COLUMN end_time           FORMAT A19        HEADING "End Time"
COLUMN duration_mins      FORMAT 9999.9     HEADING "Mins"
COLUMN status             FORMAT A12        HEADING "Status"
COLUMN job_name           FORMAT A30        HEADING "Job Name"

PROMPT
PROMPT ============================================================================
PROMPT  RECENT STATISTICS OPERATIONS (Last &days_back Days)
PROMPT ============================================================================

SELECT
    operation,
    target,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    ROUND((CAST(end_time AS DATE) - CAST(start_time AS DATE)) * 24 * 60, 1) AS duration_mins,
    status,
    job_name
FROM
    dba_optstat_operations
WHERE
    start_time > SYSDATE - &days_back
    AND (target LIKE UPPER('&schema_name') || '.%' OR '&schema_name' = '%')
ORDER BY
    start_time DESC;

PROMPT
PROMPT ============================================================================
PROMPT  OPERATIONS SUMMARY BY TYPE
PROMPT ============================================================================

COLUMN count       FORMAT 9999 HEADING "Count"
COLUMN completed   FORMAT 9999 HEADING "OK"
COLUMN failed      FORMAT 9999 HEADING "Fail"
COLUMN timed_out   FORMAT 9999 HEADING "T/Out"
COLUMN in_progress FORMAT 9999 HEADING "Run"
COLUMN avg_mins    FORMAT 9999.9 HEADING "Avg Min"
COLUMN max_mins    FORMAT 9999.9 HEADING "Max Min"

SELECT
    operation,
    COUNT(*) AS count,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed,
    SUM(CASE WHEN status = 'TIMED OUT' THEN 1 ELSE 0 END) AS timed_out,
    SUM(CASE WHEN status = 'IN PROGRESS' THEN 1 ELSE 0 END) AS in_progress,
    ROUND(AVG((CAST(end_time AS DATE) - CAST(start_time AS DATE)) * 24 * 60), 1) AS avg_mins,
    ROUND(MAX((CAST(end_time AS DATE) - CAST(start_time AS DATE)) * 24 * 60), 1) AS max_mins
FROM
    dba_optstat_operations
WHERE
    start_time > SYSDATE - &days_back
    AND (target LIKE UPPER('&schema_name') || '.%' OR '&schema_name' = '%')
GROUP BY
    operation
ORDER BY
    count DESC;

PROMPT
PROMPT ============================================================================
PROMPT  FAILED OPERATIONS
PROMPT ============================================================================

COLUMN notes FORMAT A60 HEADING "Notes"

SELECT
    operation,
    target,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    status,
    job_name,
    SUBSTR(notes, 1, 60) AS notes
FROM
    dba_optstat_operations
WHERE
    start_time > SYSDATE - &days_back
    AND status IN ('FAILED', 'TIMED OUT')
    AND (target LIKE UPPER('&schema_name') || '.%' OR '&schema_name' = '%')
ORDER BY
    start_time DESC;

PROMPT
PROMPT ============================================================================
PROMPT  LONG RUNNING OPERATIONS (> 30 minutes)
PROMPT ============================================================================

SELECT
    operation,
    target,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    ROUND((CAST(end_time AS DATE) - CAST(start_time AS DATE)) * 24 * 60, 1) AS duration_mins,
    status
FROM
    dba_optstat_operations
WHERE
    start_time > SYSDATE - &days_back
    AND (CAST(end_time AS DATE) - CAST(start_time AS DATE)) * 24 * 60 > 30
    AND (target LIKE UPPER('&schema_name') || '.%' OR '&schema_name' = '%')
ORDER BY
    duration_mins DESC;

PROMPT
PROMPT ============================================================================
PROMPT  DAILY OPERATIONS VOLUME
PROMPT ============================================================================

COLUMN day        FORMAT A10   HEADING "Day"
COLUMN total_ops  FORMAT 9999  HEADING "Total Ops"
COLUMN total_mins FORMAT 99999 HEADING "Total Min"

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD') AS day,
    COUNT(*) AS total_ops,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed,
    ROUND(SUM((CAST(end_time AS DATE) - CAST(start_time AS DATE)) * 24 * 60), 0) AS total_mins
FROM
    dba_optstat_operations
WHERE
    start_time > SYSDATE - &days_back
    AND (target LIKE UPPER('&schema_name') || '.%' OR '&schema_name' = '%')
GROUP BY
    TO_CHAR(start_time, 'YYYY-MM-DD')
ORDER BY
    day DESC;

PROMPT
PROMPT ============================================================================
PROMPT  TABLES WITH MOST FREQUENT STATS GATHERING
PROMPT ============================================================================

COLUMN gather_count FORMAT 9999 HEADING "Count"
COLUMN first_gather FORMAT A16  HEADING "First Gather"
COLUMN last_gather  FORMAT A16  HEADING "Last Gather"

SELECT
    target AS table_name,
    COUNT(*) AS gather_count,
    MIN(TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI')) AS first_gather,
    MAX(TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI')) AS last_gather,
    ROUND(AVG((CAST(end_time AS DATE) - CAST(start_time AS DATE)) * 24 * 60), 1) AS avg_mins
FROM
    dba_optstat_operations
WHERE
    start_time > SYSDATE - &days_back
    AND operation LIKE 'gather%'
    AND (target LIKE UPPER('&schema_name') || '.%' OR '&schema_name' = '%')
GROUP BY
    target
HAVING
    COUNT(*) > 1
ORDER BY
    gather_count DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT Operation Types:
PROMPT   gather_table_stats    - Single table gather
PROMPT   gather_schema_stats   - Schema-wide gather
PROMPT   gather_database_stats - Database-wide gather
PROMPT   delete_table_stats    - Statistics deletion
PROMPT   set_table_stats       - Manual stats setting
PROMPT   restore_table_stats   - Stats restoration from history
PROMPT

UNDEFINE schema_name
UNDEFINE days_back

SET FEEDBACK ON
SET VERIFY ON
