-- ============================================================================
-- 02_column_stats_analysis.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Column-level statistics and histogram analysis
-- ============================================================================
-- Usage: @02_column_stats_analysis.sql
-- Parameters: Schema name (prompted), Table name (optional)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  COLUMN STATISTICS ANALYSIS
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '
ACCEPT table_name CHAR PROMPT 'Enter table name (or % for all): '

COLUMN table_name         FORMAT A25        HEADING "Table"
COLUMN column_name        FORMAT A25        HEADING "Column"
COLUMN data_type          FORMAT A15        HEADING "Data Type"
COLUMN nullable           FORMAT A4         HEADING "Null"
COLUMN num_distinct       FORMAT 999,999,999,999  HEADING "Distinct"
COLUMN num_nulls          FORMAT 999,999,999,999  HEADING "Nulls"
COLUMN density            FORMAT 0.99999999       HEADING "Density"
COLUMN histogram          FORMAT A15             HEADING "Histogram"
COLUMN num_buckets        FORMAT 9999            HEADING "Bkts"
COLUMN low_value_d        FORMAT A20             HEADING "Low Value"
COLUMN high_value_d       FORMAT A20             HEADING "High Value"
COLUMN issues             FORMAT A20             HEADING "Issues"

PROMPT
PROMPT Column Statistics for: &schema_name..&table_name
PROMPT ============================================================================

SELECT
    c.table_name,
    c.column_name,
    c.data_type,
    c.nullable,
    cs.num_distinct,
    cs.num_nulls,
    cs.density,
    cs.histogram,
    cs.num_buckets,
    CASE
        WHEN c.data_type IN ('NUMBER', 'FLOAT', 'BINARY_FLOAT', 'BINARY_DOUBLE') THEN
            SUBSTR(TO_CHAR(UTL_RAW.CAST_TO_NUMBER(cs.low_value)), 1, 20)
        WHEN c.data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') THEN
            SUBSTR(UTL_RAW.CAST_TO_VARCHAR2(cs.low_value), 1, 20)
        WHEN c.data_type = 'DATE' THEN
            TO_CHAR(TO_DATE(TO_CHAR(UTL_RAW.CAST_TO_NUMBER(SUBSTR(cs.low_value,1,2))-100,'FM00')
                ||TO_CHAR(UTL_RAW.CAST_TO_NUMBER(SUBSTR(cs.low_value,3,2))-100,'FM00')
                ||TO_CHAR(UTL_RAW.CAST_TO_NUMBER(SUBSTR(cs.low_value,5,2)),'FM00')
                ||TO_CHAR(UTL_RAW.CAST_TO_NUMBER(SUBSTR(cs.low_value,7,2)),'FM00'),
                'YYYYMMDD'), 'YYYY-MM-DD')
        ELSE '...'
    END AS low_value_d,
    CASE
        WHEN c.data_type IN ('NUMBER', 'FLOAT', 'BINARY_FLOAT', 'BINARY_DOUBLE') THEN
            SUBSTR(TO_CHAR(UTL_RAW.CAST_TO_NUMBER(cs.high_value)), 1, 20)
        WHEN c.data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') THEN
            SUBSTR(UTL_RAW.CAST_TO_VARCHAR2(cs.high_value), 1, 20)
        WHEN c.data_type = 'DATE' THEN
            TO_CHAR(TO_DATE(TO_CHAR(UTL_RAW.CAST_TO_NUMBER(SUBSTR(cs.high_value,1,2))-100,'FM00')
                ||TO_CHAR(UTL_RAW.CAST_TO_NUMBER(SUBSTR(cs.high_value,3,2))-100,'FM00')
                ||TO_CHAR(UTL_RAW.CAST_TO_NUMBER(SUBSTR(cs.high_value,5,2)),'FM00')
                ||TO_CHAR(UTL_RAW.CAST_TO_NUMBER(SUBSTR(cs.high_value,7,2)),'FM00'),
                'YYYYMMDD'), 'YYYY-MM-DD')
        ELSE '...'
    END AS high_value_d,
    CASE
        WHEN cs.num_distinct IS NULL THEN 'NO STATS'
        WHEN cs.histogram = 'NONE' AND cs.num_distinct < 254
             AND cs.num_distinct > 1 THEN 'NEEDS HIST?'
        WHEN cs.num_buckets > 254 THEN 'MANY BUCKETS'
        ELSE NULL
    END AS issues
FROM
    dba_tab_columns c
    LEFT JOIN dba_tab_col_statistics cs
        ON c.owner = cs.owner
        AND c.table_name = cs.table_name
        AND c.column_name = cs.column_name
WHERE
    c.owner = UPPER('&schema_name')
    AND c.table_name LIKE UPPER('&table_name')
    AND c.virtual_column = 'NO'
ORDER BY
    c.table_name,
    c.column_id;

PROMPT
PROMPT ============================================================================
PROMPT  HISTOGRAM DISTRIBUTION SUMMARY
PROMPT ============================================================================

SELECT
    cs.histogram,
    COUNT(*) AS column_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM
    dba_tab_columns c
    LEFT JOIN dba_tab_col_statistics cs
        ON c.owner = cs.owner
        AND c.table_name = cs.table_name
        AND c.column_name = cs.column_name
WHERE
    c.owner = UPPER('&schema_name')
    AND c.table_name LIKE UPPER('&table_name')
    AND c.virtual_column = 'NO'
GROUP BY
    cs.histogram
ORDER BY
    column_count DESC;

COLUMN histogram     FORMAT A15  HEADING "Histogram Type"
COLUMN column_count  FORMAT 9999 HEADING "Columns"
COLUMN pct           FORMAT 990.9 HEADING "Pct%"

PROMPT
PROMPT ============================================================================
PROMPT  COLUMNS WITHOUT STATISTICS
PROMPT ============================================================================

SELECT
    c.table_name,
    c.column_name,
    c.data_type,
    c.nullable
FROM
    dba_tab_columns c
    LEFT JOIN dba_tab_col_statistics cs
        ON c.owner = cs.owner
        AND c.table_name = cs.table_name
        AND c.column_name = cs.column_name
WHERE
    c.owner = UPPER('&schema_name')
    AND c.table_name LIKE UPPER('&table_name')
    AND c.virtual_column = 'NO'
    AND cs.num_distinct IS NULL
ORDER BY
    c.table_name,
    c.column_id;

PROMPT
PROMPT Histogram Types:
PROMPT   NONE           - No histogram
PROMPT   FREQUENCY      - Each distinct value has its own bucket (NDV <= 254)
PROMPT   TOP-FREQUENCY  - Top-N frequent values (NDV > 254, popular values fit in 254 buckets)
PROMPT   HYBRID         - Mix of frequency and height-balanced (NDV > 254)
PROMPT   HEIGHT BALANCED - Legacy histogram type (pre-12c)
PROMPT
PROMPT Issue Legend:
PROMPT   NO STATS     - Column has no statistics
PROMPT   NEEDS HIST?  - Low NDV column without histogram (consider FOR COLUMNS)
PROMPT   MANY BUCKETS - More than 254 buckets (unusual)
PROMPT

SET FEEDBACK ON
SET VERIFY ON
