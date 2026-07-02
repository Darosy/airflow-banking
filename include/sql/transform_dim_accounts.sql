-- Transform: stg_accounts → dim_accounts
-- Cast tipe data, handle close_date kosong, tambah derived columns, deduplikasi

-- TRUNCATE TABLE dim_accounts;

INSERT INTO dim_accounts (
    account_id,
    account_no,
    account_type,
    product_name,
    currency,
    open_date,
    close_date,
    status,
    interest_rate,
    customer_id,
    branch_id,
    -- derived
    is_closed,
    account_age_years,
    tenure_segment
)
SELECT DISTINCT ON (account_id)
    account_id,
    account_no,
    account_type,
    product_name,
    currency,
    open_date::DATE,
    NULLIF(close_date, '')::DATE AS close_date,
    status,
    interest_rate,
    customer_id,
    branch_id,
    -- flag ditutup
    CASE WHEN UPPER(status) = 'CLOSED' THEN TRUE ELSE FALSE END AS is_closed,
    -- umur rekening: sampai close_date kalau sudah tutup, kalau belum sampai hari ini
    DATE_PART(
        'year',
        AGE(COALESCE(NULLIF(close_date, '')::DATE, CURRENT_DATE), open_date::DATE)
    )::SMALLINT AS account_age_years,
    -- segmentasi lama nasabah pegang rekening
    CASE
        WHEN DATE_PART('year', AGE(COALESCE(NULLIF(close_date, '')::DATE, CURRENT_DATE), open_date::DATE)) < 1 THEN 'New (<1y)'
        WHEN DATE_PART('year', AGE(COALESCE(NULLIF(close_date, '')::DATE, CURRENT_DATE), open_date::DATE)) < 3 THEN 'Growing (1-3y)'
        WHEN DATE_PART('year', AGE(COALESCE(NULLIF(close_date, '')::DATE, CURRENT_DATE), open_date::DATE)) < 7 THEN 'Established (3-7y)'
        ELSE 'Loyal (7y+)'
    END AS tenure_segment
FROM stg_accounts
WHERE account_id IS NOT NULL
ORDER BY account_id;
