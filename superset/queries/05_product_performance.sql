-- Q5: Product Performance
-- Which account product drives the highest volume & avg balance
SELECT
    a.product_name,
    COUNT(f.transaction_id)     AS tx_count,
    SUM(f.amount)                AS tx_value,
    AVG(f.balance_after)          AS avg_balance
FROM fact_transaction f
JOIN dim_accounts a ON f.account_id = a.account_id
WHERE f.status = 'SUCCESS'
GROUP BY a.product_name
ORDER BY tx_value DESC;
