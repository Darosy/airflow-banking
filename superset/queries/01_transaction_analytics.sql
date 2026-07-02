-- Q1: Transaction Analytics
-- Total volume & value of transactions per day/week/month + growth trend
SELECT
    d.full_date,
    d.week_of_year,
    d.month_year_label,
    COUNT(*)          AS tx_volume,
    SUM(f.amount)      AS tx_value
FROM fact_transaction f
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.status = 'SUCCESS'
GROUP BY d.full_date, d.week_of_year, d.month_year_label
ORDER BY d.full_date;
