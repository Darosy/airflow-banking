-- Transform: stg_branches → dim_branches
-- Cast tipe data, tambah derived columns, deduplikasi

-- TRUNCATE TABLE dim_branches;

INSERT INTO dim_branches (
    branch_id,
    branch_code,
    branch_name,
    city,
    province,
    region,
    branch_type,
    open_date,
    is_active,
    -- derived
    branch_age_years
)
SELECT DISTINCT ON (branch_id)
    branch_id,
    branch_code,
    branch_name,
    city,
    province,
    region,
    branch_type,
    open_date::DATE,
    CASE WHEN LOWER(is_active) = 'true' THEN TRUE ELSE FALSE END AS is_active,
    -- usia cabang dari open_date
    DATE_PART('year', AGE(CURRENT_DATE, open_date::DATE))::SMALLINT AS branch_age_years
FROM stg_branches
WHERE branch_id IS NOT NULL
ORDER BY branch_id;
