-- ============================================================
-- Engagement Analysis
-- DAU, WAU, MAU and Stickiness
-- ============================================================

-- Only complete periods are included.
-- The last day in the data is only partly covered, so the data end
-- is the start of that day: CAST(MAX(event_time) AS DATE).
-- A period is complete if period start + period length <= data end.

-- Each metric is calculated twice: on all data (events) and on cleaned
-- data (events_clean), which excludes the June–August 2023 anomaly.

-- Days without events are kept as DAU = 0: a calendar of all days
-- is built with range() and daily DAU is joined to it with LEFT JOIN.
-- In stickiness, the same is achieved by dividing the monthly sum of
-- daily DAU by the number of days in the month.


-- Daily Active Users (DAU)
-- Number of unique users who performed at least one event per day.

-- export: dau_by_day.csv
WITH calendar AS (
	SELECT range AS day
	FROM range(
		(SELECT date_trunc('month', MIN(event_time)) FROM events),
		(SELECT CAST(MAX(event_time) AS DATE) FROM events),
		INTERVAL 1 DAY
	)
),

daily AS (
	SELECT
		date_trunc('day', event_time) AS day,
		COUNT(DISTINCT user_id) AS dau
	FROM events
	GROUP BY day
)

SELECT
	c.day,
	COALESCE(d.dau, 0) AS dau
FROM calendar c
LEFT JOIN daily d
	ON c.day = d.day
ORDER BY c.day;


WITH calendar AS (
	SELECT range AS day
	FROM range(
		(SELECT date_trunc('month', MIN(event_time)) FROM events),
		(SELECT CAST(MAX(event_time) AS DATE) FROM events),
		INTERVAL 1 DAY
	)
),

daily AS (
	SELECT
		date_trunc('day', event_time) AS day,
		COUNT(DISTINCT user_id) AS dau
	FROM events
	GROUP BY day
)

SELECT
    MIN(COALESCE(d.dau, 0)) AS min_dau,
    MAX(COALESCE(d.dau, 0)) AS max_dau,
    ROUND(AVG(COALESCE(d.dau, 0)), 2) AS avg_dau
FROM calendar c
LEFT JOIN daily d
	ON c.day = d.day;


-- Weekly Active Users (WAU)
-- Number of unique users who performed at least one event per week.

-- export: wau_by_week.csv
SELECT
	date_trunc('week', event_time) AS week,
	COUNT(DISTINCT user_id) AS wau
FROM events
WHERE date_trunc('week', event_time) + INTERVAL 7 DAY
      <= (SELECT CAST(MAX(event_time) AS DATE) FROM events)
GROUP BY week
ORDER BY week;



-- Monthly Active Users (MAU)
-- Number of unique users who performed at least one event per month.

-- export: mau_by_month.csv
SELECT
	date_trunc('month', event_time) AS month,
	COUNT(DISTINCT user_id) AS mau
FROM events
WHERE date_trunc('month', event_time) + INTERVAL 1 MONTH
      <= (SELECT CAST(MAX(event_time) AS DATE) FROM events)
GROUP BY month
ORDER BY month;



-- Stickiness (DAU/MAU)
-- Average DAU divided by MAU for each complete calendar month.
-- Average DAU = sum of daily DAU / number of days in the month.
-- The sum of daily DAU equals the number of (user, active day) pairs,
-- and days without events add nothing to it, so dividing by the full
-- length of the month counts them as DAU = 0 without a calendar.

-- export: stickiness_pct.csv
WITH active_user_days AS (
	-- one row per user per day with at least one event, complete months only
	SELECT DISTINCT
		user_id,
		CAST(event_time AS DATE) AS day
	FROM events
	WHERE date_trunc('month', event_time) + INTERVAL 1 MONTH
	      <= (SELECT CAST(MAX(event_time) AS DATE) FROM events)
),

monthly AS (
	SELECT
		date_trunc('month', day) AS month,
		COUNT(*) AS dau_sum,                 -- sum of daily DAU over the month
		COUNT(DISTINCT user_id) AS mau
	FROM active_user_days
	GROUP BY month
)

SELECT
	month,
	ROUND(dau_sum * 1.0 / day(last_day(month)), 2) AS monthly_avg_dau,
	mau,
	ROUND(dau_sum * 100.0 / day(last_day(month)) / mau, 2) AS stickiness_pct
FROM monthly
ORDER BY month;


-- ============================================================
-- Cleaned versions: the same queries on events_clean
-- (events without the June–August 2023 anomalous sessions,
-- see setup/01_create_events_clean.sql and 00_data_quality.sql).
-- These are the main results used in the report.
-- ============================================================


-- Daily Active Users (DAU), cleaned
-- Number of unique users who performed at least one event per day.

-- export: dau_by_day_clean.csv
WITH calendar AS (
	SELECT range AS day
	FROM range(
		(SELECT date_trunc('month', MIN(event_time)) FROM events_clean),
		(SELECT CAST(MAX(event_time) AS DATE) FROM events_clean),
		INTERVAL 1 DAY
	)
),

daily AS (
	SELECT
		date_trunc('day', event_time) AS day,
		COUNT(DISTINCT user_id) AS dau
	FROM events_clean
	GROUP BY day
)

SELECT
	c.day,
	COALESCE(d.dau, 0) AS dau
FROM calendar c
LEFT JOIN daily d
	ON c.day = d.day
ORDER BY c.day;


WITH calendar AS (
	SELECT range AS day
	FROM range(
		(SELECT date_trunc('month', MIN(event_time)) FROM events_clean),
		(SELECT CAST(MAX(event_time) AS DATE) FROM events_clean),
		INTERVAL 1 DAY
	)
),

daily AS (
	SELECT
		date_trunc('day', event_time) AS day,
		COUNT(DISTINCT user_id) AS dau
	FROM events_clean
	GROUP BY day
)

SELECT
    MIN(COALESCE(d.dau, 0)) AS min_dau,
    MAX(COALESCE(d.dau, 0)) AS max_dau,
    ROUND(AVG(COALESCE(d.dau, 0)), 2) AS avg_dau
FROM calendar c
LEFT JOIN daily d
	ON c.day = d.day;


-- Weekly Active Users (WAU), cleaned
-- Number of unique users who performed at least one event per week.

-- export: wau_by_week_clean.csv
SELECT
	date_trunc('week', event_time) AS week,
	COUNT(DISTINCT user_id) AS wau
FROM events_clean
WHERE date_trunc('week', event_time) + INTERVAL 7 DAY
      <= (SELECT CAST(MAX(event_time) AS DATE) FROM events_clean)
GROUP BY week
ORDER BY week;



-- Monthly Active Users (MAU), cleaned
-- Number of unique users who performed at least one event per month.

-- export: mau_by_month_clean.csv
SELECT
	date_trunc('month', event_time) AS month,
	COUNT(DISTINCT user_id) AS mau
FROM events_clean
WHERE date_trunc('month', event_time) + INTERVAL 1 MONTH
      <= (SELECT CAST(MAX(event_time) AS DATE) FROM events_clean)
GROUP BY month
ORDER BY month;



-- Stickiness (DAU/MAU), cleaned
-- Average DAU divided by MAU for each complete calendar month.
-- Average DAU = sum of daily DAU / number of days in the month.
-- The sum of daily DAU equals the number of (user, active day) pairs,
-- and days without events add nothing to it, so dividing by the full
-- length of the month counts them as DAU = 0 without a calendar.

-- export: stickiness_pct_clean.csv
WITH active_user_days AS (
	-- one row per user per day with at least one event, complete months only
	SELECT DISTINCT
		user_id,
		CAST(event_time AS DATE) AS day
	FROM events_clean
	WHERE date_trunc('month', event_time) + INTERVAL 1 MONTH
	      <= (SELECT CAST(MAX(event_time) AS DATE) FROM events_clean)
),

monthly AS (
	SELECT
		date_trunc('month', day) AS month,
		COUNT(*) AS dau_sum,                 -- sum of daily DAU over the month
		COUNT(DISTINCT user_id) AS mau
	FROM active_user_days
	GROUP BY month
)

SELECT
	month,
	ROUND(dau_sum * 1.0 / day(last_day(month)), 2) AS monthly_avg_dau,
	mau,
	ROUND(dau_sum * 100.0 / day(last_day(month)) / mau, 2) AS stickiness_pct
FROM monthly
ORDER BY month;
