-- ============================================================
-- Bracket Purchase Retention by monthly purchase cohort
-- ============================================================

-- Bracket purchase retention: share of eligible users who made at least
-- one repeat purchase during a time interval after their first purchase.
-- Brackets: Day 1–7, Day 8–14, Day 15–30, Day 31+.
--
-- Data: events_clean, purchase = checkout_complete, cohort = month of
-- the first purchase. A bracket is included for a user only if it is
-- fully observed: first purchase date + last day of the bracket < data
-- end. For Day 31+ the user must be observable for at least 31 days.
--
-- Output: one row per cohort month and bracket with the cohort size,
-- eligible users (denominator), users with a repeat purchase in the
-- bracket (numerator) and retention in %.


-- export: purchase_bracket_retention_monthly.csv
WITH data_end AS (

    -- Start of the last, partly covered day (exclusive end of the data)

    SELECT
        CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean

),

purchase_days AS (

    -- One row per user per day with at least one purchase,
    -- only fully observed days

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

retention_brackets AS (

    -- Bracket boundaries in days since the first purchase

    SELECT *
    FROM (VALUES
        (1, 'Day 1-7',   1,  7),
        (2, 'Day 8-14',  8,  14),
        (3, 'Day 15-30', 15, 30),
        (4, 'Day 31+',   31, NULL)
    ) AS b(bracket_order, bracket, first_day, last_day)

),

eligible_users AS (

    -- Users for whom the bracket is fully observed

    SELECT
        u.user_id,
        u.first_purchase_date,
        u.cohort_month,
        b.bracket_order,
        b.bracket,
        b.first_day,
        b.last_day
    FROM user_first_purchase u
    CROSS JOIN retention_brackets b
    WHERE u.first_purchase_date + COALESCE(b.last_day, b.first_day)
          < (SELECT end_date FROM data_end)

),

retention_table AS (

    -- Eligible users and users with at least one repeat purchase
    -- inside the bracket (COUNT DISTINCT: several purchase days in the
    -- same bracket count once)

    SELECT
        e.cohort_month,
        e.bracket_order,
        e.bracket,
        COUNT(DISTINCT e.user_id) AS eligible_users,
        COUNT(DISTINCT p.user_id) AS returned_users
    FROM eligible_users e
    LEFT JOIN purchase_days p
        ON p.user_id = e.user_id
        AND p.purchase_date - e.first_purchase_date >= e.first_day
        AND (e.last_day IS NULL OR p.purchase_date - e.first_purchase_date <= e.last_day)
    GROUP BY
        e.cohort_month,
        e.bracket_order,
        e.bracket

)

SELECT
    t.cohort_month,

    (
        SELECT COUNT(*)
        FROM user_first_purchase u
        WHERE u.cohort_month = t.cohort_month
    ) AS cohort_users,

    t.bracket_order,
    t.bracket,
    t.eligible_users,
    t.returned_users,
    ROUND(t.returned_users * 100.0 / t.eligible_users, 2) AS retention_pct

FROM retention_table t
ORDER BY
    t.cohort_month,
    t.bracket_order;
