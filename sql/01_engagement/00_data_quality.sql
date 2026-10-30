-- ============================================================
-- Data Quality: June–August 2023 anomaly
-- Checks that support excluding the anomalous sessions
-- (see setup/01_create_events_clean.sql)
-- ============================================================


-- Check 1. Active users vs. sign-ups by month
-- In a normal month almost all active users are already signed up.
-- If extra activity comes from new customers, sign-ups should grow too.

-- export: dq_activity_vs_signups.csv
WITH activity AS (
	SELECT
		date_trunc('month', e.event_time) AS month,
		COUNT(DISTINCT e.user_id) AS mau,
		COUNT(DISTINCT CASE WHEN e.event_time < u.signup_time
		                    THEN e.user_id END) AS active_before_signup
	FROM events e
	JOIN users u
		ON e.user_id = u.user_id
	WHERE date_trunc('month', e.event_time) + INTERVAL 1 MONTH
	      <= (SELECT CAST(MAX(event_time) AS DATE) FROM events)
	GROUP BY month
),

signups AS (
	SELECT
		date_trunc('month', signup_time) AS month,
		COUNT(*) AS signups
	FROM users
	GROUP BY month
)

SELECT
	a.month,
	COALESCE(s.signups, 0) AS signups,
	a.mau,
	a.active_before_signup
FROM activity a
LEFT JOIN signups s
	ON a.month = s.month
ORDER BY a.month;


-- Check 2. When did users who were active before sign-up
-- in June–August 2023 actually sign up?

-- export: dq_signup_year.csv
SELECT
	EXTRACT(year FROM u.signup_time) AS signup_year,
	COUNT(DISTINCT u.user_id) AS users
FROM events e
JOIN users u
	ON e.user_id = u.user_id
WHERE e.event_time >= '2023-06-01'
  AND e.event_time <  '2023-09-01'
  AND e.event_time < u.signup_time
GROUP BY signup_year
ORDER BY signup_year;


-- Check 3a. Most common session profiles in June–August 2023
-- No pattern is specified in advance: sessions are grouped by their
-- set of event types and number of events, and the most frequent
-- profiles are listed.

-- export: dq_session_profiles.csv
WITH sessions AS (
	SELECT
		session_id,
		MIN(event_time) AS session_start,
		COUNT(*) AS n_events,
		STRING_AGG(DISTINCT event_name, ' + ' ORDER BY event_name) AS event_types
	FROM events
	GROUP BY session_id
)

SELECT
	event_types,
	n_events,
	COUNT(*) AS sessions
FROM sessions
WHERE session_start >= '2023-06-01'
  AND session_start <  '2023-09-01'
GROUP BY
	event_types,
	n_events
ORDER BY
	sessions DESC,
	event_types
LIMIT 5;


-- Check 3b. How often does the most common profile from Check 3a occur
-- in each month?
-- Step 1: one row per session with its start time, number of events
-- and the set of event types (sorted alphabetically, so the same set
-- always gives the same string).
-- Step 2: per month, count all sessions and sessions with exactly
-- these 4 events, each occurring once.

-- export: dq_session_pattern.csv
WITH sessions AS (
	SELECT
		session_id,
		MIN(event_time) AS session_start,
		COUNT(*) AS n_events,
		STRING_AGG(DISTINCT event_name, ' + ' ORDER BY event_name) AS event_types
	FROM events
	GROUP BY session_id
)

SELECT
	date_trunc('month', session_start) AS month,
	COUNT(*) AS all_sessions,
	COUNT(CASE WHEN n_events = 4
	            AND event_types = 'add_to_cart + session_end + view_product_page + website_visit'
	           THEN 1 END) AS pattern_sessions
FROM sessions
GROUP BY month
HAVING pattern_sessions > 0
ORDER BY month;


-- Check 3c. Order and duration of the pattern sessions from Check 3b
-- STRING_AGG in Checks 3a and 3b sorts event types alphabetically, so it
-- shows which events a session contains, but not their order. Here the
-- events are joined in time order, and the session duration is added.

-- export: dq_session_sequence.csv
WITH sessions AS (
	SELECT
		session_id,
		MIN(event_time) AS session_start,
		COUNT(*) AS n_events,
		STRING_AGG(DISTINCT event_name, ' + ' ORDER BY event_name) AS event_types,
		STRING_AGG(event_name, ' -> ' ORDER BY event_time) AS event_sequence,
		date_diff('second', MIN(event_time), MAX(event_time)) AS duration_sec
	FROM events
	GROUP BY session_id
)

SELECT
	event_sequence,
	duration_sec,
	COUNT(*) AS sessions
FROM sessions
WHERE n_events = 4
  AND event_types = 'add_to_cart + session_end + view_product_page + website_visit'
  AND session_start >= '2023-06-01'
  AND session_start <  '2023-09-01'
GROUP BY
	event_sequence,
	duration_sec
ORDER BY sessions DESC;
