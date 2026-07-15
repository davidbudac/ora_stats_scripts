-- ============================================================================
-- 06_extended_stats.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Extended statistics (column groups, expressions)
-- ============================================================================
-- Usage: @06_extended_stats.sql
-- Parameters: Schema name (prompted)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  EXTENDED STATISTICS ANALYSIS
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '

COLUMN table_name         FORMAT A25        HEADING "Table"
COLUMN extension_name     FORMAT A35        HEADING "Extension Name"
COLUMN extension          FORMAT A50        HEADING "Extension (Columns/Expression)"
COLUMN creator            FORMAT A8         HEADING "Creator"
COLUMN droppable          FORMAT A4         HEADING "Drop"
COLUMN histogram          FORMAT A15        HEADING "Histogram"
COLUMN num_distinct       FORMAT 999,999,999,999 HEADING "Distinct"

PROMPT
PROMPT ============================================================================
PROMPT  EXISTING EXTENDED STATISTICS
PROMPT ============================================================================

SELECT
    se.table_name,
    se.extension_name,
    se.extension,
    se.creator,
    se.droppable,
    cs.histogram,
    cs.num_distinct
FROM
    dba_stat_extensions se
    LEFT JOIN dba_tab_col_statistics cs
        ON se.owner = cs.owner
        AND se.table_name = cs.table_name
        AND se.extension_name = cs.column_name
WHERE
    se.owner = UPPER('&schema_name')
ORDER BY
    se.table_name,
    se.extension_name;

PROMPT
PROMPT ============================================================================
PROMPT  EXTENDED STATISTICS SUMMARY BY TYPE
PROMPT ============================================================================

COLUMN extension_type FORMAT A15 HEADING "Type"
COLUMN count          FORMAT 9999 HEADING "Count"

SELECT
    CASE
        WHEN se.extension NOT LIKE '%(%(%' THEN 'COLUMN GROUP'
        ELSE 'EXPRESSION'
    END AS extension_type,
    se.creator,
    COUNT(*) AS count
FROM
    dba_stat_extensions se
WHERE
    se.owner = UPPER('&schema_name')
GROUP BY
    CASE
        WHEN se.extension NOT LIKE '%(%(%' THEN 'COLUMN GROUP'
        ELSE 'EXPRESSION'
    END,
    se.creator
ORDER BY
    extension_type,
    creator;

PROMPT
PROMPT ============================================================================
PROMPT  SQL PLAN DIRECTIVES SUGGESTING COLUMN GROUPS
PROMPT ============================================================================
PROMPT
PROMPT Directives with DYNAMIC_SAMPLING or DYNAMIC_SAMPLING_RESULT:

COLUMN directive_id   FORMAT 99999999999999999999 HEADING "Directive ID"
COLUMN columns        FORMAT A40        HEADING "Columns"
COLUMN directive_type FORMAT A25        HEADING "Directive Type"
COLUMN state          FORMAT A12        HEADING "State"
COLUMN reason         FORMAT A30        HEADING "Reason"
COLUMN created        FORMAT A10        HEADING "Created"
COLUMN last_used      FORMAT A10        HEADING "Last Used"

SELECT
    d.directive_id,
    o.object_name AS table_name,
    LISTAGG(o.subobject_name, ', ') WITHIN GROUP (ORDER BY o.subobject_name) AS columns,
    d.type AS directive_type,
    d.state,
    d.reason,
    TO_CHAR(d.created, 'YYYY-MM-DD') AS created,
    TO_CHAR(d.last_used, 'YYYY-MM-DD') AS last_used
FROM
    dba_sql_plan_directives d
    JOIN dba_sql_plan_dir_objects o
        ON d.directive_id = o.directive_id
WHERE
    o.owner = UPPER('&schema_name')
    AND o.object_type = 'COLUMN'
    AND d.type IN ('DYNAMIC_SAMPLING', 'DYNAMIC_SAMPLING_RESULT')
    AND d.state != 'SUPERSEDED'
GROUP BY
    d.directive_id,
    o.object_name,
    d.type,
    d.state,
    d.reason,
    d.created,
    d.last_used
ORDER BY
    d.last_used DESC NULLS LAST,
    o.object_name;

PROMPT
PROMPT ============================================================================
PROMPT  RECOMMENDED COLUMN GROUPS (from Directives not yet implemented)
PROMPT ============================================================================

COLUMN suggested_columns FORMAT A40 HEADING "Suggested Columns"
COLUMN create_command    FORMAT A80 HEADING "Create Command"

SELECT
    o.object_name AS table_name,
    '(' || LISTAGG(o.subobject_name, ', ') WITHIN GROUP (ORDER BY o.subobject_name) || ')' AS suggested_columns,
    d.state,
    'EXEC DBMS_STATS.CREATE_EXTENDED_STATS(''' || UPPER('&schema_name') || ''', ''' ||
        o.object_name || ''', ''(' ||
        LISTAGG(o.subobject_name, ', ') WITHIN GROUP (ORDER BY o.subobject_name) || ')'');' AS create_command
FROM
    dba_sql_plan_directives d
    JOIN dba_sql_plan_dir_objects o
        ON d.directive_id = o.directive_id
WHERE
    o.owner = UPPER('&schema_name')
    AND o.object_type = 'COLUMN'
    AND d.type IN ('DYNAMIC_SAMPLING', 'DYNAMIC_SAMPLING_RESULT')
    AND d.state IN ('USABLE', 'NEW', 'MISSING_STATS')
    AND NOT EXISTS (
        SELECT 1
        FROM dba_stat_extensions se
        WHERE se.owner = o.owner
        AND se.table_name = o.object_name
        AND se.extension LIKE '%"' || o.subobject_name || '"%'
    )
GROUP BY
    d.directive_id,
    o.object_name,
    d.state
ORDER BY
    o.object_name;

PROMPT
PROMPT ============================================================================
PROMPT  AUTO_STAT_EXTENSIONS PREFERENCE STATUS
PROMPT ============================================================================

COLUMN scope       FORMAT A30 HEADING "Scope"
COLUMN value       FORMAT A10 HEADING "Value"
COLUMN description FORMAT A55 HEADING "Description"

SELECT
    'Global AUTO_STAT_EXTENSIONS' AS scope,
    DBMS_STATS.GET_PREFS('AUTO_STAT_EXTENSIONS') AS value,
    CASE DBMS_STATS.GET_PREFS('AUTO_STAT_EXTENSIONS')
        WHEN 'ON' THEN 'Extended stats auto-created from SQL plan directives'
        WHEN 'OFF' THEN 'Extended stats must be created manually'
        ELSE 'Unknown'
    END AS description
FROM dual;

PROMPT
PROMPT Notes:
PROMPT   - Column groups help optimizer with correlated column predicates
PROMPT   - SQL Plan Directives identify columns that need extended stats
PROMPT   - AUTO_STAT_EXTENSIONS=ON automates column group creation
PROMPT   - Expression stats support virtual column statistics
PROMPT   - CREATOR types: USER (manual), AUTO (automatic), SYSTEM (internal)
PROMPT

UNDEFINE schema_name

SET FEEDBACK ON
SET VERIFY ON
