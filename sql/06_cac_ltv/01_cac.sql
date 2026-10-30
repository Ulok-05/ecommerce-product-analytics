-- ============================================================
-- Customer acquisition cost (CAC) by channel
-- ============================================================

-- acquisition_costs has one row per user: the acquisition channel and the
-- cost attributed to the user. CAC is calculated in two ways:
--   - per acquired user: total cost / acquired users;
--   - per paying subscriber: total cost / users with a paid plan
--     (any plan except Free). This is a blended metric: the cost of all
--     acquired users is divided by the paying ones; the data do not show
--     a separate cost of acquiring paying users.
-- Based on an earlier version of this analysis.


-- export: cac_by_channel.csv
WITH user_costs AS (
    SELECT
        a.user_id,
        a.acquisition_channel,
        a.cost,
        CASE WHEN s.plan IS NOT NULL AND s.plan <> 'Free' THEN 1 ELSE 0 END AS paying
    FROM acquisition_costs a
    LEFT JOIN subscriptions s
        ON s.user_id = a.user_id
)

SELECT
    acquisition_channel,
    COUNT(*) AS users,
    ROUND(SUM(cost), 2) AS total_cost,
    ROUND(SUM(cost) / COUNT(*), 2) AS cac_per_user,
    ROUND(MIN(cost), 2) AS min_cost,
    ROUND(MAX(cost), 2) AS max_cost,
    CAST(SUM(paying) AS INTEGER) AS paying_subscribers,
    ROUND(SUM(cost) / SUM(paying), 2) AS cac_per_paying_subscriber
FROM user_costs
GROUP BY acquisition_channel
ORDER BY
    cac_per_user,
    acquisition_channel;
