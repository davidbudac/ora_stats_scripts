-- ============================================================================
-- 01_table_stats_overview.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Table-level statistics summary for a schema
-- ============================================================================
-- Usage: @01_table_stats_overview.sql
-- Parameters: Schema name (prompted)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  TABLE STATISTICS OVERVIEW
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '

COLUMN table_name         FORMAT A30        HEADING "Table Name"
COLUMN partitioned        FORMAT A4         HEADING "Part"
COLUMN num_rows           FORMAT 999,999,999,999  HEADING "Num Rows"
COLUMN blocks             FORMAT 999,999,999      HEADING "Blocks"
COLUMN avg_row_len        FORMAT 99,999           HEADING "AvgLen"
COLUMN sample_size        FORMAT 999,999,999,999  HEADING "Sample Size"
COLUMN sample_pct         FORMAT 990.9            HEADING "Smpl%"
COLUMN last_analyzed      FORMAT A19              HEADING "Last Analyzed"
COLUMN stale              FORMAT A5               HEADING "Stale"
COLUMN stattype_locked    FORMAT A6               HEADING "Locked"
COLUMN days_old           FORMAT 9999             HEADING "Days"
COLUMN issues             FORMAT A25              HEADING "Issues"

PROMPT
PROMPT Table Statistics for Schema: &schema_name
PROMPT ============================================================================

SELECT
    t.table_name,
    t.partitioned AS partitioned,
    ts.num_rows,
    t.blocks,
    t.avg_row_len,
    ts.sample_size,
    CASE
        WHEN ts.num_rows > 0 THEN ROUND(ts.sample_size / ts.num_rows * 100, 1)
        ELSE NULL
    END AS sample_pct,
    TO_CHAR(ts.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS last_analyzed,
    ts.stale_stats AS stale,
    ts.stattype_locked,
    TRUNC(SYSDATE - ts.last_analyzed) AS days_old,
    CASE
        WHEN ts.num_rows IS NULL THEN 'NO STATS'
        WHEN ts.stale_stats = 'YES' THEN 'STALE'
        WHEN TRUNC(SYSDATE - ts.last_analyzed) > 30 THEN 'OLD (>30d)'
        WHEN ts.sample_size IS NOT NULL
             AND ts.num_rows > 0
             AND ts.sample_size / ts.num_rows < 0.1 THEN 'LOW SAMPLE'
        ELSE NULL
    END AS issues
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
ORDER BY
    CASE
        WHEN ts.num_rows IS NULL THEN 1
        WHEN ts.stale_stats = 'YES' THEN 2
        WHEN TRUNC(SYSDATE - ts.last_analyzed) > 30 THEN 3
        ELSE 4
    END,
    ts.num_rows DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT  SUMMARY
PROMPT ============================================================================

COLUMN total_tables  FORMAT 9999 HEADING "Total|Tables"
COLUMN no_stats      FORMAT 9999 HEADING "No|Stats"
COLUMN stale_stats   FORMAT 9999 HEADING "Stale|Stats"
COLUMN old_stats     FORMAT 9999 HEADING "Old|Stats"
COLUMN low_sample    FORMAT 9999 HEADING "Low|Sample"
COLUMN locked_stats  FORMAT 9999 HEADING "Locked|Stats"

SELECT
    COUNT(*) AS total_tables,
    SUM(CASE WHEN ts.num_rows IS NULL THEN 1 ELSE 0 END) AS no_stats,
    SUM(CASE WHEN ts.stale_stats = 'YES' THEN 1 ELSE 0 END) AS stale_stats,
    SUM(CASE WHEN ts.last_analyzed < SYSDATE - 30 AND ts.num_rows IS NOT NULL THEN 1 ELSE 0 END) AS old_stats,
    SUM(CASE WHEN ts.sample_size IS NOT NULL AND ts.num_rows > 0
             AND ts.sample_size / ts.num_rows < 0.1 THEN 1 ELSE 0 END) AS low_sample,
    SUM(CASE WHEN ts.stattype_locked IS NOT NULL THEN 1 ELSE 0 END) AS locked_stats
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
    );

PROMPT
PROMPT Issue Legend:
PROMPT   NO STATS   - Table has no optimizer statistics
PROMPT   STALE      - Statistics marked as stale by Oracle
PROMPT   OLD (>30d) - Statistics older than 30 days
PROMPT   LOW SAMPLE - Sample size less than 10% of rows
PROMPT
PROMPT Note: Temporary, secondary, nested, and external tables are excluded.
PROMPT

UNDEFINE schema_name

SET FEEDBACK ON
SET VERIFY ON
