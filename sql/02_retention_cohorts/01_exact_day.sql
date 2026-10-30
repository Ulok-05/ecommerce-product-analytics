-- ============================================================
-- Retention & Cohort Analysis
-- Exact-Day Retention by monthly cohort
-- ============================================================

-- Cohort: the month of a user's first event.
-- Day-N retention: share of eligible users who were active
-- exactly N days after their first event.
--
-- Data: events_clean (events without the June–August 2023 anomalous
-- sessions, see setup/01_create_events_clean.sql). The same query on
-- events is used only to show how the anomaly distorts the cohorts.
--
-- Observation window: the last day in the data is only partly covered,
-- so the data end is the start of that day: CAST(MAX(event_time) AS DATE).
-- Day N of a user is observed only if first_date + N < data end.
--
-- Monthly retention is calculated over users (eligible users of the
-- whole month), not as an average of daily cohort percentages.
--
-- Output: one row per cohort month and day N with the cohort size,
-- the number of eligible users (denominator), the number of returning
-- users (numerator) and retention in %.


-- export: exact_day_retention_monthly.csv
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

    -- One row per user per active day

    SELECT DISTINCT
        user_id,
        CAST(event_time AS DATE) AS activity_date
    FROM events_clean

),

retention_days AS (

    -- Retention days to analyze

    SELECT *
    FROM (VALUES (1), (2), (3), (7), (14), (30)) AS r(day_n)

),

eligible_users AS (

    -- Users whose day N is fully observed before the data end

    SELECT
        u.user_id,
        u.first_date,
        u.cohort_month,
        r.day_n
    FROM user_first_event u
    CROSS JOIN retention_days r
    WHERE u.first_date + r.day_n < (SELECT end_date FROM data_end)

),

retention_table AS (

    -- Eligible and returning users for each cohort month and day N

    SELECT
        e.cohort_month,
        e.day_n,
        COUNT(*) AS eligible_users,
        COUNT(a.user_id) AS returned_users
    FROM eligible_users e
    LEFT JOIN user_activity a
        ON a.user_id = e.user_id
        AND a.activity_date = e.first_date + e.day_n
    GROUP BY
        e.cohort_month,
        e.day_n

)

SELECT
    t.cohort_month,

    (
        SELECT COUNT(*)
        FROM user_first_event u
        WHERE u.cohort_month = t.cohort_month
    ) AS cohort_users,

    t.day_n,
    t.eligible_users,
    t.returned_users,
    ROUND(t.returned_users * 100.0 / t.eligible_users, 2) AS retention_pct

FROM retention_table t
ORDER BY
    t.cohort_month,
    t.day_n;



-- ============================================================
-- The same query on all events (events), including the anomalous
-- sessions. Used only to show how the anomaly distorts the cohorts.
-- ============================================================

-- export: exact_day_retention_monthly_all.csv
WITH data_end AS (
    SELECT
        CAST(MAX(event_time) AS DATE) AS end_date
    FROM events
),

user_first_event AS (
    SELECT
        user_id,
        MIN(CAST(event_time AS DATE)) AS first_date,
        date_trunc('month', MIN(event_time)) AS cohort_month
    FROM events
    GROUP BY user_id
),

user_activity AS (
    SELECT DISTINCT
        user_id,
        CAST(event_time AS DATE) AS activity_date
    FROM events
),

retention_days AS (
    SELECT *
    FROM (VALUES (1), (2), (3), (7), (14), (30)) AS r(day_n)
),

eligible_users AS (
    SELECT
        u.user_id,
        u.first_date,
        u.cohort_month,
        r.day_n
    FROM user_first_event u
    CROSS JOIN retention_days r
    WHERE u.first_date + r.day_n < (SELECT end_date FROM data_end)
),

retention_table AS (
    SELECT
        e.cohort_month,
        e.day_n,
        COUNT(*) AS eligible_users,
        COUNT(a.user_id) AS returned_users
    FROM eligible_users e
    LEFT JOIN user_activity a
        ON a.user_id = e.user_id
        AND a.activity_date = e.first_date + e.day_n
    GROUP BY
        e.cohort_month,
        e.day_n
)

SELECT
    t.cohort_month,

    (
        SELECT COUNT(*)
        FROM user_first_event u
        WHERE u.cohort_month = t.cohort_month
    ) AS cohort_users,

    t.day_n,
    t.eligible_users,
    t.returned_users,
    ROUND(t.returned_users * 100.0 / t.eligible_users, 2) AS retention_pct

FROM retention_table t
ORDER BY
    t.cohort_month,
    t.day_n;



-- ============================================================
-- Check: how the anomaly changes the June 2023 cohort
-- ============================================================
-- Users in the June 2023 cohort on all data (events), split by whether
-- their first event is an anomalous session (an event that is not in
-- events_clean) and whether it is before their sign-up time. For users
-- whose first event is an anomalous session before sign-up: days from
-- the first event to sign-up, the number of active days before sign-up,
-- and how many of them have any non-anomalous activity before the
-- sign-up date.

-- export: june_2023_cohort_check.csv
WITH first_all AS (
    SELECT user_id, MIN(event_time) AS first_time
    FROM events
    GROUP BY user_id
),

first_clean AS (
    SELECT user_id, MIN(event_time) AS first_time
    FROM events_clean
    GROUP BY user_id
),

june_all AS (
    SELECT
        a.user_id,
        a.first_time,
        u.signup_time,
        (c.first_time IS NULL OR c.first_time > a.first_time) AS first_event_anomalous,
        date_trunc('month', c.first_time) = DATE '2023-06-01' AS june_on_clean_data
    FROM first_all a
    INNER JOIN users u ON u.user_id = a.user_id
    LEFT JOIN first_clean c ON c.user_id = a.user_id
    WHERE date_trunc('month', a.first_time) = DATE '2023-06-01'
),

anomalous_before_signup AS (
    SELECT
        j.user_id,
        date_diff('day', CAST(j.first_time AS DATE), CAST(j.signup_time AS DATE)) AS days_to_signup,
        (
            SELECT COUNT(DISTINCT CAST(e.event_time AS DATE))
            FROM events e
            WHERE e.user_id = j.user_id
              AND e.event_time < j.signup_time
        ) AS active_days_before_signup,
        EXISTS (
            SELECT 1
            FROM events_clean e
            WHERE e.user_id = j.user_id
              AND CAST(e.event_time AS DATE) < CAST(j.signup_time AS DATE)
        ) AS other_activity_before_signup_date
    FROM june_all j
    WHERE j.first_event_anomalous
      AND j.first_time < j.signup_time
)

SELECT
    (SELECT COUNT(*) FROM june_all) AS june_cohort_all_data,
    (SELECT COUNT(*) FROM june_all WHERE june_on_clean_data) AS also_june_on_clean_data,
    (SELECT COUNT(*) FROM june_all WHERE NOT june_on_clean_data) AS moved_from_later_cohorts,
    (SELECT COUNT(*) FROM june_all WHERE first_event_anomalous) AS first_event_anomalous,
    (SELECT COUNT(*) FROM anomalous_before_signup) AS first_event_anomalous_before_signup,
    (SELECT MEDIAN(days_to_signup) FROM anomalous_before_signup) AS median_days_to_signup,
    (SELECT MEDIAN(active_days_before_signup) FROM anomalous_before_signup) AS median_active_days_before_signup,
    (SELECT COUNT(*) FROM anomalous_before_signup WHERE other_activity_before_signup_date) AS with_other_activity_before_signup_date;
