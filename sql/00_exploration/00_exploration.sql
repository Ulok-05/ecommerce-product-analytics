-- ============================================================
-- Exploration and Data Quality
-- Data understanding before the analysis
-- ============================================================

-- Blocks:
--   1. Tables and row counts
--   2. Dimensions: events, conversions, channels, plans, features
--   3. Keys: uniqueness and NULLs
--   4. Referential integrity: child tables → users
--   5. Temporal consistency: activity before sign-up
--   6. Duplicates in acquisition_costs
--   Summary


-- ============================================================
-- 1. Tables and row counts
-- ============================================================

SELECT
    'users' AS table_name,
    COUNT(*) AS rows_count
FROM users

UNION ALL

SELECT
    'events',
    COUNT(*)
FROM events

UNION ALL

SELECT
    'subscriptions',
    COUNT(*)
FROM subscriptions

UNION ALL

SELECT
    'conversions',
    COUNT(*)
FROM conversions

UNION ALL

SELECT
    'nps_responses',
    COUNT(*)
FROM nps_responses

UNION ALL

SELECT
    'acquisition_costs',
    COUNT(*)
FROM acquisition_costs;


-- ============================================================
-- 2. Dimensions
-- ============================================================

-- Event types: number of events and unique users per event
SELECT
    event_name,
    COUNT(*) AS events,
    COUNT(DISTINCT user_id) AS users
FROM events
GROUP BY event_name
ORDER BY events DESC;


-- Conversion types
SELECT
    conversion_type,
    COUNT(*) AS conversions,
    COUNT(DISTINCT user_id) AS users
FROM conversions
GROUP BY conversion_type
ORDER BY conversions DESC;


-- Acquisition channels
SELECT
    acquisition_channel,
    COUNT(DISTINCT user_id) AS users,
    SUM(cost) AS total_cost
FROM acquisition_costs
GROUP BY acquisition_channel
ORDER BY total_cost DESC;


-- Subscription plans
SELECT
    plan,
    COUNT(*) AS subscriptions,
    COUNT(DISTINCT user_id) AS users,
    SUM(mrr_amount) AS total_mrr
FROM subscriptions
GROUP BY plan
ORDER BY total_mrr DESC;


-- Product features
SELECT
    feature_name,
    COUNT(*) AS events,
    COUNT(DISTINCT user_id) AS users
FROM events
WHERE feature_name IS NOT NULL
GROUP BY feature_name
ORDER BY users DESC;


-- ============================================================
-- 3. Keys: uniqueness and NULLs
-- ============================================================

-- Duplicate user_id in users (expected: no rows)
SELECT
	user_id,
	COUNT(user_id)
FROM users
GROUP BY user_id
HAVING COUNT(user_id) > 1;


-- NULL user_id in users (expected: 0)
SELECT
	COUNT(*)
FROM users
WHERE user_id IS NULL;


-- ============================================================
-- 4. Referential integrity: child tables → users
-- ============================================================

-- Events without a user (expected: 0)
SELECT
    COUNT(*) AS orphan_events
FROM events e
LEFT JOIN users u
    ON e.user_id = u.user_id
WHERE u.user_id IS NULL;


-- Conversions without a user (expected: 0)
SELECT
    COUNT(*) AS orphan_conversions
FROM conversions c
LEFT JOIN users u
    ON c.user_id = u.user_id
WHERE u.user_id IS NULL;


-- Subscriptions without a user (expected: 0)
SELECT
    COUNT(*) AS orphan_subscriptions
FROM subscriptions s
LEFT JOIN users u
    ON s.user_id = u.user_id
WHERE u.user_id IS NULL;


-- NPS responses without a user (expected: 0)
SELECT
    COUNT(*) AS orphan_nps
FROM nps_responses n
LEFT JOIN users u
    ON n.user_id = u.user_id
WHERE u.user_id IS NULL;


-- Acquisition costs without a user (expected: 0)
SELECT
    COUNT(*) AS orphan_acquisition_costs
FROM acquisition_costs a
LEFT JOIN users u
    ON a.user_id = u.user_id
WHERE u.user_id IS NULL;


-- ============================================================
-- 5. Temporal consistency: activity before sign-up
-- ============================================================

-- Events that happen before the user's sign-up
SELECT
	COUNT(*) AS events_before_signup
FROM events e
INNER JOIN users u
	ON e.user_id = u.user_id
WHERE e.event_time < u.signup_time;


-- Which events happen before sign-up
SELECT
    e.event_name,
    COUNT(*) AS events,
    COUNT(DISTINCT e.user_id) AS users
FROM events e
INNER JOIN users u
    ON e.user_id = u.user_id
WHERE e.event_time < u.signup_time
GROUP BY e.event_name
ORDER BY events DESC;


-- How long before sign-up these events happen
SELECT
    e.event_name,
    ROUND(
        AVG(
            DATE_DIFF('hour', e.event_time, u.signup_time)
        ), 2
    ) AS avg_hours_before_signup
FROM events e
INNER JOIN users u
    ON e.user_id = u.user_id
WHERE e.event_time < u.signup_time
GROUP BY e.event_name
ORDER BY avg_hours_before_signup DESC;

/* The dataset contains pre-signup activity, and the timing suggests
   that some events may belong to a different behavioral period or
   synthetic data-generation logic.

   Most of these events are concentrated in June–August 2023 and form
   an anomaly in engagement metrics. It is investigated in
   sql/01_engagement/00_data_quality.sql and excluded via the table
   events_clean (setup/01_create_events_clean.sql). */


-- Conversions before sign-up
SELECT
    c.conversion_type,
    COUNT(*) AS conversions,
    COUNT(DISTINCT c.user_id) AS users
FROM conversions c
INNER JOIN users u
    ON c.user_id = u.user_id
WHERE c.conversion_time < u.signup_time
GROUP BY c.conversion_type
ORDER BY conversions DESC;

/* There are 3 conversions recorded before sign-up, all of them
   trial_signup. This is a minor temporal inconsistency / limitation
   in the synthetic dataset. */


-- Subscriptions that start before sign-up (expected: no rows)
SELECT
    s.plan,
    COUNT(*) AS subscriptions,
    COUNT(DISTINCT s.user_id) AS users
FROM subscriptions s
INNER JOIN users u
    ON s.user_id = u.user_id
WHERE s.start_date < CAST(u.signup_time AS DATE)
GROUP BY s.plan
ORDER BY subscriptions DESC;

-- Result: no subscriptions start before sign-up.


-- Users with several subscriptions (expected: no rows)
SELECT
    user_id,
    COUNT(*) AS subscription_count
FROM subscriptions
GROUP BY user_id
HAVING COUNT(*) > 1
ORDER BY subscription_count DESC;

-- Result: each user has at most one subscription record.


-- Subscriptions with end_date before start_date (expected: 0)
SELECT
    COUNT(*) AS invalid_subscriptions
FROM subscriptions
WHERE end_date < start_date;


-- ============================================================
-- 6. Duplicates in acquisition_costs
-- ============================================================

-- Users with several acquisition records (expected: no rows)
SELECT
    user_id,
    COUNT(*) AS acquisition_records
FROM acquisition_costs
GROUP BY user_id
HAVING COUNT(*) > 1
ORDER BY acquisition_records DESC;


-- Fully duplicated rows (same user, channel and cost)
SELECT
    user_id,
    acquisition_channel,
    cost,
    COUNT(*) AS duplicate_records
FROM acquisition_costs
GROUP BY
    user_id,
    acquisition_channel,
    cost
HAVING COUNT(*) > 1
ORDER BY duplicate_records DESC;


-- Total rows vs unique rows
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT
        user_id || '|' || acquisition_channel || '|' || cost
    ) AS unique_rows
FROM acquisition_costs;

-- Result: no duplicates, one acquisition record per user.


/*
==========================================================
SUMMARY — DATA UNDERSTANDING & DATA QUALITY
==========================================================

The dataset contains data about:

- users and registrations
- product events and feature usage
- conversions
- subscriptions and MRR
- acquisition channels and acquisition costs
- NPS responses

Data quality checks showed:

- user_id in the users table is unique and not NULL
- all child tables reference existing users
- some events occur before sign-up, most of them form an anomaly
  in June–August 2023 (see sql/01_engagement/00_data_quality.sql)
- 3 trial_signup conversions occur before sign-up
- subscription dates are valid
- each user has at most one subscription
- acquisition_costs has one record per user, without duplicates

Dataset limitations:

- some temporal inconsistencies exist
- pre-signup events may represent pre-registration activity
  or synthetic data generation logic

Therefore, results involving event timing should be
interpreted with caution.
*/
