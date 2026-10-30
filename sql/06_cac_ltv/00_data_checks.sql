-- ============================================================
-- Data checks for acquisition and monetization
-- ============================================================

-- 1. Do conversions agree with subscriptions? If they did,
--    paid_plan_purchase would come after trial_signup, close to the
--    subscription start, and only for users with a paid plan.
-- 2. Which period do subscription end dates cover? If end dates were
--    recorded for the whole data period, subscriptions that started in
--    2023 could also end within their first 90 days.


-- Check 1. conversions vs subscriptions

-- export: conversions_consistency_check.csv
WITH trial AS (
    SELECT user_id, MIN(conversion_time) AS trial_time
    FROM conversions
    WHERE conversion_type = 'trial_signup'
    GROUP BY user_id
),

paid AS (
    SELECT user_id, MIN(conversion_time) AS paid_time
    FROM conversions
    WHERE conversion_type = 'paid_plan_purchase'
    GROUP BY user_id
)

SELECT
    (SELECT COUNT(*) FROM paid) AS users_with_paid_plan_purchase,
    (SELECT COUNT(*) FROM paid p INNER JOIN trial t ON t.user_id = p.user_id
      WHERE p.paid_time < t.trial_time) AS paid_before_trial,
    (SELECT MEDIAN(date_diff('day', p.paid_time, t.trial_time)) FROM paid p INNER JOIN trial t ON t.user_id = p.user_id
      WHERE p.paid_time < t.trial_time) AS median_days_paid_before_trial,
    (SELECT COUNT(*) FROM paid p INNER JOIN subscriptions s ON s.user_id = p.user_id) AS paid_users_with_subscription,
    (SELECT COUNT(*) FROM paid p INNER JOIN subscriptions s ON s.user_id = p.user_id
      WHERE abs(date_diff('day', CAST(p.paid_time AS DATE), s.start_date)) <= 1) AS paid_within_1_day_of_subscription_start,
    (SELECT COUNT(*) FROM paid p INNER JOIN subscriptions s ON s.user_id = p.user_id
      WHERE s.plan = 'Free') AS free_plan_users_with_paid_plan_purchase,
    (SELECT COUNT(*) FROM subscriptions WHERE plan = 'Enterprise') AS enterprise_subscribers,
    (SELECT COUNT(*) FROM paid p INNER JOIN subscriptions s ON s.user_id = p.user_id
      WHERE s.plan = 'Enterprise') AS enterprise_with_paid_plan_purchase;



-- Check 2. Period covered by subscription end dates

-- export: subscription_end_date_range.csv
SELECT
    COUNT(*) AS subscriptions,
    COUNT(end_date) AS ended_subscriptions,
    MIN(start_date) AS first_start_date,
    MIN(end_date) AS first_end_date,
    MAX(end_date) AS last_end_date
FROM subscriptions;



-- Check 3. Subscriptions ended within 90 days, by start quarter
-- Only subscriptions whose first 90 days are observed before the
-- snapshot date (MAX(start_date), as in 02_revenue.sql) are counted.

-- export: subscription_ended_90_days_by_quarter.csv
WITH snapshot AS (
    SELECT MAX(start_date) AS snapshot_date
    FROM subscriptions
)

SELECT
    date_trunc('quarter', start_date) AS start_quarter,
    COUNT(*) AS subscriptions,
    COUNT(*) FILTER (WHERE start_date + 90 <= (SELECT snapshot_date FROM snapshot)) AS observed_90_days,
    COUNT(*) FILTER (WHERE start_date + 90 <= (SELECT snapshot_date FROM snapshot)
                       AND end_date - start_date <= 90) AS ended_within_90_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE start_date + 90 <= (SELECT snapshot_date FROM snapshot)
                                     AND end_date - start_date <= 90)
          / NULLIF(COUNT(*) FILTER (WHERE start_date + 90 <= (SELECT snapshot_date FROM snapshot)), 0), 1)
        AS ended_within_90_days_pct
FROM subscriptions
GROUP BY start_quarter
ORDER BY start_quarter;
