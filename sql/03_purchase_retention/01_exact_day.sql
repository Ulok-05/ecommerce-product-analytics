-- ============================================================
-- Purchase Retention
-- Exact-Day Purchase Retention by monthly purchase cohort
-- ============================================================

-- Purchase: a checkout_complete event. Several purchases on the same
-- calendar day count as one purchase day.
-- Cohort: the month of a user's first purchase.
-- Day-N purchase retention: share of eligible users who made a repeat
-- purchase exactly N days after their first purchase.
--
-- Data: events_clean, for consistency with the other analyses. The
-- anomalous June–August 2023 sessions contain no checkout_complete
-- events, so purchases are the same in events and events_clean
-- (checked below).
--
-- Observation window: the last day in the data is only partly covered,
-- so the data end is the start of that day: CAST(MAX(event_time) AS DATE).
-- Day N of a user is observed only if first purchase date + N < data end.
--
-- Output: one row per cohort month and day N with the cohort size,
-- the number of eligible users (denominator), the number of users with
-- a repeat purchase on Day N (numerator) and retention in %.


-- Check: the anomalous sessions do not affect purchases

-- export: purchase_anomaly_check.csv
SELECT
    (SELECT COUNT(*) FROM events WHERE event_name = 'checkout_complete') AS purchases_all_events,
    (SELECT COUNT(*) FROM events_clean WHERE event_name = 'checkout_complete') AS purchases_events_clean,
    (SELECT COUNT(DISTINCT user_id) FROM events_clean WHERE event_name = 'checkout_complete') AS purchasers,
    (SELECT COUNT(*) FROM users) AS users;



-- Exact-Day Purchase Retention

-- export: purchase_exact_day_retention_monthly.csv
WITH data_end AS (

    -- Start of the last, partly covered day (exclusive end of the data)

    SELECT
        CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean

),

purchase_days AS (

    -- One row per user per day with at least one purchase

    SELECT DISTINCT
        user_id,
        CAST(event_time AS DATE) AS purchase_date
    FROM events_clean
    WHERE event_name = 'checkout_complete'
      AND CAST(event_time AS DATE) < (SELECT end_date FROM data_end)

),

user_first_purchase AS (

    -- First purchase date and purchase cohort month of each user

    SELECT
        user_id,
        MIN(purchase_date) AS first_purchase_date,
        date_trunc('month', MIN(purchase_date)) AS cohort_month
    FROM purchase_days
    GROUP BY user_id

),

retention_days AS (

    -- Retention days to analyze

    SELECT *
    FROM (VALUES (1), (2), (3), (7), (14), (30)) AS r(day_n)

),

eligible_users AS (

    -- Users whose day N is fully observed before the data end

    SELECT
        u.user_id,
        u.first_purchase_date,
        u.cohort_month,
        r.day_n
    FROM user_first_purchase u
    CROSS JOIN retention_days r
    WHERE u.first_purchase_date + r.day_n < (SELECT end_date FROM data_end)

),

retention_table AS (

    -- Eligible users and users with a repeat purchase exactly on day N

    SELECT
        e.cohort_month,
        e.day_n,
        COUNT(*) AS eligible_users,
        COUNT(p.user_id) AS returned_users
    FROM eligible_users e
    LEFT JOIN purchase_days p
        ON p.user_id = e.user_id
        AND p.purchase_date = e.first_purchase_date + e.day_n
    GROUP BY
        e.cohort_month,
        e.day_n

)

SELECT
    t.cohort_month,

    (
        SELECT COUNT(*)
        FROM user_first_purchase u
        WHERE u.cohort_month = t.cohort_month
    ) AS cohort_users,

    t.day_n,
    t.eligible_users,
    t.returned_users,
    ROUND(t.returned_users * 100.0 / t.eligible_users, 2) AS retention_pct

FROM retention_table t
ORDER BY
    t.cohort_month,
    t.day_n;
