-- Q6: Risk & Fraud Detection
-- High-value / high fraud-score transactions
SELECT
    f.transaction_code,
    c.full_name,
    ch.channel_name,
    f.amount,
    f.status,
    f.fraud_score
FROM fact_transaction f
JOIN dim_customers c ON f.customer_id = c.customer_id
JOIN dim_channels ch ON f.channel_id = ch.channel_id
WHERE f.is_fraud = TRUE OR f.fraud_score > 0.7
ORDER BY f.fraud_score DESC
LIMIT 20;

-- Accounts with repeated FAILED transactions
SELECT account_id, COUNT(*) AS failed_count
FROM fact_transaction
WHERE status = 'FAILED'
GROUP BY account_id
HAVING COUNT(*) >= 3
ORDER BY failed_count DESC;
