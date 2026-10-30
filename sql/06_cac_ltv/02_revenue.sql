-- ============================================================
-- Subscription revenue
-- ============================================================

-- Revenue of a subscription = billed months × mrr_amount.
--   - Snapshot date: the last date in the subscriptions table
--     (MAX(start_date) = 2025-05-20). The latest start date is used as a
--     proxy for the end of the subscription data; it is not necessarily the
--     date up to which the data are complete. Subscriptions without end_date are
--     counted as active up to this date. Events go on to August 2025, but
--     the users, subscriptions and conversions tables end in May 2025.
--   - Billed months: every started 30-day period is billed, at least one
--     month: GREATEST(CEIL(days / 30), 1), where days run from start_date to
--     the earlier of end_date and the snapshot date (all end dates are
--     before the snapshot date in this data, so the cap changes nothing
--     here, but keeps revenue limited to the snapshot date).
-- Revenue is gross subscription revenue (no costs or margin).
--
-- An earlier version of this analysis (the LTV draft) used 2025-04-28 (the last
-- end_date) as the snapshot date and no minimum billed period.
-- Subscriptions that start on or after this date then get 0 billed months.


-- Check: the draft method vs the method used here, one change at a time
--   1. Draft: snapshot 2025-04-28, no minimum (negative months count as 0)
--   2. Snapshot 2025-05-20, no minimum
--   3. Snapshot 2025-05-20, at least one billed month (used in this notebook)
-- In step 2, the subscriptions with 0 billed months are the 7 that start on
-- the snapshot date (2025-05-20) and have no end_date.

-- export: revenue_snapshot_check.csv
WITH snapshot AS (
    SELECT MAX(start_date) AS snapshot_date
    FROM subscriptions
),

revenue AS (
    SELECT
        GREATEST(CEIL((COALESCE(end_date, DATE '2025-04-28') - start_date) / 30.0), 0) AS draft_months,
        GREATEST(CEIL((LEAST(COALESCE(end_date, (SELECT snapshot_date FROM snapshot)), (SELECT snapshot_date FROM snapshot)) - start_date) / 30.0), 0) AS months_no_minimum,
        GREATEST(CEIL((LEAST(COALESCE(end_date, (SELECT snapshot_date FROM snapshot)), (SELECT snapshot_date FROM snapshot)) - start_date) / 30.0), 1) AS months,
        mrr_amount
    FROM subscriptions
)

SELECT
    1 AS step,
    'Draft: snapshot 2025-04-28, no minimum' AS method,
    COUNT(*) FILTER (WHERE draft_months = 0) AS subscriptions_without_billed_months,
    ROUND(SUM(draft_months * mrr_amount), 2) AS total_revenue
FROM revenue
UNION ALL
SELECT
    2,
    'Snapshot 2025-05-20, no minimum',
    COUNT(*) FILTER (WHERE months_no_minimum = 0),
    ROUND(SUM(months_no_minimum * mrr_amount), 2)
FROM revenue
UNION ALL
SELECT
    3,
    'Snapshot 2025-05-20, at least one month (this notebook)',
    COUNT(*) FILTER (WHERE months = 0),
    ROUND(SUM(months * mrr_amount), 2)
FROM revenue
ORDER BY step;



-- Revenue by plan

-- export: revenue_by_plan.csv
WITH snapshot AS (
    SELECT MAX(start_date) AS snapshot_date
    FROM subscriptions
),

subscription_revenue AS (
    SELECT
        plan,
        end_date,
        mrr_amount,
        GREATEST(CEIL((LEAST(COALESCE(end_date, (SELECT snapshot_date FROM snapshot)), (SELECT snapshot_date FROM snapshot)) - start_date) / 30.0), 1) AS months
    FROM subscriptions
)

SELECT
    plan,
    COUNT(*) AS subscribers,
    COUNT(*) FILTER (WHERE end_date IS NULL) AS active_subscriptions,
    ROUND(AVG(mrr_amount), 2) AS avg_mrr,
    ROUND(AVG(months), 1) AS avg_billed_months,
    ROUND(SUM(months * mrr_amount), 2) AS revenue,
    ROUND(100.0 * SUM(months * mrr_amount) / SUM(SUM(months * mrr_amount)) OVER (), 1) AS pct_of_revenue
FROM subscription_revenue
GROUP BY plan
ORDER BY revenue DESC;
