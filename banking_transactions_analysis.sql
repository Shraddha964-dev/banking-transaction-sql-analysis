-- =============================================================================
-- BANKING TRANSACTION ANALYTICS — SQL Portfolio Project
-- Author: Shraddha Sajane
-- Dataset: Synthetic retail banking transaction data (simulating real-world use)
-- Tools: PostgreSQL / SQLite compatible
-- Description: End-to-end SQL analysis of customer banking transactions to
--              uncover spending patterns, detect anomalies, and segment customers.
-- =============================================================================


-- =============================================================================
-- SECTION 1: DATABASE SETUP & SCHEMA
-- =============================================================================

CREATE TABLE IF NOT EXISTS customers (
    customer_id     VARCHAR(10) PRIMARY KEY,
    name            VARCHAR(100),
    age             INT,
    city            VARCHAR(50),
    account_type    VARCHAR(20),   -- 'CHECKING', 'SAVINGS', 'PREMIUM'
    join_date       DATE,
    credit_score    INT
);

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id  VARCHAR(15) PRIMARY KEY,
    customer_id     VARCHAR(10),
    txn_date        DATE,
    txn_time        TIME,
    amount          DECIMAL(10,2),
    txn_type        VARCHAR(20),   -- 'DEBIT', 'CREDIT'
    category        VARCHAR(30),   -- 'FOOD', 'TRAVEL', 'SHOPPING', 'UTILITIES', etc.
    merchant        VARCHAR(100),
    channel         VARCHAR(20),   -- 'MOBILE', 'ATM', 'ONLINE', 'BRANCH'
    status          VARCHAR(15)    -- 'COMPLETED', 'PENDING', 'DECLINED'
);


-- =============================================================================
-- SECTION 2: EXPLORATORY DATA ANALYSIS (EDA)
-- =============================================================================

-- Q1: What is the overall transaction volume and value by month?
SELECT
    DATE_TRUNC('month', txn_date)       AS month,
    COUNT(*)                             AS total_transactions,
    ROUND(SUM(amount), 2)                AS total_volume,
    ROUND(AVG(amount), 2)                AS avg_transaction_value,
    COUNT(DISTINCT customer_id)          AS unique_customers
FROM transactions
WHERE status = 'COMPLETED'
GROUP BY 1
ORDER BY 1;


-- Q2: Which spending categories drive the most revenue?
SELECT
    category,
    COUNT(*)                                                        AS num_transactions,
    ROUND(SUM(amount), 2)                                           AS total_spend,
    ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER (), 2)       AS pct_of_total,
    ROUND(AVG(amount), 2)                                           AS avg_spend
FROM transactions
WHERE txn_type = 'DEBIT' AND status = 'COMPLETED'
GROUP BY category
ORDER BY total_spend DESC;


-- Q3: What channels do customers prefer, and how does channel affect average spend?
SELECT
    channel,
    COUNT(*)                        AS num_transactions,
    ROUND(AVG(amount), 2)           AS avg_amount,
    ROUND(SUM(amount), 2)           AS total_amount,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 2) AS pct_of_transactions
FROM transactions
WHERE status = 'COMPLETED'
GROUP BY channel
ORDER BY num_transactions DESC;


-- =============================================================================
-- SECTION 3: CUSTOMER SPENDING BEHAVIOR
-- =============================================================================

-- Q4: Rank customers by total spend (top spenders)
SELECT
    c.customer_id,
    c.name,
    c.account_type,
    c.city,
    COUNT(t.transaction_id)                                      AS num_transactions,
    ROUND(SUM(t.amount), 2)                                      AS total_spend,
    ROUND(AVG(t.amount), 2)                                      AS avg_spend,
    RANK() OVER (ORDER BY SUM(t.amount) DESC)                    AS spend_rank
FROM customers c
JOIN transactions t ON c.customer_id = t.customer_id
WHERE t.txn_type = 'DEBIT' AND t.status = 'COMPLETED'
GROUP BY c.customer_id, c.name, c.account_type, c.city
ORDER BY total_spend DESC
LIMIT 20;


-- Q5: Month-over-month spending growth per customer (using window functions)
WITH monthly_spend AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', txn_date)   AS month,
        ROUND(SUM(amount), 2)            AS monthly_spend
    FROM transactions
    WHERE txn_type = 'DEBIT' AND status = 'COMPLETED'
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
),
mom_growth AS (
    SELECT
        customer_id,
        month,
        monthly_spend,
        LAG(monthly_spend) OVER (PARTITION BY customer_id ORDER BY month) AS prev_month_spend,
        ROUND(
            (monthly_spend - LAG(monthly_spend) OVER (PARTITION BY customer_id ORDER BY month))
            * 100.0
            / NULLIF(LAG(monthly_spend) OVER (PARTITION BY customer_id ORDER BY month), 0),
        2) AS mom_growth_pct
    FROM monthly_spend
)
SELECT * FROM mom_growth
WHERE prev_month_spend IS NOT NULL
ORDER BY customer_id, month;


-- Q6: Customer activity streaks — how many consecutive months has each customer transacted?
WITH monthly_activity AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', txn_date) AS active_month
    FROM transactions
    WHERE status = 'COMPLETED'
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
),
ranked AS (
    SELECT
        customer_id,
        active_month,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY active_month) AS rn,
        active_month - (ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY active_month) * INTERVAL '1 month') AS grp
    FROM monthly_activity
),
streaks AS (
    SELECT
        customer_id,
        grp,
        COUNT(*) AS streak_length,
        MIN(active_month) AS streak_start,
        MAX(active_month) AS streak_end
    FROM ranked
    GROUP BY customer_id, grp
)
SELECT
    customer_id,
    MAX(streak_length) AS longest_consecutive_active_months
FROM streaks
GROUP BY customer_id
ORDER BY longest_consecutive_active_months DESC;


-- =============================================================================
-- SECTION 4: ANOMALY & FRAUD DETECTION
-- =============================================================================

-- Q7: Flag transactions that are statistical outliers (>3 std deviations above customer's mean)
WITH customer_stats AS (
    SELECT
        customer_id,
        AVG(amount)     AS avg_amount,
        STDDEV(amount)  AS std_amount
    FROM transactions
    WHERE txn_type = 'DEBIT' AND status = 'COMPLETED'
    GROUP BY customer_id
),
flagged AS (
    SELECT
        t.transaction_id,
        t.customer_id,
        t.txn_date,
        t.amount,
        t.merchant,
        t.category,
        cs.avg_amount,
        cs.std_amount,
        ROUND((t.amount - cs.avg_amount) / NULLIF(cs.std_amount, 0), 2) AS z_score
    FROM transactions t
    JOIN customer_stats cs ON t.customer_id = cs.customer_id
    WHERE t.txn_type = 'DEBIT' AND t.status = 'COMPLETED'
)
SELECT *
FROM flagged
WHERE z_score > 3
ORDER BY z_score DESC;


-- Q8: Detect potential fraudulent patterns — multiple transactions within 10 minutes
WITH time_gaps AS (
    SELECT
        transaction_id,
        customer_id,
        txn_date,
        txn_time,
        amount,
        merchant,
        LAG(txn_time) OVER (PARTITION BY customer_id, txn_date ORDER BY txn_time)  AS prev_txn_time,
        EXTRACT(EPOCH FROM (txn_time - LAG(txn_time) OVER (PARTITION BY customer_id, txn_date ORDER BY txn_time))) / 60
            AS minutes_since_last_txn
    FROM transactions
    WHERE status = 'COMPLETED' AND txn_type = 'DEBIT'
)
SELECT *
FROM time_gaps
WHERE minutes_since_last_txn IS NOT NULL
  AND minutes_since_last_txn < 10
ORDER BY customer_id, txn_date, txn_time;


-- Q9: Customers with unusually high decline rates (potential fraud probe)
SELECT
    customer_id,
    COUNT(*) FILTER (WHERE status = 'DECLINED')     AS declined_txns,
    COUNT(*)                                          AS total_txns,
    ROUND(COUNT(*) FILTER (WHERE status = 'DECLINED') * 100.0 / COUNT(*), 2) AS decline_rate_pct
FROM transactions
GROUP BY customer_id
HAVING COUNT(*) > 5
   AND COUNT(*) FILTER (WHERE status = 'DECLINED') * 100.0 / COUNT(*) > 30
ORDER BY decline_rate_pct DESC;


-- =============================================================================
-- SECTION 5: RFM CUSTOMER SEGMENTATION (Pure SQL — mirrors Python project)
-- =============================================================================

-- Q10: Calculate RFM scores for every customer
WITH rfm_raw AS (
    SELECT
        customer_id,
        CURRENT_DATE - MAX(txn_date)        AS recency_days,       -- R: days since last transaction
        COUNT(DISTINCT txn_date)             AS frequency,           -- F: number of active days
        ROUND(SUM(amount), 2)                AS monetary             -- M: total spend
    FROM transactions
    WHERE txn_type = 'DEBIT' AND status = 'COMPLETED'
    GROUP BY customer_id
),
rfm_scored AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days ASC)   AS r_score,   -- lower recency = better
        NTILE(5) OVER (ORDER BY frequency DESC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC)       AS m_score
    FROM rfm_raw
),
rfm_segmented AS (
    SELECT
        *,
        CONCAT(r_score, f_score, m_score)            AS rfm_code,
        (r_score + f_score + m_score)                AS rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
            WHEN r_score >= 3 AND f_score >= 3                   THEN 'Loyal Customer'
            WHEN r_score >= 4 AND f_score <= 2                   THEN 'New Customer'
            WHEN r_score <= 2 AND f_score >= 3                   THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2                   THEN 'Lost Customer'
            ELSE 'Potential Loyalist'
        END AS segment
    FROM rfm_scored
)
SELECT
    segment,
    COUNT(*)                        AS num_customers,
    ROUND(AVG(recency_days), 1)     AS avg_recency_days,
    ROUND(AVG(frequency), 1)        AS avg_frequency,
    ROUND(AVG(monetary), 2)         AS avg_monetary,
    ROUND(SUM(monetary), 2)         AS total_revenue_contribution
FROM rfm_segmented
GROUP BY segment
ORDER BY total_revenue_contribution DESC;


-- =============================================================================
-- SECTION 6: COHORT RETENTION ANALYSIS
-- =============================================================================

-- Q11: Monthly cohort retention — what % of each cohort returns each month?
WITH first_txn AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(txn_date)) AS cohort_month
    FROM transactions
    WHERE status = 'COMPLETED'
    GROUP BY customer_id
),
activity AS (
    SELECT
        t.customer_id,
        f.cohort_month,
        DATE_TRUNC('month', t.txn_date) AS activity_month
    FROM transactions t
    JOIN first_txn f ON t.customer_id = f.customer_id
    WHERE t.status = 'COMPLETED'
    GROUP BY t.customer_id, f.cohort_month, DATE_TRUNC('month', t.txn_date)
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS num_customers
    FROM first_txn GROUP BY cohort_month
),
retention AS (
    SELECT
        a.cohort_month,
        EXTRACT(MONTH FROM AGE(a.activity_month, a.cohort_month)) AS months_since_join,
        COUNT(DISTINCT a.customer_id) AS retained_customers
    FROM activity a
    GROUP BY a.cohort_month, months_since_join
)
SELECT
    r.cohort_month,
    r.months_since_join,
    cs.num_customers AS cohort_size,
    r.retained_customers,
    ROUND(r.retained_customers * 100.0 / cs.num_customers, 1) AS retention_pct
FROM retention r
JOIN cohort_size cs ON r.cohort_month = cs.cohort_month
ORDER BY r.cohort_month, r.months_since_join;
