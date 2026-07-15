-- ============================================================================
-- 11_stats_history.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Statistics history, retention, and restore options
-- ============================================================================
-- Usage: @11_stats_history.sql
-- Parameters: Schema name (prompted), Table name (optional)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  STATISTICS HISTORY AND RESTORE
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '
ACCEPT table_name CHAR DEFAULT '%' PROMPT 'Enter table name [%]: '

PROMPT
PROMPT ============================================================================
PROMPT  HISTORY RETENTION CONFIGURATION
PROMPT ============================================================================

COLUMN setting FORMAT A40 HEADING "Setting"
COLUMN value   FORMAT A40 HEADING "Value"

SELECT
    'History Retention (days)' AS setting,
    TO_CHAR(DBMS_STATS.GET_STATS_HISTORY_RETENTION) AS value
FROM dual
UNION ALL
SELECT
    'Oldest Restorable Stats (availability)',
    TO_CHAR(DBMS_STATS.GET_STATS_HISTORY_AVAILABILITY, 'YYYY-MM-DD HH24:MI:SS')
FROM dual;

PROMPT
PROMPT ============================================================================
PROMPT  SYSAUX SPACE USED BY STATISTICS HISTORY
PROMPT ============================================================================

COLUMN occupant_name FORMAT A20 HEADING "Occupant"
COLUMN schema_name_o FORMAT A15 HEADING "Schema"
COLUMN space_mb      FORMAT 999,999.9 HEADING "Space (MB)"

SELECT
    occupant_name,
    schema_name AS schema_name_o,
    ROUND(space_usage_kbytes / 1024, 1) AS space_mb
FROM
    v$sysaux_occupants
WHERE
    occupant_name LIKE 'SM%'
ORDER BY
    space_usage_kbytes DESC;

PROMPT
PROMPT ============================================================================
PROMPT  RECENT STATISTICS SAVES (Table-Level History)
PROMPT ============================================================================

COLUMN table_name        FORMAT A30 HEADING "Table Name"
COLUMN partition_name    FORMAT A25 HEADING "Partition"
COLUMN stats_update_time FORMAT A19 HEADING "Stats Saved At"

SELECT
    table_name,
    partition_name,
    TO_CHAR(stats_update_time, 'YYYY-MM-DD HH24:MI:SS') AS stats_update_time
FROM
    dba_tab_stats_history
WHERE
    owner = UPPER('&schema_name')
    AND table_name LIKE UPPER('&table_name')
ORDER BY
    stats_update_time DESC
FETCH FIRST 50 ROWS ONLY;

PROMPT
PROMPT ============================================================================
PROMPT  HISTORY DEPTH PER TABLE (How many restore points exist)
PROMPT ============================================================================

COLUMN versions      FORMAT 9999 HEADING "Versions"
COLUMN oldest_save   FORMAT A19  HEADING "Oldest Save"
COLUMN newest_save   FORMAT A19  HEADING "Newest Save"

SELECT
    table_name,
    COUNT(*) AS versions,
    TO_CHAR(MIN(stats_update_time), 'YYYY-MM-DD HH24:MI:SS') AS oldest_save,
    TO_CHAR(MAX(stats_update_time), 'YYYY-MM-DD HH24:MI:SS') AS newest_save
FROM
    dba_tab_stats_history
WHERE
    owner = UPPER('&schema_name')
    AND table_name LIKE UPPER('&table_name')
    AND partition_name IS NULL
GROUP BY
    table_name
ORDER BY
    versions DESC,
    table_name;

PROMPT
PROMPT ============================================================================
PROMPT  USEFUL COMMANDS
PROMPT ============================================================================
PROMPT
PROMPT -- Restore table stats as of a point in time:
PROMPT EXEC DBMS_STATS.RESTORE_TABLE_STATS('&schema_name', 'TABLE_NAME', -
PROMPT      TO_TIMESTAMP('2026-01-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));
PROMPT
PROMPT -- Restore an entire schema as of a point in time:
PROMPT EXEC DBMS_STATS.RESTORE_SCHEMA_STATS('&schema_name', -
PROMPT      TO_TIMESTAMP('2026-01-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));
PROMPT
PROMPT -- Change the retention period (days):
PROMPT EXEC DBMS_STATS.ALTER_STATS_HISTORY_RETENTION(31);
PROMPT
PROMPT -- Purge history older than N days (frees SYSAUX space):
PROMPT EXEC DBMS_STATS.PURGE_STATS(SYSDATE - 15);
PROMPT
PROMPT -- Compare current stats against a historical version:
PROMPT SELECT * FROM TABLE(DBMS_STATS.DIFF_TABLE_STATS_IN_HISTORY( -
PROMPT     '&schema_name', 'TABLE_NAME', SYSDATE - 7, SYSDATE, 10));
PROMPT
PROMPT Notes:
PROMPT   - Statistics are automatically saved before each gather; restore lets
PROMPT     you back out a bad gather quickly.
PROMPT   - Restore does NOT work for stats gathered before the availability
PROMPT     timestamp shown above, or if history was purged.
PROMPT   - Large SM/OPTSTAT usage in SYSAUX usually means retention is too long
PROMPT     or purging is not keeping up.
PROMPT

UNDEFINE schema_name
UNDEFINE table_name

SET FEEDBACK ON
SET VERIFY ON
