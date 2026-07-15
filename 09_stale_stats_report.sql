-- ============================================================================
-- 09_stale_stats_report.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Stale statistics identification and DML activity analysis
-- ============================================================================
-- Usage: @09_stale_stats_report.sql
-- Parameters: Schema name (prompted)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  STALE STATISTICS REPORT
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '

PROMPT
PROMPT Flushing database monitoring info so DBA_TAB_MODIFICATIONS is current...
EXEC DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO;

COLUMN table_name         FORMAT A30        HEADING "Table Name"
COLUMN num_rows           FORMAT 999,999,999,999 HEADING "Num Rows"
COLUMN last_analyzed      FORMAT A19        HEADING "Last Analyzed"
COLUMN stale              FORMAT A5         HEADING "Stale"
COLUMN inserts            FORMAT 999,999,999,999 HEADING "Inserts"
COLUMN updates            FORMAT 999,999,999,999 HEADING "Updates"
COLUMN deletes            FORMAT 999,999,999,999 HEADING "Deletes"
COLUMN total_mods         FORMAT 999,999,999,999 HEADING "Total Mods"
COLUMN pct_modified       FORMAT 999.9      HEADING "Mod%"
COLUMN truncated          FORMAT A5         HEADING "Trunc"
COLUMN priority           FORMAT A8         HEADING "Priority"

PROMPT
PROMPT ============================================================================
PROMPT  TABLES MARKED AS STALE
PROMPT ============================================================================

SELECT
    ts.table_name,
    ts.num_rows,
    TO_CHAR(ts.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS last_analyzed,
    ts.stale_stats AS stale,
    NVL(tm.inserts, 0) AS inserts,
    NVL(tm.updates, 0) AS updates,
    NVL(tm.deletes, 0) AS deletes,
    NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0) AS total_mods,
    CASE
        WHEN ts.num_rows > 0 THEN
            ROUND((NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0)) / ts.num_rows * 100, 1)
        ELSE NULL
    END AS pct_modified,
    NVL(tm.truncated, 'NO') AS truncated,
    CASE
        WHEN NVL(tm.truncated, 'NO') = 'YES' THEN 'CRITICAL'
        WHEN ts.num_rows IS NULL THEN 'HIGH'
        WHEN ts.num_rows > 0 AND
             (NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0)) / ts.num_rows > 0.5 THEN 'HIGH'
        WHEN ts.stale_stats = 'YES' THEN 'MEDIUM'
        ELSE 'LOW'
    END AS priority
FROM
    dba_tab_statistics ts
    LEFT JOIN dba_tab_modifications tm
        ON ts.owner = tm.table_owner
        AND ts.table_name = tm.table_name
        AND tm.partition_name IS NULL
WHERE
    ts.owner = UPPER('&schema_name')
    AND ts.object_type = 'TABLE'
    AND ts.partition_name IS NULL
    AND (ts.stale_stats = 'YES'
         OR ts.num_rows IS NULL
         OR NVL(tm.truncated, 'NO') = 'YES')
ORDER BY
    CASE
        WHEN NVL(tm.truncated, 'NO') = 'YES' THEN 1
        WHEN ts.num_rows IS NULL THEN 2
        ELSE 3
    END,
    NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0) DESC;

PROMPT
PROMPT ============================================================================
PROMPT  DML ACTIVITY SINCE LAST GATHER (All Tables)
PROMPT ============================================================================
PROMPT
PROMPT Tables with significant modifications (> 10% or > 100K rows):

COLUMN days_old FORMAT 9999 HEADING "Days"

SELECT
    ts.table_name,
    ts.num_rows,
    TO_CHAR(ts.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS last_analyzed,
    NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0) AS total_mods,
    CASE
        WHEN ts.num_rows > 0 THEN
            ROUND((NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0)) / ts.num_rows * 100, 1)
        ELSE NULL
    END AS pct_modified,
    ts.stale_stats AS stale,
    TRUNC(SYSDATE - ts.last_analyzed) AS days_old
FROM
    dba_tab_statistics ts
    LEFT JOIN dba_tab_modifications tm
        ON ts.owner = tm.table_owner
        AND ts.table_name = tm.table_name
        AND tm.partition_name IS NULL
WHERE
    ts.owner = UPPER('&schema_name')
    AND ts.object_type = 'TABLE'
    AND ts.partition_name IS NULL
    AND ts.num_rows IS NOT NULL
    AND (
        (ts.num_rows > 0 AND (NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0)) / ts.num_rows > 0.1)
        OR (NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0)) > 100000
    )
ORDER BY
    NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0) DESC;

PROMPT
PROMPT ============================================================================
PROMPT  TABLES WITHOUT STATISTICS
PROMPT ============================================================================

COLUMN actual_rows FORMAT 999,999,999,999 HEADING "Actual Rows"
COLUMN partitioned FORMAT A4              HEADING "Part"
COLUMN table_analyzed FORMAT A19          HEADING "Table Analyzed"

SELECT
    t.table_name,
    t.num_rows AS actual_rows,
    t.blocks,
    t.partitioned,
    TO_CHAR(t.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS table_analyzed
FROM
    dba_tables t
    LEFT JOIN dba_tab_statistics ts
        ON t.owner = ts.owner
        AND t.table_name = ts.table_name
        AND ts.partition_name IS NULL
WHERE
    t.owner = UPPER('&schema_name')
    AND t.temporary = 'N'
    AND t.secondary = 'N'
    AND t.nested = 'NO'
    AND (t.iot_type IS NULL OR t.iot_type = 'IOT')
    AND NOT EXISTS (
        SELECT 1 FROM dba_external_tables x
        WHERE x.owner = t.owner AND x.table_name = t.table_name
    )
    AND ts.num_rows IS NULL
ORDER BY
    t.blocks DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT  STALE STATISTICS SUMMARY
PROMPT ============================================================================

COLUMN total_tables  FORMAT 9999 HEADING "Total"
COLUMN stale_tables  FORMAT 9999 HEADING "Stale"
COLUMN no_stats      FORMAT 9999 HEADING "No Stats"
COLUMN truncated     FORMAT 9999 HEADING "Truncated"
COLUMN high_churn    FORMAT 9999 HEADING "High Churn"

SELECT
    COUNT(*) AS total_tables,
    SUM(CASE WHEN ts.stale_stats = 'YES' THEN 1 ELSE 0 END) AS stale_tables,
    SUM(CASE WHEN ts.num_rows IS NULL THEN 1 ELSE 0 END) AS no_stats,
    SUM(CASE WHEN NVL(tm.truncated, 'NO') = 'YES' THEN 1 ELSE 0 END) AS truncated,
    SUM(CASE
        WHEN ts.num_rows > 0 AND
             (NVL(tm.inserts, 0) + NVL(tm.updates, 0) + NVL(tm.deletes, 0)) / ts.num_rows > 0.5
        THEN 1 ELSE 0
    END) AS high_churn
FROM
    dba_tab_statistics ts
    LEFT JOIN dba_tab_modifications tm
        ON ts.owner = tm.table_owner
        AND ts.table_name = tm.table_name
        AND tm.partition_name IS NULL
    JOIN dba_tables t
        ON ts.owner = t.owner
        AND ts.table_name = t.table_name
WHERE
    ts.owner = UPPER('&schema_name')
    AND ts.object_type = 'TABLE'
    AND ts.partition_name IS NULL
    AND t.temporary = 'N'
    AND t.secondary = 'N'
    AND t.nested = 'NO'
    AND NOT EXISTS (
        SELECT 1 FROM dba_external_tables x
        WHERE x.owner = t.owner AND x.table_name = t.table_name
    );

PROMPT
PROMPT ============================================================================
PROMPT  RECOMMENDED GATHER COMMANDS
PROMPT ============================================================================
PROMPT
PROMPT -- Gather stats for all stale tables in schema:
PROMPT EXEC DBMS_STATS.GATHER_SCHEMA_STATS('&schema_name', OPTIONS=>'GATHER STALE');
PROMPT
PROMPT -- Gather stats for tables without statistics:
PROMPT EXEC DBMS_STATS.GATHER_SCHEMA_STATS('&schema_name', OPTIONS=>'GATHER EMPTY');
PROMPT
PROMPT -- Force refresh all statistics in schema:
PROMPT EXEC DBMS_STATS.GATHER_SCHEMA_STATS('&schema_name', OPTIONS=>'GATHER');
PROMPT
PROMPT Priority Legend:
PROMPT   CRITICAL - Table was truncated, stats completely invalid
PROMPT   HIGH     - No stats or >50% data modified
PROMPT   MEDIUM   - Marked stale by Oracle
PROMPT   LOW      - Minor changes
PROMPT
PROMPT Note: DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO was executed at the start
PROMPT       of this report so DML counts reflect current in-memory activity.
PROMPT

UNDEFINE schema_name

SET FEEDBACK ON
SET VERIFY ON
