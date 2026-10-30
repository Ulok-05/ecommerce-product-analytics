-- ============================================================
-- events_clean: events without the June–August 2023 anomaly
-- ============================================================

-- In June–August 2023 the data contains ~2,165 identical sessions:
-- exactly 4 events (website_visit, view_product_page, add_to_cart,
-- session_end), no checkout, mostly attributed to users before their
-- sign-up date. See sql/01_engagement/00_data_quality.sql for the checks.
--
-- This table is a copy of events without those sessions.
-- The original events table is not changed.
-- If events is reloaded, run this script again to rebuild events_clean.
--
-- Run once after setup/00_create_tables.sql:
--   .read setup/01_create_events_clean.sql

CREATE OR REPLACE TABLE events_clean AS

WITH sessions AS (
    SELECT
        session_id,
        MIN(event_time) AS session_start,
        COUNT(*) AS n_events,
        STRING_AGG(DISTINCT event_name, ' + ' ORDER BY event_name) AS event_types
    FROM events
    GROUP BY session_id
),

anomalous_sessions AS (
    SELECT session_id
    FROM sessions
    WHERE n_events = 4
      AND event_types = 'add_to_cart + session_end + view_product_page + website_visit'
      AND session_start >= '2023-06-01'
      AND session_start <  '2023-09-01'
)

SELECT e.*
FROM events e
LEFT JOIN anomalous_sessions a
    ON e.session_id = a.session_id
WHERE a.session_id IS NULL;
