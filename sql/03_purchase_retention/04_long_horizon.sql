-- ============================================================
-- Purchase Retention
-- Repeat purchases beyond Day 30
-- ============================================================

-- 01_exact_day.sql covers Days 1–30, and the brackets in 02_bracket.sql
-- end with the open-ended Day 31+. These queries extend the horizon for
-- all purchasers together (not by monthly cohort):
--   1. Exact-Day Purchase Retention on Days 1–100;
--   2. closed, non-overlapping 30-day intervals up to Day 120;
--   3. how much observed activity time a user has left after the first
--      purchase.
-- Purchase rules as in 01_exact_day.sql. A user is eligible for a day or
-- an interval only if it is fully observed (first purchase date + N <
-- data end). Because eligible users differ between days and intervals,
-- the values are also shown for a fixed group: users whose whole 120-day
-- horizon after the first purchase is observed.
--
-- Data: events_clean, only fully observed days.


-- Step 1. Exact-Day Purchase Retention on Days 1–100

-- export: purchase_retention_long_horizon.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

purchase_days AS (
    -- One row per user per purchase day, only fully observed days
    SELECT DISTINCT
        user_id,
        CAST(event_time AS DATE) AS purchase_date
    FROM events_clean
    WHERE event_name = 'checkout_complete'
      AND event_time < (SELECT end_date FROM data_end)
),

first_purchase AS (
    SELECT
        user_id,
        MIN(purchase_date) AS first_date,
        MIN(purchase_date) + 120 < (SELECT end_date FROM data_end) AS full_horizon
    FROM purchase_days
    GROUP BY user_id
),

retention_days AS (
    SELECT *
    FROM (VALUES (1), (7), (14), (30), (45), (60), (70), (80), (90), (100)) AS r(day_n)
),

user_days AS (
    SELECT
        r.day_n,
        f.full_horizon,
        EXISTS (
            SELECT 1 FROM purchase_days p
            WHERE p.user_id = f.user_id
              AND p.purchase_date = f.first_date + r.day_n
        ) AS purchased
    FROM first_purchase f
    CROSS JOIN retention_days r
    WHERE f.first_date + r.day_n < (SELECT end_date FROM data_end)
)

SELECT
    day_n,
    COUNT(*) AS eligible_users,
    COUNT(*) FILTER (WHERE purchased) AS returned_users,
    ROUND(100.0 * COUNT(*) FILTER (WHERE purchased) / COUNT(*), 2) AS retention_pct,
    COUNT(*) FILTER (WHERE full_horizon) AS full_horizon_users,
    ROUND(100.0 * COUNT(*) FILTER (WHERE full_horizon AND purchased)
          / COUNT(*) FILTER (WHERE full_horizon), 2) AS full_horizon_retention_pct
FROM user_days
GROUP BY day_n
ORDER BY day_n;



-- Step 2. Closed 30-day intervals: at least one repeat purchase

-- export: purchase_retention_intervals.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

purchase_days AS (
    SELECT DISTINCT
        user_id,
        CAST(event_time AS DATE) AS purchase_date
    FROM events_clean
    WHERE event_name = 'checkout_complete'
      AND event_time < (SELECT end_date FROM data_end)
),

first_purchase AS (
    SELECT
        user_id,
        MIN(purchase_date) AS first_date,
        MIN(purchase_date) + 120 < (SELECT end_date FROM data_end) AS full_horizon
    FROM purchase_days
    GROUP BY user_id
),

intervals AS (
    SELECT *
    FROM (VALUES
        (1, 'Day 1-30', 1, 30),
        (2, 'Day 31-60', 31, 60),
        (3, 'Day 61-90', 61, 90),
        (4, 'Day 91-120', 91, 120)
    ) AS i(interval_order, interval_name, first_day, last_day)
),

user_intervals AS (
    -- A user is eligible for an interval only if its last day is observed
    SELECT
        i.interval_order,
        i.interval_name,
        f.full_horizon,
        EXISTS (
            SELECT 1 FROM purchase_days p
            WHERE p.user_id = f.user_id
              AND p.purchase_date - f.first_date BETWEEN i.first_day AND i.last_day
        ) AS purchased
    FROM first_purchase f
    CROSS JOIN intervals i
    WHERE f.first_date + i.last_day < (SELECT end_date FROM data_end)
)

SELECT
    interval_name,
    COUNT(*) AS eligible_users,
    COUNT(*) FILTER (WHERE purchased) AS returned_users,
    ROUND(100.0 * COUNT(*) FILTER (WHERE purchased) / COUNT(*), 2) AS retention_pct,
    COUNT(*) FILTER (WHERE full_horizon) AS full_horizon_users,
    ROUND(100.0 * COUNT(*) FILTER (WHERE full_horizon AND purchased)
          / COUNT(*) FILTER (WHERE full_horizon), 2) AS full_horizon_retention_pct
FROM user_intervals
GROUP BY
    interval_order,
    interval_name
ORDER BY interval_order;



-- Step 3. Observed activity left after the first purchase
-- Days from the first purchase to the user's last observed event (any
-- event type), for users with a fully observed 120-day horizon.

-- export: purchase_activity_after_first_purchase.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

first_purchase AS (
    SELECT
        user_id,
        MIN(CAST(event_time AS DATE)) AS first_date
    FROM events_clean
    WHERE event_name = 'checkout_complete'
      AND event_time < (SELECT end_date FROM data_end)
    GROUP BY user_id
    HAVING MIN(CAST(event_time AS DATE)) + 120 < (SELECT end_date FROM data_end)
),

activity_left AS (
    SELECT
        f.user_id,
        MAX(CAST(e.event_time AS DATE)) - f.first_date AS days_left
    FROM first_purchase f
    INNER JOIN events_clean e
        ON e.user_id = f.user_id
       AND e.event_time < (SELECT end_date FROM data_end)
    GROUP BY
        f.user_id,
        f.first_date
)

SELECT
    COUNT(*) AS full_horizon_users,
    MIN(days_left) AS min_days_left,
    QUANTILE_DISC(days_left, 0.25) AS p25_days_left,
    MEDIAN(days_left) AS median_days_left,
    QUANTILE_DISC(days_left, 0.75) AS p75_days_left,
    MAX(days_left) AS max_days_left,
    ROUND(100.0 * COUNT(*) FILTER (WHERE days_left < 31) / COUNT(*), 1) AS pct_less_than_31_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE days_left < 61) / COUNT(*), 1) AS pct_less_than_61_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE days_left < 91) / COUNT(*), 1) AS pct_less_than_91_days
FROM activity_left;
