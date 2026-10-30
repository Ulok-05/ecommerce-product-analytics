-- ============================================================
-- Session check
-- Do sessions look like real visits?
-- ============================================================

-- A path analysis inside sessions (what users do before and after a
-- step, as in an earlier version of this analysis)
-- needs sessions that look like visits: short, with session_end as the
-- last event. These checks test whether sessions in this dataset look so.
--
-- Data: events_clean, only fully observed days. session_end is included
-- here, as it is part of the check.


-- Check 1. Session length and number of events

-- export: session_summary.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

sessions AS (
    SELECT
        session_id,
        COUNT(*) AS events,
        date_diff('minute', MIN(event_time), MAX(event_time)) AS duration_minutes
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
    GROUP BY session_id
)

SELECT
    COUNT(*) AS sessions,
    MIN(events) AS min_events,
    MEDIAN(events) AS median_events,
    ROUND(QUANTILE_CONT(duration_minutes, 0.25) / 1440.0, 1) AS p25_duration_days,
    ROUND(MEDIAN(duration_minutes) / 1440.0, 1) AS median_duration_days,
    ROUND(QUANTILE_CONT(duration_minutes, 0.75) / 1440.0, 1) AS p75_duration_days,
    ROUND(100.0 * AVG(CASE WHEN duration_minutes > 1440 THEN 1 ELSE 0 END), 1) AS pct_longer_than_1_day
FROM sessions;



-- Check 2. Position of session_end in the session
-- Events are ordered by event_time; event_name only breaks ties. No two
-- events of the same session share a timestamp in this data, so the
-- tie-breaker does not affect the result. In data with ties, the order
-- of tied events would not be a confirmed sequence of actions.

-- export: session_end_position.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

ranked_events AS (
    SELECT
        session_id,
        event_name,
        ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY event_time, event_name) AS position,
        COUNT(*) OVER (PARTITION BY session_id) AS session_events
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
)

SELECT
    CASE
        WHEN position = session_events THEN 'Last event'
        WHEN position = 1 THEN 'First event'
        ELSE 'In the middle'
    END AS session_end_position,
    COUNT(*) AS sessions,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM ranked_events
WHERE event_name = 'session_end'
GROUP BY session_end_position
ORDER BY sessions DESC;



-- Check 3. duration_ms of session_end events
-- Events have a duration_ms field. For session_end it may be meant as the
-- session duration, but the data dictionary does not describe it, and it
-- is also filled for most other event types, so its meaning is not
-- certain. Here it is compared with the session length from event
-- timestamps (Check 1).

-- export: session_duration_ms.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

sessions AS (
    SELECT
        session_id,
        MAX(duration_ms) FILTER (WHERE event_name = 'session_end') AS session_end_duration_ms,
        date_diff('minute', MIN(event_time), MAX(event_time)) AS timestamp_duration_minutes
    FROM observed
    GROUP BY session_id
)

SELECT
    COUNT(*) AS sessions,
    COUNT(session_end_duration_ms) AS sessions_with_duration_ms,
    ROUND(MIN(session_end_duration_ms) / 60000.0, 1) AS min_duration_ms_minutes,
    ROUND(MEDIAN(session_end_duration_ms) / 60000.0, 1) AS median_duration_ms_minutes,
    ROUND(MAX(session_end_duration_ms) / 60000.0, 1) AS max_duration_ms_minutes,
    ROUND(MEDIAN(timestamp_duration_minutes) / 1440.0, 1) AS median_timestamp_duration_days,
    (SELECT COUNT(DISTINCT event_name) FROM observed WHERE duration_ms IS NOT NULL) AS event_types_with_duration_ms
FROM sessions;



-- Distribution of duration_ms of session_end in 2-minute bins

-- export: session_duration_ms_distribution.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

session_end_durations AS (
    SELECT duration_ms / 60000.0 AS duration_minutes
    FROM events_clean
    WHERE event_name = 'session_end'
      AND event_time < (SELECT end_date FROM data_end)
),

bins AS (
    SELECT bin_start
    FROM range(0, 30, 2) AS r(bin_start)
)

SELECT
    b.bin_start AS bin_start_minutes,
    b.bin_start + 2 AS bin_end_minutes,
    COUNT(d.duration_minutes) AS sessions
FROM bins b
LEFT JOIN session_end_durations d
    ON d.duration_minutes >= b.bin_start
   AND (d.duration_minutes < b.bin_start + 2
        OR (b.bin_start = 28 AND d.duration_minutes <= 30))
GROUP BY b.bin_start
ORDER BY b.bin_start;
