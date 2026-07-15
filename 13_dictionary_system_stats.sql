-- ============================================================================
-- 13_dictionary_system_stats.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Dictionary, fixed object, and system (workload) statistics
-- ============================================================================
-- Usage: @13_dictionary_system_stats.sql
-- Parameters: None (database-wide view)
-- Requires: DBA privileges (SELECT on SYS.AUX_STATS$ via SELECT ANY DICTIONARY)
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  DICTIONARY, FIXED OBJECT AND SYSTEM STATISTICS
PROMPT ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT  SYSTEM (WORKLOAD) STATISTICS - SYS.AUX_STATS$
PROMPT ============================================================================

COLUMN sname FORMAT A20        HEADING "Section"
COLUMN pname FORMAT A15        HEADING "Parameter"
COLUMN pval1 FORMAT 999,999,990.99 HEADING "Value"
COLUMN pval2 FORMAT A30        HEADING "Text Value"

SELECT
    sname,
    pname,
    pval1,
    pval2
FROM
    sys.aux_stats$
ORDER BY
    sname,
    pname;

PROMPT
PROMPT ============================================================================
PROMPT  DICTIONARY STATISTICS FRESHNESS (SYS / SYSTEM Schemas)
PROMPT ============================================================================

COLUMN owner          FORMAT A10  HEADING "Owner"
COLUMN total_tables   FORMAT 99999 HEADING "Tables"
COLUMN with_stats     FORMAT 99999 HEADING "With Stats"
COLUMN no_stats       FORMAT 99999 HEADING "No Stats"
COLUMN stale_tables   FORMAT 99999 HEADING "Stale"
COLUMN oldest_analyzed FORMAT A19 HEADING "Oldest Analyzed"
COLUMN newest_analyzed FORMAT A19 HEADING "Newest Analyzed"

SELECT
    owner,
    COUNT(*) AS total_tables,
    SUM(CASE WHEN num_rows IS NOT NULL THEN 1 ELSE 0 END) AS with_stats,
    SUM(CASE WHEN num_rows IS NULL THEN 1 ELSE 0 END) AS no_stats,
    SUM(CASE WHEN stale_stats = 'YES' THEN 1 ELSE 0 END) AS stale_tables,
    TO_CHAR(MIN(last_analyzed), 'YYYY-MM-DD HH24:MI:SS') AS oldest_analyzed,
    TO_CHAR(MAX(last_analyzed), 'YYYY-MM-DD HH24:MI:SS') AS newest_analyzed
FROM
    dba_tab_statistics
WHERE
    owner IN ('SYS', 'SYSTEM')
    AND object_type = 'TABLE'
    AND partition_name IS NULL
GROUP BY
    owner
ORDER BY
    owner;

PROMPT
PROMPT ============================================================================
PROMPT  FIXED OBJECT (X$) STATISTICS COVERAGE
PROMPT ============================================================================

COLUMN fixed_tables    FORMAT 99999 HEADING "Fixed Tables"
COLUMN with_stats      FORMAT 99999 HEADING "With Stats"
COLUMN no_stats        FORMAT 99999 HEADING "No Stats"
COLUMN last_gathered   FORMAT A19   HEADING "Last Gathered"

SELECT
    COUNT(*) AS fixed_tables,
    SUM(CASE WHEN last_analyzed IS NOT NULL THEN 1 ELSE 0 END) AS with_stats,
    SUM(CASE WHEN last_analyzed IS NULL THEN 1 ELSE 0 END) AS no_stats,
    TO_CHAR(MAX(last_analyzed), 'YYYY-MM-DD HH24:MI:SS') AS last_gathered
FROM
    dba_tab_statistics
WHERE
    object_type = 'FIXED TABLE';

PROMPT
PROMPT ============================================================================
PROMPT  USEFUL COMMANDS
PROMPT ============================================================================
PROMPT
PROMPT -- Gather dictionary statistics (SYS, SYSTEM and other internal schemas):
PROMPT EXEC DBMS_STATS.GATHER_DICTIONARY_STATS;
PROMPT
PROMPT -- Gather fixed object (X$) statistics - do this under representative load:
PROMPT EXEC DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;
PROMPT
PROMPT -- Gather NOWORKLOAD system statistics:
PROMPT EXEC DBMS_STATS.GATHER_SYSTEM_STATS('NOWORKLOAD');
PROMPT
PROMPT -- Reset system statistics to defaults:
PROMPT EXEC DBMS_STATS.DELETE_SYSTEM_STATS;
PROMPT
PROMPT Notes:
PROMPT   - Dictionary stats: gathered by the auto stats task, but verify after
PROMPT     big dictionary changes (mass partition maintenance, upgrades).
PROMPT   - Fixed object stats: NOT gathered automatically before 12c R2; missing
PROMPT     stats on X$ tables can cause poor plans for internal / V$ queries.
PROMPT   - System stats (AUX_STATS$): most systems are best served by the
PROMPT     defaults (CPUSPEEDNW/IOSEEKTIM/IOTFRSPEED only); Oracle recommends
PROMPT     against workload system stats unless you have a proven need.
PROMPT

SET FEEDBACK ON
SET VERIFY ON
