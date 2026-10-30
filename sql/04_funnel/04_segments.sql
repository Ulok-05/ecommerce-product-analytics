-- ============================================================
-- Funnel by segment: country, acquisition channel, plan
-- ============================================================

-- The same sequential funnel as in 01_funnel.sql (events_clean, no time
-- limit), split by country (users), acquisition channel
-- (acquisition_costs) and subscription plan (subscriptions; only users
-- with a subscription). Based on an earlier version of this analysis.
--
-- Output: one row per segment type, segment and funnel step.


-- export: funnel_segments.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

visit_step AS (
    SELECT user_id, MIN(event_time) AS step_time
    FROM events_observed
    WHERE event_name = 'website_visit'
    GROUP BY user_id
),

view_step AS (
    SELECT e.user_id, MIN(e.event_time) AS step_time
    FROM visit_step p
    INNER JOIN events_observed e ON e.user_id = p.user_id
    WHERE e.event_name = 'view_product_page' AND e.event_time > p.step_time
    GROUP BY e.user_id
),

cart_step AS (
    SELECT e.user_id, MIN(e.event_time) AS step_time
    FROM view_step p
    INNER JOIN events_observed e ON e.user_id = p.user_id
    WHERE e.event_name = 'add_to_cart' AND e.event_time > p.step_time
    GROUP BY e.user_id
),

checkout_start_step AS (
    SELECT e.user_id, MIN(e.event_time) AS step_time
    FROM cart_step p
    INNER JOIN events_observed e ON e.user_id = p.user_id
    WHERE e.event_name = 'checkout_start' AND e.event_time > p.step_time
    GROUP BY e.user_id
),

purchase_step AS (
    SELECT e.user_id, MIN(e.event_time) AS step_time
    FROM checkout_start_step p
    INNER JOIN events_observed e ON e.user_id = p.user_id
    WHERE e.event_name = 'checkout_complete' AND e.event_time > p.step_time
    GROUP BY e.user_id
),

user_funnel AS (
    -- One row per user who visited: the furthest steps reached
    SELECT
        v.user_id,
        1 AS visit,
        CASE WHEN vw.user_id IS NOT NULL THEN 1 ELSE 0 END AS view_product,
        CASE WHEN c.user_id IS NOT NULL THEN 1 ELSE 0 END AS add_to_cart,
        CASE WHEN cs.user_id IS NOT NULL THEN 1 ELSE 0 END AS checkout_start,
        CASE WHEN p.user_id IS NOT NULL THEN 1 ELSE 0 END AS purchase
    FROM visit_step v
    LEFT JOIN view_step vw ON vw.user_id = v.user_id
    LEFT JOIN cart_step c ON c.user_id = v.user_id
    LEFT JOIN checkout_start_step cs ON cs.user_id = v.user_id
    LEFT JOIN purchase_step p ON p.user_id = v.user_id
),

user_segments AS (
    SELECT 'Country' AS segment_type, user_id, country AS segment FROM users
    UNION ALL
    SELECT 'Acquisition channel', user_id, acquisition_channel FROM acquisition_costs
    UNION ALL
    SELECT 'Plan', user_id, plan FROM subscriptions
)

SELECT
    s.segment_type,
    s.segment,
    COUNT(*) AS visit_users,
    CAST(SUM(f.view_product) AS INTEGER) AS view_users,
    CAST(SUM(f.add_to_cart) AS INTEGER) AS cart_users,
    CAST(SUM(f.checkout_start) AS INTEGER) AS checkout_start_users,
    CAST(SUM(f.purchase) AS INTEGER) AS purchase_users,
    ROUND(SUM(f.purchase) * 100.0 / COUNT(*), 2) AS overall_conversion_pct
FROM user_funnel f
INNER JOIN user_segments s
    ON s.user_id = f.user_id
GROUP BY
    s.segment_type,
    s.segment
ORDER BY
    s.segment_type,
    overall_conversion_pct DESC,
    s.segment;
