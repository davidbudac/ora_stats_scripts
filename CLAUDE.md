# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Oracle Optimizer Statistics Analysis Toolkit** - a collection of SQL*Plus scripts for analyzing and troubleshooting Oracle database optimizer statistics. All scripts require DBA privileges and are designed to run in SQL*Plus.

## Running Scripts

```bash
# In SQL*Plus, connected as a DBA user:
@01_table_stats_overview.sql
@02_column_stats_analysis.sql
# etc.
```

Most scripts prompt for a schema name (and optionally a table name pattern). Use `%` as a wildcard for table names.

## Script Architecture

### Shared Configuration
- `common_settings.sql` - Included by all scripts via `@@common_settings.sql`. Sets SQL*Plus formatting (LINESIZE 200, PAGESIZE 100), column formats, and NLS_DATE_FORMAT.

### Script Categories

**Analysis Scripts (01-06):**
- `01_table_stats_overview.sql` - Table-level stats summary with staleness flags
- `02_column_stats_analysis.sql` - Column stats, histograms, low/high value decoding
- `03_stats_preferences.sql` - DBMS_STATS preferences at global/schema/table levels
- `04_index_stats.sql` - Index stats with clustering factor analysis
- `05_partition_stats.sql` - Partition-level stats and incremental statistics status
- `06_extended_stats.sql` - Column groups, expressions, and SQL Plan Directives

**Monitoring Scripts (07-09):**
- `07_auto_stats_monitor.sql` - Auto task client status, maintenance windows, running operations
- `08_stats_operations.sql` - DBA_OPTSTAT_OPERATIONS history with failure analysis
- `09_stale_stats_report.sql` - Stale stats with DML activity from DBA_TAB_MODIFICATIONS

**Health Check (10):**
- `10_stats_health_check.sql` - Comprehensive health check with PL/SQL recommendations block

**History / Pending / System (11-14):**
- `11_stats_history.sql` - Stats history retention, SYSAUX usage, restore points (DBA_TAB_STATS_HISTORY)
- `12_pending_stats.sql` - Pending stats from PUBLISH=FALSE gathers (DBA_TAB_PENDING_STATS)
- `13_dictionary_system_stats.sql` - Dictionary/fixed-object stats freshness, system stats (SYS.AUX_STATS$)
- `14_realtime_hf_stats.sql` - Real-time stats and high-frequency auto task (19c+ only)

**Batch driver:**
- `run_all.sh` - Runs all scripts for one schema, feeding prompt answers via stdin, into a combined report file. Used by the CI smoke test (`.github/workflows/smoke-test.yml`) against a `gvenzl/oracle-free` container.

## Key Data Dictionary Views Used

- `DBA_TAB_STATISTICS` / `DBA_IND_STATISTICS` - Stats with staleness flags
- `DBA_TAB_COL_STATISTICS` - Column stats including histograms
- `DBA_TAB_MODIFICATIONS` - DML activity since last gather (inserts/updates/deletes/truncated)
- `DBA_OPTSTAT_OPERATIONS` - Statistics gathering history
- `DBA_TAB_STAT_PREFS` - Table-level preference overrides
- `DBA_STAT_EXTENSIONS` - Extended statistics (column groups, expressions)
- `DBA_SQL_PLAN_DIRECTIVES` / `DBA_SQL_PLAN_DIR_OBJECTS` - SPD recommendations
- `DBA_AUTOTASK_CLIENT` / `DBA_AUTOTASK_CLIENT_HISTORY` - Auto stats job status

## Conventions

- All scripts use the same issue flags: `NO STATS`, `STALE`, `OLD (>30d)`, `LOW SAMPLE`
- Column formats are standardized in `common_settings.sql`; per-query `COLUMN` commands must appear BEFORE the query they format (SQL*Plus applies them to subsequent statements only)
- Scripts output a legend/notes section at the end explaining flags and recommendations
- Raw `LOW_VALUE`/`HIGH_VALUE` are decoded via `DBMS_STATS.CONVERT_RAW_VALUE` in a `WITH FUNCTION` clause (12c+)
- Table-level reports consistently exclude temporary, secondary, nested, and external tables
- `DBA_OPTSTAT_OPERATIONS` and autotask history times are `TIMESTAMP WITH TIME ZONE` - compute durations via `CAST(... AS DATE)` arithmetic, never raw timestamp subtraction (yields INTERVAL, breaks ROUND/AVG)
- Each script ends with `UNDEFINE` of its substitution variables and restores `FEEDBACK`/`VERIFY`
