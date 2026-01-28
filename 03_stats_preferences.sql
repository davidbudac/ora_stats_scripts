-- ============================================================================
-- 03_stats_preferences.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- DBMS_STATS preferences at global, schema, and table levels
-- ============================================================================
-- Usage: @03_stats_preferences.sql
-- Parameters: Schema name (prompted)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  STATISTICS PREFERENCES
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '

COLUMN preference_name    FORMAT A35        HEADING "Preference"
COLUMN global_value       FORMAT A30        HEADING "Global Value"
COLUMN schema_value       FORMAT A30        HEADING "Schema Value"
COLUMN default_value      FORMAT A30        HEADING "Default"
COLUMN is_default         FORMAT A3         HEADING "Def"

PROMPT
PROMPT ============================================================================
PROMPT  GLOBAL PREFERENCES
PROMPT ============================================================================

SELECT
    'APPROXIMATE_NDV_ALGORITHM' AS preference_name,
    DBMS_STATS.GET_PREFS('APPROXIMATE_NDV_ALGORITHM') AS global_value,
    'REPEAT OR HYPERLOGLOG' AS default_value,
    CASE WHEN DBMS_STATS.GET_PREFS('APPROXIMATE_NDV_ALGORITHM') IN ('REPEAT OR HYPERLOGLOG', 'ADAPTIVE SAMPLING') THEN 'Yes' ELSE 'No' END AS is_default
FROM dual
UNION ALL
SELECT
    'AUTO_STAT_EXTENSIONS',
    DBMS_STATS.GET_PREFS('AUTO_STAT_EXTENSIONS'),
    'OFF',
    CASE WHEN DBMS_STATS.GET_PREFS('AUTO_STAT_EXTENSIONS') = 'OFF' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'CASCADE',
    DBMS_STATS.GET_PREFS('CASCADE'),
    'DBMS_STATS.AUTO_CASCADE',
    CASE WHEN DBMS_STATS.GET_PREFS('CASCADE') = 'DBMS_STATS.AUTO_CASCADE' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'CONCURRENT',
    DBMS_STATS.GET_PREFS('CONCURRENT'),
    'OFF',
    CASE WHEN DBMS_STATS.GET_PREFS('CONCURRENT') = 'OFF' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'DEGREE',
    DBMS_STATS.GET_PREFS('DEGREE'),
    'NULL (auto)',
    CASE WHEN DBMS_STATS.GET_PREFS('DEGREE') IS NULL OR DBMS_STATS.GET_PREFS('DEGREE') = 'NULL' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'ESTIMATE_PERCENT',
    DBMS_STATS.GET_PREFS('ESTIMATE_PERCENT'),
    'DBMS_STATS.AUTO_SAMPLE_SIZE',
    CASE WHEN DBMS_STATS.GET_PREFS('ESTIMATE_PERCENT') = 'DBMS_STATS.AUTO_SAMPLE_SIZE' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'GLOBAL_TEMP_TABLE_STATS',
    DBMS_STATS.GET_PREFS('GLOBAL_TEMP_TABLE_STATS'),
    'SESSION',
    CASE WHEN DBMS_STATS.GET_PREFS('GLOBAL_TEMP_TABLE_STATS') = 'SESSION' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'GRANULARITY',
    DBMS_STATS.GET_PREFS('GRANULARITY'),
    'AUTO',
    CASE WHEN DBMS_STATS.GET_PREFS('GRANULARITY') = 'AUTO' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'INCREMENTAL',
    DBMS_STATS.GET_PREFS('INCREMENTAL'),
    'FALSE',
    CASE WHEN DBMS_STATS.GET_PREFS('INCREMENTAL') = 'FALSE' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'INCREMENTAL_STALENESS',
    DBMS_STATS.GET_PREFS('INCREMENTAL_STALENESS'),
    'NULL',
    CASE WHEN DBMS_STATS.GET_PREFS('INCREMENTAL_STALENESS') IS NULL THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'METHOD_OPT',
    DBMS_STATS.GET_PREFS('METHOD_OPT'),
    'FOR ALL COLUMNS SIZE AUTO',
    CASE WHEN DBMS_STATS.GET_PREFS('METHOD_OPT') = 'FOR ALL COLUMNS SIZE AUTO' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'NO_INVALIDATE',
    DBMS_STATS.GET_PREFS('NO_INVALIDATE'),
    'DBMS_STATS.AUTO_INVALIDATE',
    CASE WHEN DBMS_STATS.GET_PREFS('NO_INVALIDATE') = 'DBMS_STATS.AUTO_INVALIDATE' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'OPTIONS',
    DBMS_STATS.GET_PREFS('OPTIONS'),
    'GATHER',
    CASE WHEN DBMS_STATS.GET_PREFS('OPTIONS') = 'GATHER' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'PUBLISH',
    DBMS_STATS.GET_PREFS('PUBLISH'),
    'TRUE',
    CASE WHEN DBMS_STATS.GET_PREFS('PUBLISH') = 'TRUE' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'STALE_PERCENT',
    DBMS_STATS.GET_PREFS('STALE_PERCENT'),
    '10',
    CASE WHEN DBMS_STATS.GET_PREFS('STALE_PERCENT') = '10' THEN 'Yes' ELSE 'No' END
FROM dual
UNION ALL
SELECT
    'TABLE_CACHED_BLOCKS',
    DBMS_STATS.GET_PREFS('TABLE_CACHED_BLOCKS'),
    '1',
    CASE WHEN DBMS_STATS.GET_PREFS('TABLE_CACHED_BLOCKS') = '1' THEN 'Yes' ELSE 'No' END
FROM dual
ORDER BY preference_name;

PROMPT
PROMPT ============================================================================
PROMPT  TABLE-LEVEL PREFERENCE OVERRIDES FOR SCHEMA: &schema_name
PROMPT ============================================================================

COLUMN table_name         FORMAT A30        HEADING "Table Name"
COLUMN preference_name    FORMAT A30        HEADING "Preference"
COLUMN preference_value   FORMAT A40        HEADING "Value"

SELECT
    table_name,
    preference_name,
    preference_value
FROM
    dba_tab_stat_prefs
WHERE
    owner = UPPER('&schema_name')
ORDER BY
    table_name,
    preference_name;

PROMPT
PROMPT ============================================================================
PROMPT  INCREMENTAL STATISTICS CONFIGURATION
PROMPT ============================================================================
PROMPT
PROMPT Tables with INCREMENTAL=TRUE (should be partitioned):

SELECT
    p.table_name,
    p.preference_value AS incremental,
    t.partitioned,
    CASE
        WHEN t.partitioned = 'NO' THEN '** WARNING: Not partitioned **'
        ELSE 'OK'
    END AS status
FROM
    dba_tab_stat_prefs p
    JOIN dba_tables t
        ON p.owner = t.owner
        AND p.table_name = t.table_name
WHERE
    p.owner = UPPER('&schema_name')
    AND p.preference_name = 'INCREMENTAL'
    AND p.preference_value = 'TRUE'
ORDER BY
    p.table_name;

PROMPT
PROMPT ============================================================================
PROMPT  TABLES WITH LOCKED STATISTICS
PROMPT ============================================================================

SELECT
    table_name,
    stattype_locked AS lock_type
FROM
    dba_tab_statistics
WHERE
    owner = UPPER('&schema_name')
    AND partition_name IS NULL
    AND stattype_locked IS NOT NULL
ORDER BY
    table_name;

COLUMN lock_type FORMAT A10 HEADING "Lock Type"

PROMPT
PROMPT Notes:
PROMPT   - Non-default global preferences are highlighted with is_default='No'
PROMPT   - INCREMENTAL=TRUE should only be used on partitioned tables
PROMPT   - AUTO_STAT_EXTENSIONS=ON enables automatic extended statistics
PROMPT   - CONCURRENT=TRUE can speed up stats gathering on large schemas
PROMPT   - Locked statistics will not be updated by DBMS_STATS.GATHER_*
PROMPT

SET FEEDBACK ON
SET VERIFY ON
