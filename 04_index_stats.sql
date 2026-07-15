-- ============================================================================
-- 04_index_stats.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Index statistics overview
-- ============================================================================
-- Usage: @04_index_stats.sql
-- Parameters: Schema name (prompted), Table name (optional)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  INDEX STATISTICS OVERVIEW
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '
ACCEPT table_name CHAR DEFAULT '%' PROMPT 'Enter table name [%]: '

COLUMN table_name         FORMAT A25        HEADING "Table"
COLUMN index_name         FORMAT A25        HEADING "Index"
COLUMN index_type         FORMAT A12        HEADING "Type"
COLUMN uniqueness         FORMAT A4         HEADING "Uniq"
COLUMN num_rows           FORMAT 999,999,999,999  HEADING "Num Rows"
COLUMN distinct_keys      FORMAT 999,999,999,999  HEADING "Distinct Keys"
COLUMN leaf_blocks        FORMAT 999,999,999      HEADING "Leaf Blks"
COLUMN blevel             FORMAT 99               HEADING "BLvl"
COLUMN clustering_factor  FORMAT 999,999,999,999  HEADING "Clust Factor"
COLUMN cf_ratio           FORMAT 990.99           HEADING "CF Ratio"
COLUMN last_analyzed      FORMAT A19              HEADING "Last Analyzed"
COLUMN stale              FORMAT A5               HEADING "Stale"
COLUMN issues             FORMAT A20              HEADING "Issues"

PROMPT
PROMPT Index Statistics for: &schema_name..&table_name
PROMPT ============================================================================

SELECT
    i.table_name,
    i.index_name,
    i.index_type,
    SUBSTR(i.uniqueness, 1, 4) AS uniqueness,
    ist.num_rows,
    ist.distinct_keys,
    ist.leaf_blocks,
    ist.blevel,
    ist.clustering_factor,
    CASE
        WHEN t.blocks > 0 THEN ROUND(ist.clustering_factor / t.blocks, 2)
        ELSE NULL
    END AS cf_ratio,
    TO_CHAR(ist.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS last_analyzed,
    ist.stale,
    CASE
        WHEN ist.num_rows IS NULL THEN 'NO STATS'
        WHEN ist.stale = 'YES' THEN 'STALE'
        WHEN t.blocks > 0 AND ist.clustering_factor / t.blocks > 10
             AND i.uniqueness = 'NONUNIQUE'
             AND i.index_type NOT LIKE 'BITMAP%' THEN 'HIGH CF'
        ELSE NULL
    END AS issues
FROM
    dba_indexes i
    JOIN dba_tables t
        ON i.table_owner = t.owner
        AND i.table_name = t.table_name
    LEFT JOIN dba_ind_statistics ist
        ON i.owner = ist.owner
        AND i.index_name = ist.index_name
        AND ist.partition_name IS NULL
WHERE
    i.owner = UPPER('&schema_name')
    AND i.table_name LIKE UPPER('&table_name')
    AND i.index_type NOT IN ('LOB')
ORDER BY
    CASE
        WHEN ist.num_rows IS NULL THEN 1
        WHEN ist.stale = 'YES' THEN 2
        ELSE 3
    END,
    i.table_name,
    i.index_name;

PROMPT
PROMPT ============================================================================
PROMPT  CLUSTERING FACTOR ANALYSIS
PROMPT ============================================================================
PROMPT
PROMPT Indexes with poor clustering factor (CF Ratio > 5):
PROMPT (CF Ratio = Clustering Factor / Table Blocks - lower is better)
PROMPT (Bitmap indexes are excluded: clustering factor is not meaningful for them)

COLUMN table_blocks   FORMAT 999,999,999 HEADING "Table Blks"
COLUMN cf_quality     FORMAT A10         HEADING "CF Quality"

SELECT
    i.table_name,
    i.index_name,
    t.blocks AS table_blocks,
    ist.clustering_factor,
    ROUND(ist.clustering_factor / NULLIF(t.blocks, 0), 2) AS cf_ratio,
    ist.num_rows AS index_rows,
    CASE
        WHEN ist.clustering_factor IS NULL THEN 'UNKNOWN'
        WHEN ist.clustering_factor <= t.blocks THEN 'EXCELLENT'
        WHEN ist.clustering_factor <= t.blocks * 2 THEN 'GOOD'
        WHEN ist.clustering_factor <= t.blocks * 5 THEN 'FAIR'
        WHEN ist.num_rows IS NOT NULL
             AND ist.clustering_factor <= ist.num_rows THEN 'POOR'
        ELSE 'VERY POOR'
    END AS cf_quality
FROM
    dba_indexes i
    JOIN dba_tables t
        ON i.table_owner = t.owner
        AND i.table_name = t.table_name
    LEFT JOIN dba_ind_statistics ist
        ON i.owner = ist.owner
        AND i.index_name = ist.index_name
        AND ist.partition_name IS NULL
WHERE
    i.owner = UPPER('&schema_name')
    AND i.table_name LIKE UPPER('&table_name')
    AND i.index_type NOT IN ('LOB')
    AND i.index_type NOT LIKE 'BITMAP%'
    AND t.blocks > 0
    AND ist.clustering_factor / t.blocks > 5
ORDER BY
    cf_ratio DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT  SUMMARY BY INDEX TYPE
PROMPT ============================================================================

COLUMN index_count FORMAT 9999 HEADING "Count"
COLUMN no_stats    FORMAT 9999 HEADING "No Stats"
COLUMN stale       FORMAT 9999 HEADING "Stale"

SELECT
    i.index_type,
    COUNT(*) AS index_count,
    SUM(CASE WHEN ist.num_rows IS NULL THEN 1 ELSE 0 END) AS no_stats,
    SUM(CASE WHEN ist.stale = 'YES' THEN 1 ELSE 0 END) AS stale
FROM
    dba_indexes i
    LEFT JOIN dba_ind_statistics ist
        ON i.owner = ist.owner
        AND i.index_name = ist.index_name
        AND ist.partition_name IS NULL
WHERE
    i.owner = UPPER('&schema_name')
    AND i.table_name LIKE UPPER('&table_name')
    AND i.index_type NOT IN ('LOB')
GROUP BY
    i.index_type
ORDER BY
    index_count DESC;

PROMPT
PROMPT Clustering Factor Notes:
PROMPT   - CF close to # of blocks = data well ordered by index key (EXCELLENT)
PROMPT   - CF close to # of rows = data randomly ordered (POOR)
PROMPT   - High CF makes index range scans expensive
PROMPT   - Consider table reorganization for critical indexes with poor CF
PROMPT
PROMPT Issue Legend:
PROMPT   NO STATS - Index has no optimizer statistics
PROMPT   STALE    - Statistics marked as stale
PROMPT   HIGH CF  - Clustering factor > 10x table blocks (non-bitmap indexes only)
PROMPT

UNDEFINE schema_name
UNDEFINE table_name

SET FEEDBACK ON
SET VERIFY ON
