-- ==========================================================
-- Unbounded Retention by monthly cohort
-- ==========================================================

-- D30 Unbounded Retention: share of eligible users who returned at
-- least once on Day 30 or later after their first event.
--
-- Data: events_clean. Cohort: the month of a user's first event.
-- A user is eligible only if Day 30 is fully observed:
-- first_date + 30 < data end.


-- export: unbounded_retention_monthly.csv
WITH data_end AS (

    -- Start of the last, partly covered day (exclusive end of the data)

    SELECT
        CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean

),

user_first_event AS (

    -- First activity date and cohort month of each user

    SELECT
        user_id,
        MIN(CAST(event_time AS DATE)) AS first_date,
        date_trunc('month', MIN(event_time)) AS cohort_month
    FROM events_clean
    GROUP BY user_id

),

eligible_users AS (

    -- Users whose Day 30 is fully observed

    SELECT
        user_id,
        first_date,
        cohort_month
    FROM user_first_event
    WHERE first_date + 30 < (SELECT end_date FROM data_end)

),

unbounded_returns AS (

    -- Eligible users with at least one event on Day 30 or later
    -- (only fully observed days)

    SELECT DISTINCT
        u.user_id
    FROM eligible_users u
    INNER JOIN events_clean e
        ON u.user_id = e.user_id
    WHERE CAST(e.event_time AS DATE) - u.first_date >= 30
      AND CAST(e.event_time AS DATE) < (SELECT end_date FROM data_end)

)

SELECT
    u.cohort_month,
    COUNT(*) AS eligible_users,
    COUNT(r.user_id) AS returned_users,
    ROUND(COUNT(r.user_id) * 100.0 / COUNT(*), 2) AS d30_unbounded_retention,
    ROUND(100.0 - COUNT(r.user_id) * 100.0 / COUNT(*), 2) AS d30_churn
FROM eligible_users u
LEFT JOIN unbounded_returns r
    ON u.user_id = r.user_id
GROUP BY u.cohort_month
ORDER BY u.cohort_month;



-- ==========================================================
-- Diagnostic Check
-- How many users have any activity 30+ days after their first event?
-- ==========================================================

WITH data_end AS (

    -- Same observation window as the main calculation

    SELECT
        CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean

),

user_first_event AS (

    SELECT
        user_id,
        MIN(CAST(event_time AS DATE)) AS first_date
    FROM events_clean
    GROUP BY user_id

),

user_30_day_return AS (

    SELECT DISTINCT
        u.user_id
    FROM user_first_event u
    INNER JOIN events_clean e
        ON u.user_id = e.user_id
    WHERE CAST(e.event_time AS DATE) - u.first_date >= 30
      AND CAST(e.event_time AS DATE) < (SELECT end_date FROM data_end)

)

SELECT
    COUNT(*) AS users_with_30_day_return,
    (SELECT COUNT(*) FROM user_first_event) AS total_users,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM user_first_event),
        2
    ) AS pct_users_with_30_day_return
FROM user_30_day_return;
