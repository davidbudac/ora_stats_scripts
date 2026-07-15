-- ============================================================================
-- 10_stats_health_check.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Comprehensive health check with actionable recommendations
-- ============================================================================
-- Usage: @10_stats_health_check.sql
-- Parameters: Schema name (prompted)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  OPTIMIZER STATISTICS HEALTH CHECK
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT
PROMPT ============================================================================
PROMPT  1. STATISTICS COVERAGE SUMMARY
PROMPT ============================================================================

COLUMN metric             FORMAT A40        HEADING "Metric"
COLUMN value              FORMAT A15        HEADING "Value"
COLUMN status             FORMAT A10        HEADING "Status"

SELECT
    'Total Tables' AS metric,
    TO_CHAR(COUNT(*)) AS value,
    'INFO' AS status
FROM dba_tables
WHERE owner = UPPER('&schema_name')
AND temporary = 'N' AND secondary = 'N' AND nested = 'NO'
UNION ALL
SELECT
    'Tables Without Statistics',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 0 THEN 'WARNING' ELSE 'OK' END
FROM dba_tables t
LEFT JOIN dba_tab_statistics ts
    ON t.owner = ts.owner AND t.table_name = ts.table_name AND ts.partition_name IS NULL
WHERE t.owner = UPPER('&schema_name')
AND t.temporary = 'N' AND t.secondary = 'N' AND t.nested = 'NO'
AND NOT EXISTS (
    SELECT 1 FROM dba_external_tables x
    WHERE x.owner = t.owner AND x.table_name = t.table_name
)
AND ts.num_rows IS NULL
UNION ALL
SELECT
    'Stale Table Statistics',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 0 THEN 'WARNING' ELSE 'OK' END
FROM dba_tab_statistics
WHERE owner = UPPER('&schema_name')
AND object_type = 'TABLE' AND partition_name IS NULL
AND stale = 'YES'
UNION ALL
SELECT
    'Tables with Locked Statistics',
    TO_CHAR(COUNT(*)),
    'INFO'
FROM dba_tab_statistics
WHERE owner = UPPER('&schema_name')
AND object_type = 'TABLE' AND partition_name IS NULL
AND stattype_locked IS NOT NULL
UNION ALL
SELECT
    'Statistics Older Than 30 Days',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 5 THEN 'WARNING' ELSE 'OK' END
FROM dba_tab_statistics
WHERE owner = UPPER('&schema_name')
AND object_type = 'TABLE' AND partition_name IS NULL
AND last_analyzed < SYSDATE - 30
AND num_rows IS NOT NULL;

PROMPT
PROMPT ============================================================================
PROMPT  2. INDEX STATISTICS HEALTH
PROMPT ============================================================================

SELECT
    'Total Indexes' AS metric,
    TO_CHAR(COUNT(*)) AS value,
    'INFO' AS status
FROM dba_indexes
WHERE owner = UPPER('&schema_name')
AND index_type != 'LOB'
UNION ALL
SELECT
    'Indexes Without Statistics',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 0 THEN 'WARNING' ELSE 'OK' END
FROM dba_indexes i
LEFT JOIN dba_ind_statistics ist
    ON i.owner = ist.owner AND i.index_name = ist.index_name AND ist.partition_name IS NULL
WHERE i.owner = UPPER('&schema_name')
AND i.index_type != 'LOB'
AND ist.num_rows IS NULL
UNION ALL
SELECT
    'Indexes with Poor Clustering Factor',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 0 THEN 'INFO' ELSE 'OK' END
FROM dba_indexes i
JOIN dba_tables t ON i.table_owner = t.owner AND i.table_name = t.table_name
LEFT JOIN dba_ind_statistics ist
    ON i.owner = ist.owner AND i.index_name = ist.index_name AND ist.partition_name IS NULL
WHERE i.owner = UPPER('&schema_name')
AND i.index_type != 'LOB'
AND t.blocks > 0
AND ist.clustering_factor / t.blocks > 10;

PROMPT
PROMPT ============================================================================
PROMPT  3. HISTOGRAM ANALYSIS
PROMPT ============================================================================

SELECT
    'Columns with FREQUENCY Histogram' AS metric,
    TO_CHAR(COUNT(*)) AS value,
    'INFO' AS status
FROM dba_tab_col_statistics
WHERE owner = UPPER('&schema_name')
AND histogram = 'FREQUENCY'
UNION ALL
SELECT
    'Columns with TOP-FREQUENCY Histogram',
    TO_CHAR(COUNT(*)),
    'INFO'
FROM dba_tab_col_statistics
WHERE owner = UPPER('&schema_name')
AND histogram = 'TOP-FREQUENCY'
UNION ALL
SELECT
    'Columns with HYBRID Histogram',
    TO_CHAR(COUNT(*)),
    'INFO'
FROM dba_tab_col_statistics
WHERE owner = UPPER('&schema_name')
AND histogram = 'HYBRID'
UNION ALL
SELECT
    'Columns with HEIGHT BALANCED (Legacy)',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 0 THEN 'INFO' ELSE 'OK' END
FROM dba_tab_col_statistics
WHERE owner = UPPER('&schema_name')
AND histogram = 'HEIGHT BALANCED'
UNION ALL
SELECT
    'Low NDV Columns Without Histogram',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 10 THEN 'INFO' ELSE 'OK' END
FROM dba_tab_col_statistics
WHERE owner = UPPER('&schema_name')
AND histogram = 'NONE'
AND num_distinct BETWEEN 2 AND 254;

PROMPT
PROMPT ============================================================================
PROMPT  4. PARTITIONED TABLES ANALYSIS
PROMPT ============================================================================

SELECT
    'Partitioned Tables' AS metric,
    TO_CHAR(COUNT(*)) AS value,
    'INFO' AS status
FROM dba_part_tables
WHERE owner = UPPER('&schema_name')
UNION ALL
SELECT
    'Partitioned Tables with INCREMENTAL=TRUE',
    TO_CHAR(COUNT(*)),
    'INFO'
FROM dba_tab_stat_prefs
WHERE owner = UPPER('&schema_name')
AND preference_name = 'INCREMENTAL'
AND preference_value = 'TRUE'
UNION ALL
SELECT
    'Stale Partitions',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 0 THEN 'WARNING' ELSE 'OK' END
FROM dba_tab_statistics
WHERE owner = UPPER('&schema_name')
AND object_type = 'PARTITION'
AND stale = 'YES';

PROMPT
PROMPT ============================================================================
PROMPT  5. EXTENDED STATISTICS
PROMPT ============================================================================

SELECT
    'Column Group Extensions' AS metric,
    TO_CHAR(COUNT(*)) AS value,
    'INFO' AS status
FROM dba_stat_extensions
WHERE owner = UPPER('&schema_name')
AND extension NOT LIKE '%(%(%'
UNION ALL
SELECT
    'Expression Extensions',
    TO_CHAR(COUNT(*)),
    'INFO'
FROM dba_stat_extensions
WHERE owner = UPPER('&schema_name')
AND extension LIKE '%(%(%'
UNION ALL
SELECT
    'Pending SQL Plan Directives',
    TO_CHAR(COUNT(DISTINCT d.directive_id)),
    CASE WHEN COUNT(DISTINCT d.directive_id) > 5 THEN 'INFO' ELSE 'OK' END
FROM dba_sql_plan_directives d
JOIN dba_sql_plan_dir_objects o ON d.directive_id = o.directive_id
WHERE o.owner = UPPER('&schema_name')
AND d.type IN ('DYNAMIC_SAMPLING', 'DYNAMIC_SAMPLING_RESULT')
AND d.state IN ('USABLE', 'NEW', 'MISSING_STATS');

PROMPT
PROMPT ============================================================================
PROMPT  6. AUTO STATS JOB STATUS
PROMPT ============================================================================

SELECT
    'Auto Optimizer Stats Collection' AS metric,
    status AS value,
    CASE WHEN status = 'ENABLED' THEN 'OK' ELSE 'WARNING' END AS status
FROM dba_autotask_client
WHERE client_name = 'auto optimizer stats collection';

PROMPT
PROMPT ============================================================================
PROMPT  7. RECENT OPERATIONS STATUS (Last 7 Days)
PROMPT ============================================================================

SELECT
    'Total Operations' AS metric,
    TO_CHAR(COUNT(*)) AS value,
    'INFO' AS status
FROM dba_optstat_operations
WHERE start_time > SYSDATE - 7
AND target LIKE UPPER('&schema_name') || '.%'
UNION ALL
SELECT
    'Failed Operations',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 0 THEN 'WARNING' ELSE 'OK' END
FROM dba_optstat_operations
WHERE start_time > SYSDATE - 7
AND target LIKE UPPER('&schema_name') || '.%'
AND status = 'FAILED'
UNION ALL
SELECT
    'Timed Out Operations',
    TO_CHAR(COUNT(*)),
    CASE WHEN COUNT(*) > 0 THEN 'WARNING' ELSE 'OK' END
FROM dba_optstat_operations
WHERE start_time > SYSDATE - 7
AND target LIKE UPPER('&schema_name') || '.%'
AND status = 'TIMED OUT';

PROMPT
PROMPT ============================================================================
PROMPT  8. GLOBAL PREFERENCES CHECK
PROMPT ============================================================================

SELECT
    preference_name AS metric,
    preference_value AS value,
    CASE
        WHEN preference_name = 'STALE_PERCENT' AND TO_NUMBER(preference_value) > 20 THEN 'INFO'
        WHEN preference_name = 'ESTIMATE_PERCENT' AND preference_value != 'DBMS_STATS.AUTO_SAMPLE_SIZE' THEN 'INFO'
        WHEN preference_name = 'AUTO_STAT_EXTENSIONS' AND preference_value = 'OFF' THEN 'INFO'
        ELSE 'OK'
    END AS status
FROM (
    SELECT 'STALE_PERCENT' AS preference_name, DBMS_STATS.GET_PREFS('STALE_PERCENT') AS preference_value FROM dual
    UNION ALL
    SELECT 'ESTIMATE_PERCENT', DBMS_STATS.GET_PREFS('ESTIMATE_PERCENT') FROM dual
    UNION ALL
    SELECT 'METHOD_OPT', DBMS_STATS.GET_PREFS('METHOD_OPT') FROM dual
    UNION ALL
    SELECT 'AUTO_STAT_EXTENSIONS', DBMS_STATS.GET_PREFS('AUTO_STAT_EXTENSIONS') FROM dual
    UNION ALL
    SELECT 'INCREMENTAL', DBMS_STATS.GET_PREFS('INCREMENTAL') FROM dual
);

PROMPT
PROMPT ============================================================================
PROMPT  9. RECOMMENDATIONS
PROMPT ============================================================================
PROMPT

DECLARE
    v_count NUMBER;
    v_recommendation VARCHAR2(200);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Based on the analysis above, consider the following actions:');
    DBMS_OUTPUT.PUT_LINE('');

    -- Check for tables without stats
    SELECT COUNT(*) INTO v_count
    FROM dba_tables t
    LEFT JOIN dba_tab_statistics ts
        ON t.owner = ts.owner AND t.table_name = ts.table_name AND ts.partition_name IS NULL
    WHERE t.owner = UPPER('&schema_name')
    AND t.temporary = 'N' AND t.secondary = 'N' AND t.nested = 'NO'
    AND NOT EXISTS (
        SELECT 1 FROM dba_external_tables x
        WHERE x.owner = t.owner AND x.table_name = t.table_name
    )
    AND ts.num_rows IS NULL;

    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[HIGH] ' || v_count || ' tables have no statistics.');
        DBMS_OUTPUT.PUT_LINE('       Run: EXEC DBMS_STATS.GATHER_SCHEMA_STATS(''' || UPPER('&schema_name') || ''', OPTIONS=>''GATHER EMPTY'');');
        DBMS_OUTPUT.PUT_LINE('');
    END IF;

    -- Check for stale stats
    SELECT COUNT(*) INTO v_count
    FROM dba_tab_statistics
    WHERE owner = UPPER('&schema_name')
    AND object_type = 'TABLE' AND partition_name IS NULL
    AND stale = 'YES';

    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[MEDIUM] ' || v_count || ' tables have stale statistics.');
        DBMS_OUTPUT.PUT_LINE('         Run: EXEC DBMS_STATS.GATHER_SCHEMA_STATS(''' || UPPER('&schema_name') || ''', OPTIONS=>''GATHER STALE'');');
        DBMS_OUTPUT.PUT_LINE('');
    END IF;

    -- Check for partitioned tables without incremental
    SELECT COUNT(*) INTO v_count
    FROM dba_part_tables pt
    WHERE pt.owner = UPPER('&schema_name')
    AND NOT EXISTS (
        SELECT 1 FROM dba_tab_stat_prefs p
        WHERE p.owner = pt.owner AND p.table_name = pt.table_name
        AND p.preference_name = 'INCREMENTAL' AND p.preference_value = 'TRUE'
    );

    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[INFO] ' || v_count || ' partitioned tables do not have INCREMENTAL=TRUE.');
        DBMS_OUTPUT.PUT_LINE('       Consider enabling incremental statistics for faster gathering.');
        DBMS_OUTPUT.PUT_LINE('');
    END IF;

    -- Check AUTO_STAT_EXTENSIONS
    IF DBMS_STATS.GET_PREFS('AUTO_STAT_EXTENSIONS') = 'OFF' THEN
        SELECT COUNT(DISTINCT d.directive_id) INTO v_count
        FROM dba_sql_plan_directives d
        JOIN dba_sql_plan_dir_objects o ON d.directive_id = o.directive_id
        WHERE o.owner = UPPER('&schema_name')
        AND d.type IN ('DYNAMIC_SAMPLING', 'DYNAMIC_SAMPLING_RESULT')
        AND d.state IN ('USABLE', 'NEW', 'MISSING_STATS');

        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('[INFO] ' || v_count || ' SQL Plan Directives suggest column groups.');
            DBMS_OUTPUT.PUT_LINE('       Consider: EXEC DBMS_STATS.SET_GLOBAL_PREFS(''AUTO_STAT_EXTENSIONS'', ''ON'');');
            DBMS_OUTPUT.PUT_LINE('');
        END IF;
    END IF;

    -- Check for old stats
    SELECT COUNT(*) INTO v_count
    FROM dba_tab_statistics
    WHERE owner = UPPER('&schema_name')
    AND object_type = 'TABLE' AND partition_name IS NULL
    AND last_analyzed < SYSDATE - 30
    AND num_rows IS NOT NULL;

    IF v_count > 5 THEN
        DBMS_OUTPUT.PUT_LINE('[INFO] ' || v_count || ' tables have statistics older than 30 days.');
        DBMS_OUTPUT.PUT_LINE('       Review if these tables have changed and need refresh.');
        DBMS_OUTPUT.PUT_LINE('');
    END IF;

    -- Check auto stats job
    SELECT COUNT(*) INTO v_count
    FROM dba_autotask_client
    WHERE client_name = 'auto optimizer stats collection'
    AND status != 'ENABLED';

    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[WARNING] Auto Optimizer Stats Collection is not enabled.');
        DBMS_OUTPUT.PUT_LINE('          Consider enabling automatic statistics gathering.');
        DBMS_OUTPUT.PUT_LINE('');
    END IF;

    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('Health check complete for schema: ' || UPPER('&schema_name'));
    DBMS_OUTPUT.PUT_LINE('============================================================================');
END;
/

PROMPT
PROMPT Status Legend:
PROMPT   OK      - No issues detected
PROMPT   INFO    - Informational, may warrant review
PROMPT   WARNING - Action recommended
PROMPT

UNDEFINE schema_name

SET SERVEROUTPUT OFF
SET FEEDBACK ON
SET VERIFY ON
