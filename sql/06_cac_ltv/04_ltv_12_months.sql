-- ============================================================
-- 12-month LTV and LTV/CAC by channel
-- ============================================================

-- LTV to date (03_ltv_cac.sql) depends on how long users have been
-- observed: users who signed up recently have had little time to pay.
-- Here revenue is counted only in the first 12 months (360 days, i.e.
-- twelve 30-day billing months) after signup, and only for users whose
-- 12 months are fully observed: signup date + 360 days < snapshot date.
--
-- Revenue of a subscription within the horizon: billed months between the
-- subscription start and the earliest of end_date, snapshot date and the
-- horizon end, × mrr_amount (rules as in 02_revenue.sql). Subscriptions
-- that start after the horizon end bring no revenue in it. No subscription
-- starts before its user's signup date in this data (checked), so all
-- revenue counted here falls after signup.


-- export: ltv_12_months_by_channel.csv
WITH snapshot AS (
    SELECT MAX(start_date) AS snapshot_date
    FROM subscriptions
),

users_horizon AS (
    SELECT
        u.user_id,
        a.acquisition_channel,
        a.cost,
        CAST(u.signup_time AS DATE) + 360 AS horizon_end,
        CAST(u.signup_time AS DATE) + 360 < (SELECT snapshot_date FROM snapshot) AS eligible
    FROM users u
    INNER JOIN acquisition_costs a
        ON a.user_id = u.user_id
),

user_value AS (
    SELECT
        h.user_id,
        h.acquisition_channel,
        h.cost,
        h.eligible,
        CASE WHEN s.plan = 'Enterprise' AND s.start_date < h.horizon_end THEN 1 ELSE 0 END AS enterprise,
        CASE
            WHEN s.start_date < h.horizon_end
            THEN GREATEST(CEIL((LEAST(COALESCE(s.end_date, (SELECT snapshot_date FROM snapshot)),
                                      (SELECT snapshot_date FROM snapshot),
                                      h.horizon_end)
                                - s.start_date) / 30.0), 1) * s.mrr_amount
            ELSE 0
        END AS revenue_12m
    FROM users_horizon h
    LEFT JOIN subscriptions s
        ON s.user_id = h.user_id
)

SELECT
    acquisition_channel,
    COUNT(*) AS users,
    COUNT(*) FILTER (WHERE eligible) AS eligible_users,
    ROUND(100.0 * COUNT(*) FILTER (WHERE eligible) / COUNT(*), 1) AS pct_eligible,
    ROUND(SUM(cost) FILTER (WHERE eligible) / COUNT(*) FILTER (WHERE eligible), 2) AS cac_per_user,
    ROUND(SUM(COALESCE(revenue_12m, 0)) FILTER (WHERE eligible) / COUNT(*) FILTER (WHERE eligible), 2) AS ltv_12_months,
    ROUND(SUM(COALESCE(revenue_12m, 0)) FILTER (WHERE eligible) / SUM(cost) FILTER (WHERE eligible), 2) AS ltv_cac_12_months,
    CAST(SUM(enterprise) FILTER (WHERE eligible) AS INTEGER) AS enterprise_users,
    ROUND(SUM(COALESCE(revenue_12m, 0)) FILTER (WHERE eligible AND enterprise = 0)
          / SUM(cost) FILTER (WHERE eligible AND enterprise = 0), 2) AS ltv_cac_12_months_without_enterprise
FROM user_value
GROUP BY acquisition_channel
ORDER BY
    ltv_cac_12_months DESC,
    acquisition_channel;
