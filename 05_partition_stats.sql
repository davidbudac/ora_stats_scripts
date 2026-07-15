-- ============================================================================
-- 05_partition_stats.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Partition-level statistics for partitioned tables
-- ============================================================================
-- Usage: @05_partition_stats.sql
-- Parameters: Schema name (prompted), Table name (optional)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  PARTITION STATISTICS OVERVIEW
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '
ACCEPT table_name CHAR DEFAULT '%' PROMPT 'Enter table name [%]: '

COLUMN table_name         FORMAT A25        HEADING "Table"
COLUMN partition_name     FORMAT A25        HEADING "Partition"
COLUMN partition_position FORMAT 9999       HEADING "Pos"
COLUMN num_rows           FORMAT 999,999,999,999  HEADING "Num Rows"
COLUMN blocks             FORMAT 999,999,999      HEADING "Blocks"
COLUMN last_analyzed      FORMAT A19              HEADING "Last Analyzed"
COLUMN stale              FORMAT A5               HEADING "Stale"
COLUMN days_old           FORMAT 9999             HEADING "Days"
COLUMN issues             FORMAT A15              HEADING "Issues"

PROMPT
PROMPT ============================================================================
PROMPT  PARTITIONED TABLES SUMMARY
PROMPT ============================================================================

COLUMN part_type      FORMAT A10  HEADING "Part Type"
COLUMN subpart_type   FORMAT A10  HEADING "SubPart"
COLUMN part_cnt       FORMAT 9999 HEADING "Parts"
COLUMN global_rows    FORMAT 999,999,999,999 HEADING "Global Rows"
COLUMN global_analyzed FORMAT A19 HEADING "Global Analyzed"
COLUMN global_stale   FORMAT A5   HEADING "Stale"
COLUMN incremental    FORMAT A6   HEADING "Incr"

SELECT
    t.table_name,
    t.partitioning_type AS part_type,
    t.subpartitioning_type AS subpart_type,
    t.partition_count AS part_cnt,
    ts.num_rows AS global_rows,
    TO_CHAR(ts.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS global_analyzed,
    ts.stale AS global_stale,
    NVL((SELECT preference_value
         FROM dba_tab_stat_prefs
         WHERE owner = t.owner
         AND table_name = t.table_name
         AND preference_name = 'INCREMENTAL'), 'FALSE') AS incremental
FROM
    dba_part_tables t
    LEFT JOIN dba_tab_statistics ts
        ON t.owner = ts.owner
        AND t.table_name = ts.table_name
        AND ts.partition_name IS NULL
WHERE
    t.owner = UPPER('&schema_name')
    AND t.table_name LIKE UPPER('&table_name')
ORDER BY
    t.table_name;

PROMPT
PROMPT ============================================================================
PROMPT  PARTITION-LEVEL STATISTICS
PROMPT ============================================================================

SELECT
    ps.table_name,
    ps.partition_name,
    ps.partition_position,
    ps.num_rows,
    tp.blocks,
    TO_CHAR(ps.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS last_analyzed,
    ps.stale,
    TRUNC(SYSDATE - ps.last_analyzed) AS days_old,
    CASE
        WHEN ps.num_rows IS NULL THEN 'NO STATS'
        WHEN ps.stale = 'YES' THEN 'STALE'
        WHEN TRUNC(SYSDATE - ps.last_analyzed) > 30 THEN 'OLD'
        ELSE NULL
    END AS issues
FROM
    dba_tab_statistics ps
    JOIN dba_tab_partitions tp
        ON ps.owner = tp.table_owner
        AND ps.table_name = tp.table_name
        AND ps.partition_name = tp.partition_name
WHERE
    ps.owner = UPPER('&schema_name')
    AND ps.table_name LIKE UPPER('&table_name')
    AND ps.object_type = 'PARTITION'
ORDER BY
    ps.table_name,
    ps.partition_position;

PROMPT
PROMPT ============================================================================
PROMPT  STALE PARTITIONS SUMMARY
PROMPT ============================================================================

COLUMN total_partitions FORMAT 9999 HEADING "Total"
COLUMN no_stats         FORMAT 9999 HEADING "No Stats"
COLUMN stale            FORMAT 9999 HEADING "Stale"
COLUMN old_stats        FORMAT 9999 HEADING "Old"

SELECT
    ps.table_name,
    COUNT(*) AS total_partitions,
    SUM(CASE WHEN ps.num_rows IS NULL THEN 1 ELSE 0 END) AS no_stats,
    SUM(CASE WHEN ps.stale = 'YES' THEN 1 ELSE 0 END) AS stale,
    SUM(CASE WHEN ps.last_analyzed < SYSDATE - 30 AND ps.num_rows IS NOT NULL THEN 1 ELSE 0 END) AS old_stats
FROM
    dba_tab_statistics ps
WHERE
    ps.owner = UPPER('&schema_name')
    AND ps.table_name LIKE UPPER('&table_name')
    AND ps.object_type = 'PARTITION'
GROUP BY
    ps.table_name
HAVING
    SUM(CASE WHEN ps.num_rows IS NULL THEN 1 ELSE 0 END) > 0
    OR SUM(CASE WHEN ps.stale = 'YES' THEN 1 ELSE 0 END) > 0
ORDER BY
    stale DESC,
    no_stats DESC;

PROMPT
PROMPT ============================================================================
PROMPT  INCREMENTAL STATISTICS - PARTITION FRESHNESS
PROMPT ============================================================================
PROMPT
PROMPT Partition stats freshness for tables with INCREMENTAL=TRUE:

COLUMN part_analyzed FORMAT A19 HEADING "Part Analyzed"
COLUMN days_ago      FORMAT 990.9 HEADING "Days Ago"

SELECT
    ps.table_name,
    ps.partition_name,
    TO_CHAR(ps.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS part_analyzed,
    ROUND(SYSDATE - ps.last_analyzed, 1) AS days_ago,
    ps.stale
FROM
    dba_tab_statistics ps
    JOIN dba_part_tables pt
        ON ps.owner = pt.owner
        AND ps.table_name = pt.table_name
WHERE
    ps.owner = UPPER('&schema_name')
    AND ps.table_name LIKE UPPER('&table_name')
    AND ps.object_type = 'PARTITION'
    AND EXISTS (
        SELECT 1
        FROM dba_tab_stat_prefs p
        WHERE p.owner = ps.owner
        AND p.table_name = ps.table_name
        AND p.preference_name = 'INCREMENTAL'
        AND p.preference_value = 'TRUE'
    )
ORDER BY
    ps.table_name,
    ps.partition_name;

PROMPT
PROMPT ============================================================================
PROMPT  GLOBAL vs PARTITION STATISTICS CONSISTENCY
PROMPT ============================================================================
PROMPT
PROMPT Tables where global stats are older than newest partition stats:

COLUMN global_analyzed       FORMAT A19 HEADING "Global Analyzed"
COLUMN newest_part_analyzed  FORMAT A19 HEADING "Newest Part Analyzed"
COLUMN drift_days            FORMAT 990.9 HEADING "Drift Days"

SELECT
    gs.table_name,
    TO_CHAR(gs.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS global_analyzed,
    TO_CHAR(MAX(ps.last_analyzed), 'YYYY-MM-DD HH24:MI:SS') AS newest_part_analyzed,
    ROUND(MAX(ps.last_analyzed) - gs.last_analyzed, 1) AS drift_days
FROM
    dba_tab_statistics gs
    JOIN dba_tab_statistics ps
        ON gs.owner = ps.owner
        AND gs.table_name = ps.table_name
        AND ps.object_type = 'PARTITION'
WHERE
    gs.owner = UPPER('&schema_name')
    AND gs.table_name LIKE UPPER('&table_name')
    AND gs.object_type = 'TABLE'
    AND gs.partition_name IS NULL
GROUP BY
    gs.table_name,
    gs.last_analyzed
HAVING
    MAX(ps.last_analyzed) > gs.last_analyzed + 1
ORDER BY
    drift_days DESC;

PROMPT
PROMPT Notes:
PROMPT   - INCREMENTAL=TRUE allows gathering only changed partition stats
PROMPT   - Global stats are derived from partition synopses with incremental
PROMPT   - Without incremental, full table scan needed for global stats
PROMPT   - Drift between global and partition stats can cause suboptimal plans
PROMPT

UNDEFINE schema_name
UNDEFINE table_name

SET FEEDBACK ON
SET VERIFY ON
