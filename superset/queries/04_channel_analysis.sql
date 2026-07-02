-- Q4: Channel Analysis
-- Channel usage + digital migration trend over time
SELECT
    ch.channel_name,
    ch.is_digital,
    d.week_of_year,
    COUNT(*)      AS tx_count,
    SUM(f.amount) AS tx_value
FROM fact_transaction f
JOIN dim_channels ch ON f.channel_id = ch.channel_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.status = 'SUCCESS'
GROUP BY ch.channel_name, ch.is_digital, d.week_of_year
ORDER BY d.week_of_year;
