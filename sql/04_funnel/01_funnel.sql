-- ============================================================
-- Funnel Analysis
-- Sequential purchase funnel
-- Website Visit → View Product → Add to Cart → Checkout Start → Purchase
-- ============================================================

-- Each step is the user's first event of that type that happens AFTER
-- the previous step (logic from an earlier version of this analysis).
--
-- Data: events_clean (events without the June–August 2023 anomalous
-- sessions). The same funnel on events is used only to show the effect
-- of the anomaly. Only fully observed days are used: the last day in
-- the data is only partly covered, so events before
-- CAST(MAX(event_time) AS DATE) are kept.
--
-- Output: one row per funnel step with the number of users who reached it.


-- Funnel on cleaned data, no time limit

-- export: funnel_steps.csv
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
    SELECT
        user_id,
        MIN(event_time) AS step_time
    FROM events_observed
    WHERE event_name = 'website_visit'
    GROUP BY user_id
),

view_step AS (
    SELECT
        e.user_id,
        MIN(e.event_time) AS step_time
    FROM visit_step p
    INNER JOIN events_observed e
        ON e.user_id = p.user_id
    WHERE e.event_name = 'view_product_page'
      AND e.event_time > p.step_time
    GROUP BY e.user_id
),

cart_step AS (
    SELECT
        e.user_id,
        MIN(e.event_time) AS step_time
    FROM view_step p
    INNER JOIN events_observed e
        ON e.user_id = p.user_id
    WHERE e.event_name = 'add_to_cart'
      AND e.event_time > p.step_time
    GROUP BY e.user_id
),

checkout_start_step AS (
    SELECT
        e.user_id,
        MIN(e.event_time) AS step_time
    FROM cart_step p
    INNER JOIN events_observed e
        ON e.user_id = p.user_id
    WHERE e.event_name = 'checkout_start'
      AND e.event_time > p.step_time
    GROUP BY e.user_id
),

purchase_step AS (
    SELECT
        e.user_id,
        MIN(e.event_time) AS step_time
    FROM checkout_start_step p
    INNER JOIN events_observed e
        ON e.user_id = p.user_id
    WHERE e.event_name = 'checkout_complete'
      AND e.event_time > p.step_time
    GROUP BY e.user_id
)

SELECT 1 AS step_order, 'Website Visit' AS step, COUNT(*) AS users FROM visit_step
UNION ALL
SELECT 2, 'View Product', COUNT(*) FROM view_step
UNION ALL
SELECT 3, 'Add to Cart', COUNT(*) FROM cart_step
UNION ALL
SELECT 4, 'Checkout Start', COUNT(*) FROM checkout_start_step
UNION ALL
SELECT 5, 'Purchase', COUNT(*) FROM purchase_step
ORDER BY step_order;



-- The same funnel on all events (including the anomalous sessions)

-- export: funnel_steps_all.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events
),

events_observed AS (
    SELECT *
    FROM events
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
)

SELECT 1 AS step_order, 'Website Visit' AS step, COUNT(*) AS users FROM visit_step
UNION ALL
SELECT 2, 'View Product', COUNT(*) FROM view_step
UNION ALL
SELECT 3, 'Add to Cart', COUNT(*) FROM cart_step
UNION ALL
SELECT 4, 'Checkout Start', COUNT(*) FROM checkout_start_step
UNION ALL
SELECT 5, 'Purchase', COUNT(*) FROM purchase_step
ORDER BY step_order;
