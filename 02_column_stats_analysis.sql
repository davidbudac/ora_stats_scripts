-- ============================================================================
-- 02_column_stats_analysis.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Column-level statistics and histogram analysis
-- ============================================================================
-- Usage: @02_column_stats_analysis.sql
-- Parameters: Schema name (prompted), Table name (optional)
-- Requires: DBA privileges (including SELECT on SYS.COL_USAGE$ via
--           SELECT ANY DICTIONARY, granted with the DBA role)
-- Notes: Uses a WITH FUNCTION clause (requires 12c+ and SQL*Plus 12c+) to
--        decode LOW_VALUE/HIGH_VALUE with DBMS_STATS.CONVERT_RAW_VALUE.
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  COLUMN STATISTICS ANALYSIS
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '
ACCEPT table_name CHAR DEFAULT '%' PROMPT 'Enter table name [%]: '

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
COLUMN used_in_preds      FORMAT A4              HEADING "Used"
COLUMN issues             FORMAT A20             HEADING "Issues"

PROMPT
PROMPT Column Statistics for: &schema_name..&table_name
PROMPT ============================================================================

WITH
    FUNCTION decode_raw(p_raw IN RAW, p_data_type IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_number   NUMBER;
        v_varchar2 VARCHAR2(4000);
        v_nvarchar NVARCHAR2(2000);
        v_date     DATE;
        v_bfloat   BINARY_FLOAT;
        v_bdouble  BINARY_DOUBLE;
    BEGIN
        IF p_raw IS NULL THEN
            RETURN NULL;
        END IF;
        CASE
            WHEN p_data_type IN ('NUMBER', 'FLOAT') THEN
                DBMS_STATS.CONVERT_RAW_VALUE(p_raw, v_number);
                RETURN SUBSTR(TO_CHAR(v_number), 1, 20);
            WHEN p_data_type = 'BINARY_FLOAT' THEN
                DBMS_STATS.CONVERT_RAW_VALUE(p_raw, v_bfloat);
                RETURN SUBSTR(TO_CHAR(v_bfloat), 1, 20);
            WHEN p_data_type = 'BINARY_DOUBLE' THEN
                DBMS_STATS.CONVERT_RAW_VALUE(p_raw, v_bdouble);
                RETURN SUBSTR(TO_CHAR(v_bdouble), 1, 20);
            WHEN p_data_type IN ('VARCHAR2', 'CHAR') THEN
                DBMS_STATS.CONVERT_RAW_VALUE(p_raw, v_varchar2);
                RETURN SUBSTR(v_varchar2, 1, 20);
            WHEN p_data_type IN ('NVARCHAR2', 'NCHAR') THEN
                DBMS_STATS.CONVERT_RAW_VALUE_NVARCHAR(p_raw, v_nvarchar);
                RETURN SUBSTR(TO_CHAR(v_nvarchar), 1, 20);
            WHEN p_data_type = 'DATE' OR p_data_type LIKE 'TIMESTAMP%' THEN
                DBMS_STATS.CONVERT_RAW_VALUE(p_raw, v_date);
                RETURN TO_CHAR(v_date, 'YYYY-MM-DD HH24:MI:SS');
            ELSE
                RETURN SUBSTR(RAWTOHEX(p_raw), 1, 20);
        END CASE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '?';
    END;
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
    decode_raw(cs.low_value, c.data_type)  AS low_value_d,
    decode_raw(cs.high_value, c.data_type) AS high_value_d,
    CASE
        WHEN u.equality_preds > 0 OR u.equijoin_preds > 0
             OR u.range_preds > 0 OR u.like_preds > 0 THEN 'YES'
        ELSE 'NO'
    END AS used_in_preds,
    CASE
        WHEN cs.num_distinct IS NULL THEN 'NO STATS'
        WHEN cs.histogram = 'NONE'
             AND cs.num_distinct < 254
             AND cs.num_distinct > 1
             AND (u.equality_preds > 0 OR u.equijoin_preds > 0
                  OR u.range_preds > 0 OR u.like_preds > 0) THEN 'NEEDS HIST?'
        WHEN cs.num_buckets > 254 THEN 'MANY BUCKETS'
        ELSE NULL
    END AS issues
FROM
    dba_tab_cols c
    LEFT JOIN dba_tab_col_statistics cs
        ON c.owner = cs.owner
        AND c.table_name = cs.table_name
        AND c.column_name = cs.column_name
    LEFT JOIN dba_objects ob
        ON ob.owner = c.owner
        AND ob.object_name = c.table_name
        AND ob.object_type = 'TABLE'
    LEFT JOIN sys.col_usage$ u
        ON u.obj# = ob.object_id
        AND u.intcol# = c.internal_column_id
WHERE
    c.owner = UPPER('&schema_name')
    AND c.table_name LIKE UPPER('&table_name')
    AND c.hidden_column = 'NO'
    AND c.virtual_column = 'NO'
ORDER BY
    c.table_name,
    c.column_id
/

PROMPT
PROMPT ============================================================================
PROMPT  HISTOGRAM DISTRIBUTION SUMMARY
PROMPT ============================================================================

COLUMN histogram     FORMAT A15  HEADING "Histogram Type"
COLUMN column_count  FORMAT 9999 HEADING "Columns"
COLUMN pct           FORMAT 990.9 HEADING "Pct%"

SELECT
    cs.histogram,
    COUNT(*) AS column_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM
    dba_tab_cols c
    LEFT JOIN dba_tab_col_statistics cs
        ON c.owner = cs.owner
        AND c.table_name = cs.table_name
        AND c.column_name = cs.column_name
WHERE
    c.owner = UPPER('&schema_name')
    AND c.table_name LIKE UPPER('&table_name')
    AND c.hidden_column = 'NO'
    AND c.virtual_column = 'NO'
GROUP BY
    cs.histogram
ORDER BY
    column_count DESC;

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
    dba_tab_cols c
    LEFT JOIN dba_tab_col_statistics cs
        ON c.owner = cs.owner
        AND c.table_name = cs.table_name
        AND c.column_name = cs.column_name
WHERE
    c.owner = UPPER('&schema_name')
    AND c.table_name LIKE UPPER('&table_name')
    AND c.hidden_column = 'NO'
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
PROMPT   NEEDS HIST?  - Low NDV column used in predicates but without histogram
PROMPT   MANY BUCKETS - More than 254 buckets (unusual)
PROMPT
PROMPT Notes:
PROMPT   - "Used" shows whether the column has appeared in WHERE-clause predicates
PROMPT     (from SYS.COL_USAGE$); METHOD_OPT SIZE AUTO only creates histograms
PROMPT     for columns with recorded usage.
PROMPT   - For a per-table usage report run:
PROMPT       SELECT DBMS_STATS.REPORT_COL_USAGE('&schema_name', 'TABLE_NAME') FROM dual;
PROMPT

UNDEFINE schema_name
UNDEFINE table_name

SET FEEDBACK ON
SET VERIFY ON
