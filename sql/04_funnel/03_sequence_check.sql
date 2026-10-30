-- ============================================================
-- Sequence check
-- Do events follow the order of a purchase journey?
-- ============================================================

-- If the events followed a purchase journey, a purchase would be expected
-- to be preceded shortly by checkout start and add to cart, and checkout
-- start would often be followed by a purchase. These checks test whether
-- the events in this dataset follow such an order.
--
-- Data: events_clean, only fully observed days (the same boundary as
-- the funnel). Unlike the funnel, which counts users, these checks are
-- event-level: they count purchase events and event transitions.


-- Check 1. Share of purchases with an earlier funnel step by the same user

-- export: funnel_sequence_before_purchase.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

events_observed AS (
    SELECT *
    FROM events_clean
    WHERE event_time < (SELECT end_date FROM data_end)
),

purchases AS (
    SELECT user_id, event_time
    FROM events_observed
    WHERE event_name = 'checkout_complete'
)

SELECT
    COUNT(*) AS purchases,

    ROUND(100.0 * AVG(CASE WHEN EXISTS (
        SELECT 1 FROM events_observed e
        WHERE e.user_id = p.user_id
          AND e.event_name = 'checkout_start'
          AND e.event_time < p.event_time
          AND e.event_time >= p.event_time - INTERVAL 1 DAY
    ) THEN 1 ELSE 0 END), 1) AS pct_with_checkout_start_24h_before,

    ROUND(100.0 * AVG(CASE WHEN EXISTS (
        SELECT 1 FROM events_observed e
        WHERE e.user_id = p.user_id
          AND e.event_name = 'add_to_cart'
          AND e.event_time < p.event_time
          AND e.event_time >= p.event_time - INTERVAL 1 DAY
    ) THEN 1 ELSE 0 END), 1) AS pct_with_add_to_cart_24h_before,

    ROUND(100.0 * AVG(CASE WHEN EXISTS (
        SELECT 1 FROM events_observed e
        WHERE e.user_id = p.user_id
          AND e.event_name = 'checkout_start'
          AND e.event_time < p.event_time
    ) THEN 1 ELSE 0 END), 1) AS pct_with_any_earlier_checkout_start

FROM purchases p;



-- Check 2. Which event comes next after checkout start?
-- session_end is excluded, as it is a technical event. Events are ordered
-- by event_time; no two events of the same user share a timestamp in this
-- data, so the order is unambiguous. In data with ties, the order of tied
-- events would not be a confirmed sequence of actions.

-- export: funnel_next_event_after_checkout_start.csv
WITH data_end AS (
    SELECT CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean
),

ordered_events AS (
    SELECT
        user_id,
        event_name,
        LEAD(event_name) OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS next_event
    FROM events_clean
    WHERE event_name <> 'session_end'
      AND event_time < (SELECT end_date FROM data_end)
)

SELECT
    next_event,
    COUNT(*) AS transitions,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM ordered_events
WHERE event_name = 'checkout_start'
  AND next_event IS NOT NULL
GROUP BY next_event
ORDER BY
    transitions DESC,
    next_event;
