# Oracle Optimizer Statistics Analysis Toolkit

A collection of SQL*Plus scripts for analyzing and troubleshooting Oracle database optimizer statistics. These scripts help DBAs identify statistics issues, monitor automatic statistics gathering, and maintain optimal query performance.

## Requirements

- Oracle Database 12c or later (script `14` requires 19c or later)
- DBA privileges
- SQL*Plus client, 12c or later (script `02` uses a `WITH FUNCTION` clause)

## Quick Start

```sql
-- Connect to the database as a DBA user
sqlplus / as sysdba

-- Run the health check for a quick overview
@10_stats_health_check.sql

-- Or start with table statistics overview
@01_table_stats_overview.sql
```

## Scripts Overview

### Analysis Scripts

| Script | Description |
|--------|-------------|
| `01_table_stats_overview.sql` | Table-level statistics summary including row counts, sample sizes, staleness flags, and age of statistics |
| `02_column_stats_analysis.sql` | Column statistics with histogram types, distinct values, density, and decoded low/high values |
| `03_stats_preferences.sql` | DBMS_STATS preferences at global, schema, and table levels; shows locked statistics and incremental config |
| `04_index_stats.sql` | Index statistics with clustering factor analysis and quality assessment |
| `05_partition_stats.sql` | Partition-level statistics for partitioned tables, incremental stats status, and global vs partition consistency |
| `06_extended_stats.sql` | Extended statistics (column groups, expressions) and SQL Plan Directives suggesting missing column groups |

### Monitoring Scripts

| Script | Description |
|--------|-------------|
| `07_auto_stats_monitor.sql` | Automatic statistics gathering job status, maintenance windows, running operations, and resource consumption |
| `08_stats_operations.sql` | Statistics operations history from DBA_OPTSTAT_OPERATIONS with failure analysis and duration metrics |
| `09_stale_stats_report.sql` | Stale statistics identification with DML activity analysis (inserts, updates, deletes, truncates) |

### Health Check

| Script | Description |
|--------|-------------|
| `10_stats_health_check.sql` | Comprehensive health check covering all areas with actionable recommendations |

### History, Pending, and System Statistics

| Script | Description |
|--------|-------------|
| `11_stats_history.sql` | Statistics history retention, SYSAUX usage, restore points, and restore/purge commands |
| `12_pending_stats.sql` | Pending (unpublished) statistics from `PUBLISH=FALSE` gathers, with publish/delete commands |
| `13_dictionary_system_stats.sql` | Dictionary stats freshness, fixed object (X$) stats coverage, and system statistics from `SYS.AUX_STATS$` |
| `14_realtime_hf_stats.sql` | Real-time statistics and the high-frequency auto stats task (19c+) |

### Batch Mode

`run_all.sh` runs every script for one schema and writes a combined report file:

```bash
./run_all.sh "/ as sysdba" HR
./run_all.sh "system/oracle@//db-host:1521/pdb1" SALES % 14
```

Arguments: connect string, schema, optional table pattern (default `%`), and
optional days-back for history scripts (default `7`). Output goes to
`stats_report_<SCHEMA>_<timestamp>.txt`.

## Script Parameters

Most scripts prompt for input parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| Schema name | The schema to analyze | `HR`, `SALES` |
| Table name | Specific table or `%` for all tables | `EMPLOYEES`, `%` |
| Days back | Number of days for historical analysis | `7` (default) |

## Issue Flags

Scripts use consistent flags to highlight potential issues:

| Flag | Description |
|------|-------------|
| `NO STATS` | Object has no optimizer statistics |
| `STALE` | Statistics marked as stale by Oracle (>10% change by default) |
| `OLD (>30d)` | Statistics older than 30 days |
| `LOW SAMPLE` | Sample size less than 10% of rows |
| `HIGH CF` | Index clustering factor exceeds 10x table blocks (non-bitmap indexes) |
| `NEEDS HIST?` | Low NDV column used in WHERE-clause predicates (per `SYS.COL_USAGE$`) but without a histogram |

## Common DBMS_STATS Commands

The scripts provide context for these common remediation commands:

```sql
-- Gather statistics for stale tables only
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('SCHEMA_NAME', OPTIONS=>'GATHER STALE');

-- Gather statistics for tables without stats
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('SCHEMA_NAME', OPTIONS=>'GATHER EMPTY');

-- Gather all statistics in a schema
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('SCHEMA_NAME');

-- Gather statistics for a specific table
EXEC DBMS_STATS.GATHER_TABLE_STATS('SCHEMA_NAME', 'TABLE_NAME');

-- Enable incremental statistics for a partitioned table
EXEC DBMS_STATS.SET_TABLE_PREFS('SCHEMA_NAME', 'TABLE_NAME', 'INCREMENTAL', 'TRUE');

-- Create extended statistics for correlated columns
SELECT DBMS_STATS.CREATE_EXTENDED_STATS('SCHEMA_NAME', 'TABLE_NAME', '(COL1, COL2)') FROM DUAL;

-- Enable automatic extended statistics creation
EXEC DBMS_STATS.SET_GLOBAL_PREFS('AUTO_STAT_EXTENSIONS', 'ON');
```

## Recommended Workflow

1. **Initial Assessment**: Run `10_stats_health_check.sql` to get an overview of statistics health
2. **Identify Issues**: Use `09_stale_stats_report.sql` to find tables needing attention
3. **Deep Dive**: Run specific scripts (01-06) to investigate problem areas
4. **Monitor**: Use `07_auto_stats_monitor.sql` and `08_stats_operations.sql` to verify gathering jobs
5. **Recover**: Use `11_stats_history.sql` to restore statistics after a bad gather
6. **Foundations**: Periodically check `12`-`14` for pending stats, dictionary/fixed-object/system stats, and 19c+ auto stats features

## File Structure

```
ora_stats_scripts/
├── common_settings.sql              # Shared SQL*Plus formatting settings
├── 01_table_stats_overview.sql      # Table statistics summary
├── 02_column_stats_analysis.sql     # Column and histogram analysis
├── 03_stats_preferences.sql         # DBMS_STATS preferences
├── 04_index_stats.sql               # Index statistics
├── 05_partition_stats.sql           # Partition statistics
├── 06_extended_stats.sql            # Extended statistics
├── 07_auto_stats_monitor.sql        # Auto stats job monitoring
├── 08_stats_operations.sql          # Operations history
├── 09_stale_stats_report.sql        # Stale statistics report
├── 10_stats_health_check.sql        # Comprehensive health check
├── 11_stats_history.sql             # Stats history, retention, restore
├── 12_pending_stats.sql             # Pending (unpublished) statistics
├── 13_dictionary_system_stats.sql   # Dictionary, fixed object, system stats
├── 14_realtime_hf_stats.sql         # Real-time & high-frequency stats (19c+)
└── run_all.sh                       # Batch driver producing a combined report
```

## Notes on Behavior

- Scripts exclude temporary, secondary, nested, and external tables from
  table-level reports.
- `09_stale_stats_report.sql` runs `DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO`
  first so DML counts are current.
- Substitution variables are `UNDEFINE`d at the end of each script, so
  re-running a script always prompts again.
- A GitHub Actions smoke test runs every script against an Oracle Free
  container and fails on any `ORA-`/`SP2-` error.

## License

MIT License - see [LICENSE](LICENSE)
