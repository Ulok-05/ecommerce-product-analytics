-- ============================================================
-- Unbounded Purchase Retention by monthly purchase cohort
-- ============================================================

-- D30 Unbounded Purchase Retention: share of eligible users who made at
-- least one repeat purchase on Day 30 or later after their first
-- purchase.
--
-- Data: events_clean, purchase = checkout_complete, cohort = month of
-- the first purchase. A user is eligible only if Day 30 is fully
-- observed: first purchase date + 30 < data end.


-- export: purchase_unbounded_retention_monthly.csv
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

eligible_users AS (

    -- Users whose Day 30 is fully observed

    SELECT
        user_id,
        first_purchase_date,
        cohort_month
    FROM user_first_purchase
    WHERE first_purchase_date + 30 < (SELECT end_date FROM data_end)

),

unbounded_returns AS (

    -- Eligible users with at least one purchase on Day 30 or later

    SELECT DISTINCT
        e.user_id
    FROM eligible_users e
    INNER JOIN purchase_days p
        ON p.user_id = e.user_id
    WHERE p.purchase_date - e.first_purchase_date >= 30

)

SELECT
    e.cohort_month,
    COUNT(*) AS eligible_users,
    COUNT(r.user_id) AS returned_users,
    ROUND(COUNT(r.user_id) * 100.0 / COUNT(*), 2) AS d30_unbounded_purchase_retention
FROM eligible_users e
LEFT JOIN unbounded_returns r
    ON e.user_id = r.user_id
GROUP BY e.cohort_month
ORDER BY e.cohort_month;
