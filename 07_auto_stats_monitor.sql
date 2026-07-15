-- ============================================================================
-- 07_auto_stats_monitor.sql
-- Oracle Optimizer Statistics Analysis Toolkit
-- Automatic statistics gathering job monitoring
-- ============================================================================
-- Usage: @07_auto_stats_monitor.sql
-- Parameters: None (system-wide view)
-- Requires: DBA privileges
-- ============================================================================

@@common_settings.sql

PROMPT
PROMPT ============================================================================
PROMPT  AUTOMATIC STATISTICS GATHERING MONITORING
PROMPT ============================================================================
PROMPT

COLUMN client_name        FORMAT A35        HEADING "Client Name"
COLUMN status             FORMAT A10        HEADING "Status"
COLUMN consumer_group     FORMAT A25        HEADING "Consumer Group"
COLUMN window_group       FORMAT A20        HEADING "Window Group"

PROMPT
PROMPT ============================================================================
PROMPT  AUTO TASK CLIENT STATUS
PROMPT ============================================================================

SELECT
    client_name,
    status,
    consumer_group,
    window_group
FROM
    dba_autotask_client
WHERE
    client_name LIKE '%stats%'
    OR client_name LIKE '%optimizer%'
ORDER BY
    client_name;

PROMPT
PROMPT ============================================================================
PROMPT  MAINTENANCE WINDOWS SCHEDULE
PROMPT ============================================================================

COLUMN window_name        FORMAT A20        HEADING "Window"
COLUMN repeat_interval    FORMAT A50        HEADING "Schedule"
COLUMN duration           FORMAT A20        HEADING "Duration"
COLUMN enabled            FORMAT A7         HEADING "Enabled"
COLUMN optimizer_stats    FORMAT A10        HEADING "Stats Job"

SELECT
    w.window_name,
    w.repeat_interval,
    w.duration,
    w.enabled,
    wc.optimizer_stats
FROM
    dba_scheduler_windows w
    LEFT JOIN dba_autotask_window_clients wc
        ON w.window_name = wc.window_name
WHERE
    w.window_name LIKE '%MONDAY%'
    OR w.window_name LIKE '%TUESDAY%'
    OR w.window_name LIKE '%WEDNESDAY%'
    OR w.window_name LIKE '%THURSDAY%'
    OR w.window_name LIKE '%FRIDAY%'
    OR w.window_name LIKE '%SATURDAY%'
    OR w.window_name LIKE '%SUNDAY%'
    OR w.window_name LIKE 'WEEKEND%'
    OR w.window_name LIKE 'WEEKNIGHT%'
ORDER BY
    DECODE(w.window_name,
        'MONDAY_WINDOW', 1,
        'TUESDAY_WINDOW', 2,
        'WEDNESDAY_WINDOW', 3,
        'THURSDAY_WINDOW', 4,
        'FRIDAY_WINDOW', 5,
        'SATURDAY_WINDOW', 6,
        'SUNDAY_WINDOW', 7,
        8);

PROMPT
PROMPT ============================================================================
PROMPT  CURRENT WINDOW STATUS
PROMPT ============================================================================

COLUMN next_start FORMAT A19 HEADING "Next Start"
COLUMN last_start FORMAT A19 HEADING "Last Start"
COLUMN active     FORMAT A6  HEADING "Active"

SELECT
    window_name,
    TO_CHAR(next_start_date, 'YYYY-MM-DD HH24:MI:SS') AS next_start,
    TO_CHAR(last_start_date, 'YYYY-MM-DD HH24:MI:SS') AS last_start,
    enabled,
    active
FROM
    dba_scheduler_windows
WHERE
    window_name LIKE '%MONDAY%'
    OR window_name LIKE '%TUESDAY%'
    OR window_name LIKE '%WEDNESDAY%'
    OR window_name LIKE '%THURSDAY%'
    OR window_name LIKE '%FRIDAY%'
    OR window_name LIKE '%SATURDAY%'
    OR window_name LIKE '%SUNDAY%'
ORDER BY
    next_start_date;

PROMPT
PROMPT ============================================================================
PROMPT  RECENT AUTO STATS TASK HISTORY (Last 7 Days)
PROMPT ============================================================================

COLUMN task_name          FORMAT A35        HEADING "Task Name"
COLUMN window_start       FORMAT A19        HEADING "Window Start"
COLUMN window_end         FORMAT A19        HEADING "Window End"
COLUMN job_status         FORMAT A12        HEADING "Status"
COLUMN job_duration_mins  FORMAT 9999.9     HEADING "Mins"

SELECT
    h.client_name AS task_name,
    TO_CHAR(h.window_start_time, 'YYYY-MM-DD HH24:MI:SS') AS window_start,
    TO_CHAR(h.window_end_time, 'YYYY-MM-DD HH24:MI:SS') AS window_end,
    h.job_status,
    ROUND((CAST(h.window_end_time AS DATE) - CAST(h.window_start_time AS DATE)) * 24 * 60, 1) AS job_duration_mins
FROM
    dba_autotask_client_history h
WHERE
    h.client_name LIKE '%stats%'
    AND h.window_start_time > SYSDATE - 7
ORDER BY
    h.window_start_time DESC;

PROMPT
PROMPT ============================================================================
PROMPT  RUNNING STATISTICS OPERATIONS
PROMPT ============================================================================

COLUMN sid           FORMAT 99999  HEADING "SID"
COLUMN serial#       FORMAT 99999  HEADING "Serial#"
COLUMN username      FORMAT A20    HEADING "Username"
COLUMN module        FORMAT A25    HEADING "Module"
COLUMN action        FORMAT A25    HEADING "Action"
COLUMN started       FORMAT A19    HEADING "Started"
COLUMN running_mins  FORMAT 9999.9 HEADING "Running Mins"

SELECT
    sid,
    serial#,
    username,
    module,
    action,
    TO_CHAR(sql_exec_start, 'YYYY-MM-DD HH24:MI:SS') AS started,
    ROUND((SYSDATE - sql_exec_start) * 24 * 60, 1) AS running_mins
FROM
    v$session
WHERE
    (module LIKE '%DBMS_STATS%' OR action LIKE '%GATHER%' OR module LIKE 'DBMS_SCHEDULER')
    AND status = 'ACTIVE'
ORDER BY
    sql_exec_start;

PROMPT
PROMPT ============================================================================
PROMPT  AUTO OPTIMIZER STATS ADVISOR FINDINGS (if available)
PROMPT ============================================================================

COLUMN task_name       FORMAT A30 HEADING "Task Name"
COLUMN execution_name  FORMAT A25 HEADING "Execution"
COLUMN exec_start      FORMAT A16 HEADING "Execution Start"
COLUMN findings_count  FORMAT 999 HEADING "Findings"

SELECT
    task_name,
    execution_name,
    TO_CHAR(execution_start, 'YYYY-MM-DD HH24:MI') AS exec_start,
    status,
    findings_count
FROM
    (SELECT
        t.task_name,
        e.execution_name,
        e.execution_start,
        e.status,
        (SELECT COUNT(*) FROM dba_advisor_findings f
         WHERE f.task_id = t.task_id AND f.execution_name = e.execution_name) AS findings_count
    FROM
        dba_advisor_tasks t
        JOIN dba_advisor_executions e ON t.task_id = e.task_id
    WHERE
        t.advisor_name = 'Statistics Advisor'
        AND e.execution_start > SYSDATE - 30
    ORDER BY
        e.execution_start DESC)
WHERE ROWNUM <= 10;

PROMPT
PROMPT ============================================================================
PROMPT  AUTO STATS SCHEDULER JOB RUNS (Last 7 Days)
PROMPT ============================================================================

COLUMN log_time      FORMAT A19    HEADING "Log Time"
COLUMN job_name      FORMAT A30    HEADING "Job Name"
COLUMN job_status    FORMAT A12    HEADING "Status"
COLUMN run_mins      FORMAT 9999.9 HEADING "Run Mins"
COLUMN cpu_mins      FORMAT 9999.9 HEADING "CPU Mins"

SELECT
    TO_CHAR(CAST(d.log_date AS DATE), 'YYYY-MM-DD HH24:MI:SS') AS log_time,
    d.job_name,
    d.status AS job_status,
    ROUND(EXTRACT(DAY FROM d.run_duration) * 1440
        + EXTRACT(HOUR FROM d.run_duration) * 60
        + EXTRACT(MINUTE FROM d.run_duration)
        + EXTRACT(SECOND FROM d.run_duration) / 60, 1) AS run_mins,
    ROUND(EXTRACT(DAY FROM d.cpu_used) * 1440
        + EXTRACT(HOUR FROM d.cpu_used) * 60
        + EXTRACT(MINUTE FROM d.cpu_used)
        + EXTRACT(SECOND FROM d.cpu_used) / 60, 1) AS cpu_mins
FROM
    dba_scheduler_job_run_details d
WHERE
    d.job_name LIKE 'ORA$AT_OS_OPT%'
    AND d.log_date > SYSTIMESTAMP - INTERVAL '7' DAY
ORDER BY
    d.log_date DESC;

PROMPT
PROMPT Notes:
PROMPT   - Auto stats runs during maintenance windows (typically nights/weekends)
PROMPT   - Job status SUCCEEDED means window completed normally
PROMPT   - Job status STOPPED means window was manually stopped or ran out of time
PROMPT   - Consider extending window duration if jobs frequently time out
PROMPT   - Use DBMS_AUTO_TASK_ADMIN to enable/disable auto stats
PROMPT

SET FEEDBACK ON
SET VERIFY ON
