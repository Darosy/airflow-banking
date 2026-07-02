-- Q2: Customer 360
-- Most active customers by frequency/value + distribution by segment
SELECT
    c.customer_id,
    c.full_name,
    c.segment,
    COUNT(f.transaction_id) AS tx_freq,
    SUM(f.amount)             AS tx_value
FROM fact_transaction f
JOIN dim_customers c ON f.customer_id = c.customer_id
WHERE f.status = 'SUCCESS'
GROUP BY c.customer_id, c.full_name, c.segment
ORDER BY tx_value DESC
LIMIT 20;

-- Segment distribution
SELECT segment, COUNT(*) AS customer_count
FROM dim_customers
GROUP BY segment;
