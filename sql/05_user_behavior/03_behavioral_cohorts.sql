-- ============================================================
-- Behavioral cohorts
-- Do users who use a feature convert better?
-- ============================================================

-- Based on an earlier version of this analysis (the draft method in Step 1).
-- Data: events_clean, only fully observed days.
--
-- Three steps:
--   1. The draft method: feature_click between the first visit and the
--      last funnel step the user reached; outcome = purchase through the
--      sequential funnel with no time limit (04_funnel, Section 4).
--   2. The same comparison for all non-funnel event types: with the draft
--      method, and with fixed windows — the event in the first 30 days
--      after the first visit, the outcome = any purchase in days 31–60.
--   3. feature_click in the first 30 days within groups of users with
--      similar activity in the same first 30 days; the same outcome.
--
-- In steps 2 and 3 the action and the activity are measured before the
-- outcome, and all users have the same periods. A user is included only
-- if both windows are observed (first visit + 60 days < data end).


-- Step 1. Draft method: feature users vs non-feature users

-- export: feature_cohort_draft.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

-- Sequential funnel from 04_funnel/01_funnel.sql (no time limit)
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
    -- One row per user who visited: first visit, last step reached, purchase through the funnel
    SELECT
        v.user_id,
        v.step_time AS first_visit_time,
        COALESCE(p.step_time, cs.step_time, c.step_time, vw.step_time, v.step_time) AS last_step_time,
        CASE WHEN p.user_id IS NOT NULL THEN 1 ELSE 0 END AS purchase
    FROM visit_step v
    LEFT JOIN view_step vw ON vw.user_id = v.user_id
    LEFT JOIN cart_step c ON c.user_id = v.user_id
    LEFT JOIN checkout_start_step cs ON cs.user_id = v.user_id
    LEFT JOIN purchase_step p ON p.user_id = v.user_id
),

cohorts AS (
    SELECT
        f.user_id,
        f.purchase,
        f.first_visit_time,
        f.last_step_time,
        CASE WHEN EXISTS (
            SELECT 1 FROM events_observed e
            WHERE e.user_id = f.user_id
              AND e.event_name = 'feature_click'
              AND e.event_time > f.first_visit_time
              AND e.event_time < f.last_step_time
        ) THEN 'Feature users' ELSE 'Non-feature users' END AS cohort
    FROM user_funnel f
)

SELECT
    cohort,
    COUNT(*) AS users,
    CAST(SUM(purchase) AS INTEGER) AS purchase_users,
    ROUND(100.0 * SUM(purchase) / COUNT(*), 1) AS conversion_pct,
    -- Users who did not get past the first visit: their interval is empty
    COUNT(*) FILTER (WHERE last_step_time = first_visit_time) AS users_only_visit,
    MEDIAN(date_diff('day', first_visit_time, last_step_time)) AS median_days_visit_to_last_step
FROM cohorts
GROUP BY cohort
ORDER BY cohort;



-- Step 2a. All non-funnel event types, draft method

-- export: cohort_by_event_type_draft.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

-- Sequential funnel from 04_funnel/01_funnel.sql (no time limit)
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
    -- One row per user who visited: first visit, last step reached, purchase through the funnel
    SELECT
        v.user_id,
        v.step_time AS first_visit_time,
        COALESCE(p.step_time, cs.step_time, c.step_time, vw.step_time, v.step_time) AS last_step_time,
        CASE WHEN p.user_id IS NOT NULL THEN 1 ELSE 0 END AS purchase
    FROM visit_step v
    LEFT JOIN view_step vw ON vw.user_id = v.user_id
    LEFT JOIN cart_step c ON c.user_id = v.user_id
    LEFT JOIN checkout_start_step cs ON cs.user_id = v.user_id
    LEFT JOIN purchase_step p ON p.user_id = v.user_id
),


event_types AS (
    SELECT *
    FROM (VALUES
        ('feature_click'), ('app_open'), ('content_share'), ('notification_click'),
        ('profile_view'), ('search'), ('settings_change'), ('video_play')
    ) AS t(event_name)
),

user_flags AS (
    SELECT
        t.event_name,
        f.purchase,
        EXISTS (
            SELECT 1 FROM events_observed e
            WHERE e.user_id = f.user_id
              AND e.event_name = t.event_name
              AND e.event_time > f.first_visit_time
              AND e.event_time < f.last_step_time
        ) AS has_event
    FROM user_funnel f
    CROSS JOIN event_types t
)

SELECT
    event_name,
    COUNT(*) FILTER (WHERE has_event) AS users_with_event,
    COUNT(*) FILTER (WHERE NOT has_event) AS users_without_event,
    ROUND(100.0 * AVG(purchase) FILTER (WHERE has_event), 1) AS conversion_with_event_pct,
    ROUND(100.0 * AVG(purchase) FILTER (WHERE NOT has_event), 1) AS conversion_without_event_pct
FROM user_flags
GROUP BY event_name
ORDER BY event_name;



-- Step 2b. All non-funnel event types, fixed windows:
-- the event in days 1–30 after the first visit, any purchase in days 31–60

-- export: cohort_by_event_type_fixed.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

eligible_users AS (
    -- First visit; both windows (days 1–30 and 31–60) must be observed
    SELECT user_id, MIN(event_time) AS first_visit_time
    FROM events_observed
    WHERE event_name = 'website_visit'
    GROUP BY user_id
    HAVING MIN(event_time) + INTERVAL 60 DAY < (SELECT end_date FROM data_end)
),

later_purchase AS (
    -- Any purchase in days 31–60 after the first visit
    SELECT
        u.user_id,
        CASE WHEN EXISTS (
            SELECT 1 FROM events_observed e
            WHERE e.user_id = u.user_id
              AND e.event_name = 'checkout_complete'
              AND e.event_time > u.first_visit_time + INTERVAL 30 DAY
              AND e.event_time <= u.first_visit_time + INTERVAL 60 DAY
        ) THEN 1 ELSE 0 END AS purchase
    FROM eligible_users u
),

event_types AS (
    SELECT *
    FROM (VALUES
        ('feature_click'), ('app_open'), ('content_share'), ('notification_click'),
        ('profile_view'), ('search'), ('settings_change'), ('video_play')
    ) AS t(event_name)
),

user_flags AS (
    SELECT
        t.event_name,
        p.purchase,
        EXISTS (
            SELECT 1 FROM events_observed e
            WHERE e.user_id = u.user_id
              AND e.event_name = t.event_name
              AND e.event_time > u.first_visit_time
              AND e.event_time <= u.first_visit_time + INTERVAL 30 DAY
        ) AS has_event
    FROM eligible_users u
    INNER JOIN later_purchase p ON p.user_id = u.user_id
    CROSS JOIN event_types t
)

SELECT
    event_name,
    COUNT(*) FILTER (WHERE has_event) AS users_with_event,
    COUNT(*) FILTER (WHERE NOT has_event) AS users_without_event,
    ROUND(100.0 * AVG(purchase) FILTER (WHERE has_event), 1) AS purchase_with_event_pct,
    ROUND(100.0 * AVG(purchase) FILTER (WHERE NOT has_event), 1) AS purchase_without_event_pct
FROM user_flags
GROUP BY event_name
ORDER BY event_name;



-- Step 3. feature_click in days 1–30 within early activity quartiles
-- Early activity = events of the user from the first visit to day 30,
-- except session_end. Quartiles split eligible users into four equal
-- groups by early activity. Outcome = any purchase in days 31–60.

-- export: feature_cohort_by_activity.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

eligible_users AS (
    -- First visit; both windows (days 1–30 and 31–60) must be observed
    SELECT user_id, MIN(event_time) AS first_visit_time
    FROM events_observed
    WHERE event_name = 'website_visit'
    GROUP BY user_id
    HAVING MIN(event_time) + INTERVAL 60 DAY < (SELECT end_date FROM data_end)
),

later_purchase AS (
    -- Any purchase in days 31–60 after the first visit
    SELECT
        u.user_id,
        CASE WHEN EXISTS (
            SELECT 1 FROM events_observed e
            WHERE e.user_id = u.user_id
              AND e.event_name = 'checkout_complete'
              AND e.event_time > u.first_visit_time + INTERVAL 30 DAY
              AND e.event_time <= u.first_visit_time + INTERVAL 60 DAY
        ) THEN 1 ELSE 0 END AS purchase
    FROM eligible_users u
),

early_activity AS (
    SELECT
        u.user_id,
        COUNT(*) FILTER (WHERE e.event_name <> 'session_end') AS early_events,
        BOOL_OR(e.event_name = 'feature_click' AND e.event_time > u.first_visit_time) AS feature_click_30d
    FROM eligible_users u
    INNER JOIN events_observed e
        ON e.user_id = u.user_id
       AND e.event_time >= u.first_visit_time
       AND e.event_time <= u.first_visit_time + INTERVAL 30 DAY
    GROUP BY u.user_id
),

quartiles AS (
    SELECT
        a.*,
        p.purchase,
        NTILE(4) OVER (ORDER BY a.early_events, a.user_id) AS activity_quartile
    FROM early_activity a
    INNER JOIN later_purchase p ON p.user_id = a.user_id
)

SELECT
    activity_quartile,
    MIN(early_events) AS min_early_events,
    MAX(early_events) AS max_early_events,
    COUNT(*) AS users,
    ROUND(100.0 * AVG(purchase), 1) AS purchase_pct,
    COUNT(*) FILTER (WHERE feature_click_30d) AS feature_users,
    COUNT(*) FILTER (WHERE NOT feature_click_30d) AS non_feature_users,
    ROUND(100.0 * AVG(purchase) FILTER (WHERE feature_click_30d), 1) AS purchase_feature_pct,
    ROUND(100.0 * AVG(purchase) FILTER (WHERE NOT feature_click_30d), 1) AS purchase_non_feature_pct
FROM quartiles
GROUP BY activity_quartile
ORDER BY activity_quartile;
