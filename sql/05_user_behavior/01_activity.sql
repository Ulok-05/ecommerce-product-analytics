-- ============================================================
-- User activity
-- How many events and active days does a user have?
-- ============================================================

-- Data: events_clean, only fully observed days (events before the start
-- of the partially covered last day, the same boundary as in 01–04).
-- session_end is excluded, as it is a technical event.


-- Event types: number of events and users

-- export: event_types.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
      AND event_name <> 'session_end'
)

SELECT
    event_name,
    COUNT(*) AS events,
    COUNT(DISTINCT user_id) AS users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_events
FROM events_observed
GROUP BY event_name
ORDER BY
    events DESC,
    event_name;



-- Activity per user: events, active days, event types and the length of
-- the active period (from the first to the last event, in days)

-- export: user_activity.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
      AND event_name <> 'session_end'
)

SELECT
    user_id,
    COUNT(*) AS events,
    COUNT(DISTINCT CAST(event_time AS DATE)) AS active_days,
    COUNT(DISTINCT event_name) AS event_types,
    date_diff('day', CAST(MIN(event_time) AS DATE), CAST(MAX(event_time) AS DATE)) + 1 AS active_period_days
FROM events_observed
GROUP BY user_id
ORDER BY user_id;



-- feature_click by feature: feature_click covers several features,
-- identified by feature_name

-- export: feature_click_by_feature.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
)

SELECT
    feature_name,
    COUNT(*) AS events,
    COUNT(DISTINCT user_id) AS users
FROM events_clean
WHERE event_name = 'feature_click'
  AND event_time < (SELECT end_date FROM data_end)
GROUP BY feature_name
ORDER BY
    events DESC,
    feature_name;
