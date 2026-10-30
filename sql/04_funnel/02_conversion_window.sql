-- ============================================================
-- Funnel by conversion window
-- ============================================================

-- The same sequential funnel as in 01_funnel.sql, but every step must
-- happen within N days of the user's first website visit.
-- Windows: 7 days, 30 days and no limit.
--
-- A user is included in a window only if the whole window is observed:
-- first visit + N days < data end. Without this rule, users who visited
-- shortly before the data end would look like non-converters.
--
-- Data: events_clean, only fully observed days.
-- Output: one row per window and funnel step.


-- export: funnel_conversion_window.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

conversion_windows AS (
    -- NULL = no time limit
    SELECT *
    FROM (VALUES (7), (30), (NULL)) AS w(window_days)
),

visit_step AS (
    -- First visit of each user, repeated for every window
    -- in which the user can be fully observed
    SELECT
        v.user_id,
        w.window_days,
        v.first_visit_time,
        v.first_visit_time AS step_time
    FROM (
        SELECT user_id, MIN(event_time) AS first_visit_time
        FROM events_observed
        WHERE event_name = 'website_visit'
        GROUP BY user_id
    ) v
    CROSS JOIN conversion_windows w
    WHERE w.window_days IS NULL
       OR v.first_visit_time + to_days(w.window_days) < (SELECT end_date FROM data_end)
),

view_step AS (
    SELECT p.user_id, p.window_days, p.first_visit_time, MIN(e.event_time) AS step_time
    FROM visit_step p
    INNER JOIN events_observed e ON e.user_id = p.user_id
    WHERE e.event_name = 'view_product_page'
      AND e.event_time > p.step_time
      AND (p.window_days IS NULL OR e.event_time <= p.first_visit_time + to_days(p.window_days))
    GROUP BY p.user_id, p.window_days, p.first_visit_time
),

cart_step AS (
    SELECT p.user_id, p.window_days, p.first_visit_time, MIN(e.event_time) AS step_time
    FROM view_step p
    INNER JOIN events_observed e ON e.user_id = p.user_id
    WHERE e.event_name = 'add_to_cart'
      AND e.event_time > p.step_time
      AND (p.window_days IS NULL OR e.event_time <= p.first_visit_time + to_days(p.window_days))
    GROUP BY p.user_id, p.window_days, p.first_visit_time
),

checkout_start_step AS (
    SELECT p.user_id, p.window_days, p.first_visit_time, MIN(e.event_time) AS step_time
    FROM cart_step p
    INNER JOIN events_observed e ON e.user_id = p.user_id
    WHERE e.event_name = 'checkout_start'
      AND e.event_time > p.step_time
      AND (p.window_days IS NULL OR e.event_time <= p.first_visit_time + to_days(p.window_days))
    GROUP BY p.user_id, p.window_days, p.first_visit_time
),

purchase_step AS (
    SELECT p.user_id, p.window_days, p.first_visit_time, MIN(e.event_time) AS step_time
    FROM checkout_start_step p
    INNER JOIN events_observed e ON e.user_id = p.user_id
    WHERE e.event_name = 'checkout_complete'
      AND e.event_time > p.step_time
      AND (p.window_days IS NULL OR e.event_time <= p.first_visit_time + to_days(p.window_days))
    GROUP BY p.user_id, p.window_days, p.first_visit_time
),

all_steps AS (
    SELECT window_days, 1 AS step_order, 'Website Visit' AS step, user_id FROM visit_step
    UNION ALL
    SELECT window_days, 2, 'View Product', user_id FROM view_step
    UNION ALL
    SELECT window_days, 3, 'Add to Cart', user_id FROM cart_step
    UNION ALL
    SELECT window_days, 4, 'Checkout Start', user_id FROM checkout_start_step
    UNION ALL
    SELECT window_days, 5, 'Purchase', user_id FROM purchase_step
),

step_counts AS (
    SELECT window_days, step_order, COUNT(*) AS users
    FROM all_steps
    GROUP BY window_days, step_order
),

funnel_skeleton AS (
    -- Every window × every step, so that steps nobody reached get 0
    SELECT w.window_days, s.step_order, s.step
    FROM conversion_windows w
    CROSS JOIN (VALUES
        (1, 'Website Visit'),
        (2, 'View Product'),
        (3, 'Add to Cart'),
        (4, 'Checkout Start'),
        (5, 'Purchase')
    ) AS s(step_order, step)
)

SELECT
    COALESCE(CAST(k.window_days AS VARCHAR) || ' days', 'No limit') AS conversion_window,
    COALESCE(k.window_days, 99999) AS window_order,
    k.step_order,
    k.step,
    COALESCE(c.users, 0) AS users
FROM funnel_skeleton k
LEFT JOIN step_counts c
    ON c.step_order = k.step_order
    AND c.window_days IS NOT DISTINCT FROM k.window_days
ORDER BY
    window_order,
    step_order;



-- Any purchase within the window vs. purchase through the funnel
-- A purchase "through the funnel" requires all previous steps in order;
-- "any purchase" only requires a checkout_complete event within the
-- window after the first visit. Same eligibility rule as above.

-- export: funnel_window_any_purchase.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

first_visit AS (
    SELECT user_id, MIN(event_time) AS first_visit_time
    FROM events_observed
    WHERE event_name = 'website_visit'
    GROUP BY user_id
),

eligible_visitors AS (
    SELECT v.user_id, v.first_visit_time, w.window_days
    FROM first_visit v
    CROSS JOIN (VALUES (7), (30)) AS w(window_days)
    WHERE v.first_visit_time + to_days(w.window_days) < (SELECT end_date FROM data_end)
)

SELECT
    CAST(v.window_days AS VARCHAR) || ' days' AS conversion_window,
    COUNT(*) AS eligible_visitors,
    COUNT(*) FILTER (WHERE EXISTS (
        SELECT 1
        FROM events_observed e
        WHERE e.user_id = v.user_id
          AND e.event_name = 'checkout_complete'
          AND e.event_time > v.first_visit_time
          AND e.event_time <= v.first_visit_time + to_days(v.window_days)
    )) AS visitors_with_any_purchase
FROM eligible_visitors v
GROUP BY v.window_days
ORDER BY v.window_days;
