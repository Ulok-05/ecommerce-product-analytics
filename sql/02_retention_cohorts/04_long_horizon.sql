-- ============================================================
-- Retention & Cohort Analysis
-- Retention beyond Day 30
-- ============================================================

-- Exact-Day Retention in 01_exact_day.sql covers Days 1–30. This query
-- extends the horizon to Day 120 for all users together (not by monthly
-- cohort), to check whether retention stays flat after Day 30.
--
-- For each Day N:
--   - Exact-Day Retention: share of eligible users active exactly on Day N;
--   - Unbounded Retention: share of eligible users with at least one
--     event on Day N or later (within the observed data).
-- Eligible users: Day N is fully observed (first_date + N < data end),
-- as in 01_exact_day.sql. The number of eligible users is shown for every
-- day, so that 0% (no events) is not confused with "not observable".
--
-- Because the eligible users differ slightly from day to day, the same
-- values are also calculated for a fixed group: users whose whole
-- 120-day horizon is observed (first_date + 120 < data end).
--
-- Data: events_clean, only fully observed days.


-- export: retention_long_horizon.csv
WITH data_end AS (

    -- Start of the last, partly covered day (exclusive end of the data)

    SELECT
        CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean

),

user_first_event AS (

    -- First activity date of each user

    SELECT
        user_id,
        MIN(CAST(event_time AS DATE)) AS first_date
    FROM events_clean
    GROUP BY user_id

),

user_activity AS (

    -- One row per user per active day, only fully observed days

    SELECT DISTINCT
        user_id,
        CAST(event_time AS DATE) AS activity_date
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)

),

user_last_day AS (

    -- Last observed active day of each user, in days since the first event

    SELECT
        u.user_id,
        u.first_date,
        MAX(a.activity_date - u.first_date) AS last_day_n,
        u.first_date + 120 < (SELECT end_date FROM data_end) AS full_horizon
    FROM user_first_event u
    INNER JOIN user_activity a
        ON a.user_id = u.user_id
    GROUP BY
        u.user_id,
        u.first_date

),

retention_days AS (

    SELECT *
    FROM (VALUES
        (1), (7), (14), (30), (45), (60), (70), (80), (90), (100), (110), (120)
    ) AS r(day_n)

),

user_days AS (

    -- Eligible users for each Day N, with exact-day and unbounded flags

    SELECT
        r.day_n,
        u.user_id,
        u.full_horizon,
        EXISTS (
            SELECT 1 FROM user_activity a
            WHERE a.user_id = u.user_id
              AND a.activity_date = u.first_date + r.day_n
        ) AS active_on_day,
        u.last_day_n >= r.day_n AS active_on_or_after_day
    FROM user_last_day u
    CROSS JOIN retention_days r
    WHERE u.first_date + r.day_n < (SELECT end_date FROM data_end)

)

SELECT
    day_n,
    COUNT(*) AS eligible_users,
    COUNT(*) FILTER (WHERE active_on_day) AS returned_users,
    ROUND(100.0 * COUNT(*) FILTER (WHERE active_on_day) / COUNT(*), 2) AS exact_day_retention_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE active_on_or_after_day) / COUNT(*), 2) AS unbounded_retention_pct,
    COUNT(*) FILTER (WHERE full_horizon) AS full_horizon_users,
    ROUND(100.0 * COUNT(*) FILTER (WHERE full_horizon AND active_on_day)
          / COUNT(*) FILTER (WHERE full_horizon), 2) AS full_horizon_exact_day_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE full_horizon AND active_on_or_after_day)
          / COUNT(*) FILTER (WHERE full_horizon), 2) AS full_horizon_unbounded_pct
FROM user_days
GROUP BY day_n
ORDER BY day_n;



-- Last observed active day of users with a fully observed 120-day horizon

-- export: retention_last_active_day.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

user_first_event AS (
    SELECT user_id, MIN(CAST(event_time AS DATE)) AS first_date
    FROM events_clean
    GROUP BY user_id
),

user_last_day AS (
    SELECT
        u.user_id,
        MAX(CAST(e.event_time AS DATE) - u.first_date) AS last_day_n
    FROM user_first_event u
    INNER JOIN events_clean e
        ON e.user_id = u.user_id
       AND e.event_time < (SELECT end_date FROM data_end)
    WHERE u.first_date + 120 < (SELECT end_date FROM data_end)
    GROUP BY u.user_id
)

SELECT
    COUNT(*) AS full_horizon_users,
    MIN(last_day_n) AS min_last_day,
    QUANTILE_DISC(last_day_n, 0.25) AS p25_last_day,
    MEDIAN(last_day_n) AS median_last_day,
    QUANTILE_DISC(last_day_n, 0.75) AS p75_last_day,
    MAX(last_day_n) AS max_last_day
FROM user_last_day;
