-- Transform: stg_dim_date → dim_date
-- Cast tipe data, tambah derived columns, deduplikasi

-- TRUNCATE TABLE dim_date;

INSERT INTO dim_date (
    date_id,
    full_date,
    year,
    quarter,
    month,
    month_name,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend,
    is_holiday,
    -- derived
    is_business_day,
    month_year_label
)
SELECT DISTINCT ON (date_id)
    date_id,
    full_date::DATE,
    year,
    quarter,
    month,
    month_name,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    CASE WHEN LOWER(is_weekend) = 'true' THEN TRUE ELSE FALSE END AS is_weekend,
    CASE WHEN LOWER(is_holiday) = 'true' THEN TRUE ELSE FALSE END AS is_holiday,
    -- hari kerja = bukan weekend & bukan holiday
    CASE
        WHEN LOWER(is_weekend) = 'false' AND LOWER(is_holiday) = 'false'
        THEN TRUE ELSE FALSE
    END AS is_business_day,
    -- label 'Jan 2024' utk kebutuhan reporting
    TO_CHAR(full_date::DATE, 'Mon YYYY') AS month_year_label
FROM stg_dim_date
WHERE date_id IS NOT NULL
ORDER BY date_id;
