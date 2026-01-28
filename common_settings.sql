-- ============================================================================
-- common_settings.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Shared SQL*Plus formatting and settings
-- ============================================================================
-- Usage: Called by other scripts via @@common_settings.sql
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TAB OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET UNDERLINE =
SET NUMWIDTH 15

-- Formatting for common columns used across scripts
COLUMN owner              FORMAT A30        HEADING "Owner"
COLUMN table_name         FORMAT A30        HEADING "Table Name"
COLUMN column_name        FORMAT A30        HEADING "Column Name"
COLUMN index_name         FORMAT A30        HEADING "Index Name"
COLUMN partition_name     FORMAT A30        HEADING "Partition"
COLUMN subpartition_name  FORMAT A30        HEADING "Subpartition"

COLUMN num_rows           FORMAT 999,999,999,999  HEADING "Num Rows"
COLUMN blocks             FORMAT 999,999,999      HEADING "Blocks"
COLUMN avg_row_len        FORMAT 999,999          HEADING "Avg Row Len"
COLUMN sample_size        FORMAT 999,999,999,999  HEADING "Sample Size"

COLUMN last_analyzed      FORMAT A19        HEADING "Last Analyzed"
COLUMN stale              FORMAT A5         HEADING "Stale"
COLUMN stattype_locked    FORMAT A6         HEADING "Locked"

COLUMN num_distinct       FORMAT 999,999,999,999  HEADING "Distinct"
COLUMN num_nulls          FORMAT 999,999,999,999  HEADING "Nulls"
COLUMN density            FORMAT 0.999999999      HEADING "Density"
COLUMN num_buckets        FORMAT 9999             HEADING "Buckets"
COLUMN histogram          FORMAT A15             HEADING "Histogram"

COLUMN preference_name    FORMAT A30        HEADING "Preference"
COLUMN preference_value   FORMAT A40        HEADING "Value"

COLUMN status             FORMAT A12        HEADING "Status"
COLUMN operation          FORMAT A25        HEADING "Operation"
COLUMN target             FORMAT A50        HEADING "Target"

COLUMN issues             FORMAT A50        HEADING "Issues"
COLUMN flag               FORMAT A5         HEADING "Flag"

-- Date format for consistency
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';

-- Prompt formatting
SET SQLPROMPT ""
