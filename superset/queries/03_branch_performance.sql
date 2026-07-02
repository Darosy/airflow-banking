-- Q3: Branch Performance
-- Highest performing branches by transaction count & value, per region
SELECT
    b.branch_name,
    b.region,
    COUNT(*)      AS tx_count,
    SUM(f.amount) AS tx_value
FROM fact_transaction f
JOIN dim_branches b ON f.branch_id = b.branch_id
WHERE f.status = 'SUCCESS'
GROUP BY b.branch_name, b.region
ORDER BY tx_value DESC;
