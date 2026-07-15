-- ============================================================================
-- 12_pending_stats.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Pending (unpublished) statistics analysis
-- ============================================================================
-- Usage: @12_pending_stats.sql
-- Parameters: Schema name (prompted)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  PENDING (UNPUBLISHED) STATISTICS
PROMPT ============================================================================
PROMPT

ACCEPT schema_name CHAR PROMPT 'Enter schema name: '

PROMPT
PROMPT ============================================================================
PROMPT  PUBLISH PREFERENCE
PROMPT ============================================================================

COLUMN scope   FORMAT A30 HEADING "Scope"
COLUMN publish FORMAT A10 HEADING "Publish"

SELECT
    'Global PUBLISH preference' AS scope,
    DBMS_STATS.GET_PREFS('PUBLISH') AS publish
FROM dual;

PROMPT
PROMPT Tables with PUBLISH=FALSE (gathers go to pending, not live):

COLUMN table_name       FORMAT A30 HEADING "Table Name"
COLUMN preference_value FORMAT A10 HEADING "Publish"

SELECT
    table_name,
    preference_value
FROM
    dba_tab_stat_prefs
WHERE
    owner = UPPER('&schema_name')
    AND preference_name = 'PUBLISH'
ORDER BY
    table_name;

PROMPT
PROMPT ============================================================================
PROMPT  PENDING TABLE STATISTICS
PROMPT ============================================================================

COLUMN num_rows      FORMAT 999,999,999,999 HEADING "Pending Rows"
COLUMN live_rows     FORMAT 999,999,999,999 HEADING "Live Rows"
COLUMN blocks        FORMAT 999,999,999     HEADING "Blocks"
COLUMN pending_since FORMAT A19             HEADING "Pending Since"
COLUMN live_analyzed FORMAT A19             HEADING "Live Analyzed"

SELECT
    p.table_name,
    p.num_rows,
    p.blocks,
    TO_CHAR(p.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS pending_since,
    ts.num_rows AS live_rows,
    TO_CHAR(ts.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS live_analyzed
FROM
    dba_tab_pending_stats p
    LEFT JOIN dba_tab_statistics ts
        ON p.owner = ts.owner
        AND p.table_name = ts.table_name
        AND ts.partition_name IS NULL
        AND ts.object_type = 'TABLE'
WHERE
    p.owner = UPPER('&schema_name')
    AND p.partition_name IS NULL
ORDER BY
    p.last_analyzed DESC;

PROMPT
PROMPT ============================================================================
PROMPT  PENDING COLUMN STATISTICS (Counts per Table)
PROMPT ============================================================================

COLUMN pending_cols FORMAT 9999 HEADING "Pending Cols"

SELECT
    table_name,
    COUNT(*) AS pending_cols,
    TO_CHAR(MAX(last_analyzed), 'YYYY-MM-DD HH24:MI:SS') AS pending_since
FROM
    dba_col_pending_stats
WHERE
    owner = UPPER('&schema_name')
GROUP BY
    table_name
ORDER BY
    table_name;

PROMPT
PROMPT ============================================================================
PROMPT  PENDING INDEX STATISTICS
PROMPT ============================================================================

COLUMN index_name FORMAT A30 HEADING "Index Name"

SELECT
    i.table_name,
    i.index_name,
    i.num_rows,
    TO_CHAR(i.last_analyzed, 'YYYY-MM-DD HH24:MI:SS') AS pending_since
FROM
    dba_ind_pending_stats i
WHERE
    i.owner = UPPER('&schema_name')
ORDER BY
    i.table_name,
    i.index_name;

PROMPT
PROMPT ============================================================================
PROMPT  USEFUL COMMANDS
PROMPT ============================================================================
PROMPT
PROMPT -- Gather stats into pending (without publishing):
PROMPT EXEC DBMS_STATS.SET_TABLE_PREFS('&schema_name', 'TABLE_NAME', 'PUBLISH', 'FALSE');
PROMPT EXEC DBMS_STATS.GATHER_TABLE_STATS('&schema_name', 'TABLE_NAME');
PROMPT
PROMPT -- Test pending stats in your session before publishing:
PROMPT ALTER SESSION SET OPTIMIZER_USE_PENDING_STATISTICS = TRUE;
PROMPT
PROMPT -- Publish pending stats once validated:
PROMPT EXEC DBMS_STATS.PUBLISH_PENDING_STATS('&schema_name', 'TABLE_NAME');
PROMPT
PROMPT -- Discard pending stats:
PROMPT EXEC DBMS_STATS.DELETE_PENDING_STATS('&schema_name', 'TABLE_NAME');
PROMPT
PROMPT Notes:
PROMPT   - Pending stats sitting unpublished for a long time usually indicate a
PROMPT     forgotten PUBLISH=FALSE preference - the optimizer keeps using old
PROMPT     live statistics while gathers silently go to the pending store.
PROMPT   - Compare "Pending Rows" vs "Live Rows" to gauge how different the
PROMPT     unpublished statistics are.
PROMPT

UNDEFINE schema_name

SET FEEDBACK ON
SET VERIFY ON
