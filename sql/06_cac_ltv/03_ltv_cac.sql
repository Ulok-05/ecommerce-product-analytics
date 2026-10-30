-- ============================================================
-- LTV to date and LTV/CAC by channel
-- ============================================================

-- LTV to date = subscription revenue up to the snapshot date per acquired
-- user (users without a subscription or with the Free plan count as 0).
-- Both LTV and CAC use the same denominator — all acquired users of the
-- channel — so LTV/CAC = channel revenue / channel cost.
-- Revenue rules as in 02_revenue.sql.
--
-- Because a few Enterprise subscribers bring a large share of revenue,
-- the same ratio is also calculated without Enterprise subscribers (they
-- are removed from both revenue and cost).


-- export: ltv_cac_by_channel.csv
WITH snapshot AS (
    SELECT MAX(start_date) AS snapshot_date
    FROM subscriptions
),

subscription_revenue AS (
    SELECT
        user_id,
        plan,
        GREATEST(CEIL((LEAST(COALESCE(end_date, (SELECT snapshot_date FROM snapshot)), (SELECT snapshot_date FROM snapshot)) - start_date) / 30.0), 1)
            * mrr_amount AS revenue
    FROM subscriptions
),

user_value AS (
    SELECT
        a.user_id,
        a.acquisition_channel,
        a.cost,
        COALESCE(r.revenue, 0) AS revenue,
        CASE WHEN r.plan = 'Enterprise' THEN 1 ELSE 0 END AS enterprise
    FROM acquisition_costs a
    LEFT JOIN subscription_revenue r
        ON r.user_id = a.user_id
)

SELECT
    acquisition_channel,
    COUNT(*) AS users,
    ROUND(SUM(cost) / COUNT(*), 2) AS cac_per_user,
    ROUND(SUM(revenue) / COUNT(*), 2) AS ltv_to_date,
    ROUND(MEDIAN(revenue), 2) AS median_revenue,
    ROUND(SUM(revenue) / SUM(cost), 2) AS ltv_cac,
    CAST(SUM(enterprise) AS INTEGER) AS enterprise_users,
    ROUND(100.0 * SUM(revenue) FILTER (WHERE enterprise = 1) / SUM(revenue), 1) AS enterprise_pct_of_revenue,
    ROUND(SUM(revenue) FILTER (WHERE enterprise = 0) / COUNT(*) FILTER (WHERE enterprise = 0), 2) AS ltv_to_date_without_enterprise,
    ROUND(SUM(revenue) FILTER (WHERE enterprise = 0) / SUM(cost) FILTER (WHERE enterprise = 0), 2) AS ltv_cac_without_enterprise
FROM user_value
GROUP BY acquisition_channel
ORDER BY
    ltv_cac DESC,
    acquisition_channel;
