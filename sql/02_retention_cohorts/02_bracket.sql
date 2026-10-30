-- ==========================================================
-- Bracket Retention by monthly cohort
-- ==========================================================

-- Bracket retention: share of eligible users who were active at least
-- once during a time interval after their first event.
-- Brackets: Day 1–7, Day 8–14, Day 15–30, Day 31+.
--
-- Data: events_clean. Cohort: the month of a user's first event.
-- A bracket is included for a user only if it is fully observed:
-- first_date + last day of the bracket < data end. For Day 31+ the
-- user must be observable for at least 31 days.


-- export: bracket_retention_monthly.csv
WITH data_end AS (

    -- Start of the last, partly covered day (exclusive end of the data)

    SELECT
        CAST(MAX(event_time) AS DATE) AS end_date
    FROM events_clean

),

user_first_event AS (

    -- First activity date and cohort month of each user

    SELECT
        user_id,
        MIN(CAST(event_time AS DATE)) AS first_date,
        date_trunc('month', MIN(event_time)) AS cohort_month
    FROM events_clean
    GROUP BY user_id

),

user_activity AS (

    -- One row per user per active day, only fully observed days

    SELECT DISTINCT
        user_id,
        CAST(event_time AS DATE) AS activity_date
    FROM events_clean
    WHERE CAST(event_time AS DATE) < (SELECT end_date FROM data_end)

),

retention_brackets AS (

    -- Bracket boundaries in days since the first event

    SELECT *
    FROM (VALUES
        (1, 'Day 1-7',   1,  7),
        (2, 'Day 8-14',  8,  14),
        (3, 'Day 15-30', 15, 30),
        (4, 'Day 31+',   31, NULL)
    ) AS b(bracket_order, bracket, first_day, last_day)

),

eligible_users AS (

    -- Users for whom the bracket is fully observed

    SELECT
        u.user_id,
        u.first_date,
        u.cohort_month,
        b.bracket_order,
        b.first_day,
        b.last_day
    FROM user_first_event u
    CROSS JOIN retention_brackets b
    WHERE u.first_date + COALESCE(b.last_day, b.first_day)
          < (SELECT end_date FROM data_end)

),

returned_users AS (

    -- Eligible users with at least one active day inside the bracket

    SELECT DISTINCT
        e.cohort_month,
        e.bracket_order,
        e.user_id
    FROM eligible_users e
    INNER JOIN user_activity a
        ON a.user_id = e.user_id
        AND a.activity_date - e.first_date >= e.first_day
        AND (e.last_day IS NULL OR a.activity_date - e.first_date <= e.last_day)

),

retention_table AS (

    -- Eligible and returning users for each cohort month and bracket

    SELECT
        e.cohort_month,
        e.bracket_order,
        COUNT(DISTINCT e.user_id) AS eligible_users,
        COUNT(DISTINCT r.user_id) AS returned_users
    FROM eligible_users e
    LEFT JOIN returned_users r
        ON r.cohort_month = e.cohort_month
        AND r.bracket_order = e.bracket_order
        AND r.user_id = e.user_id
    GROUP BY
        e.cohort_month,
        e.bracket_order

)

SELECT
    cohort_month,
    ROUND(MAX(CASE WHEN bracket_order = 1 THEN returned_users * 100.0 / eligible_users END), 2) AS day1_7,
    ROUND(MAX(CASE WHEN bracket_order = 2 THEN returned_users * 100.0 / eligible_users END), 2) AS day8_14,
    ROUND(MAX(CASE WHEN bracket_order = 3 THEN returned_users * 100.0 / eligible_users END), 2) AS day15_30,
    ROUND(MAX(CASE WHEN bracket_order = 4 THEN returned_users * 100.0 / eligible_users END), 2) AS day31_plus
FROM retention_table
GROUP BY cohort_month
ORDER BY cohort_month;
