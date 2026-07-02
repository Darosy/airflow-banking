-- Transform: stg_transactions + stg_fraud_labels → fact_transaction
-- fraud_labels di-LEFT JOIN & digabung langsung ke fact_transaction (bukan tabel dw terpisah)

-- TRUNCATE TABLE fact_transaction;

INSERT INTO fact_transaction (
    transaction_id,
    transaction_code,
    account_id,
    customer_id,
    branch_id,
    channel_id,
    date_id,
    transaction_at,
    transaction_type,
    amount,
    balance_before,
    balance_after,
    status,
    reference_no,
    is_fraud,
    fraud_type,
    fraud_score,
    -- derived
    transaction_hour,
    is_weekend_transaction,
    amount_segment,
    is_success
)
SELECT DISTINCT ON (t.transaction_id)
    t.transaction_id,
    t.transaction_code,
    t.account_id,
    t.customer_id,
    t.branch_id,
    t.channel_id,
    -- date_id dibentuk dari transaction_date, format YYYYMMDD, match dim_date
    TO_CHAR(t.transaction_date::DATE, 'YYYYMMDD')::INT AS date_id,
    t.transaction_at::TIMESTAMP,
    UPPER(t.transaction_type) AS transaction_type,
    t.amount,
    t.balance_before,
    t.balance_after,
    UPPER(t.status) AS status,
    t.reference_no,
    -- text 'true'/'false' -> boolean, NULL (tidak ada di fraud_labels) otomatis jatuh ke FALSE
    CASE WHEN LOWER(f.is_fraud) = 'true' THEN TRUE ELSE FALSE END AS is_fraud,
    f.fraud_type,
    f.fraud_score,
    -- jam transaksi, berguna utk pola fraud/peak hour
    DATE_PART('hour', t.transaction_at::TIMESTAMP)::SMALLINT AS transaction_hour,
    -- transaksi jatuh di weekend atau bukan
    CASE WHEN EXTRACT(ISODOW FROM t.transaction_date::DATE) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend_transaction,
    -- segmentasi nominal transaksi
    CASE
        WHEN t.amount <   100000  THEN 'Micro'
        WHEN t.amount <  1000000  THEN 'Small'
        WHEN t.amount <  5000000  THEN 'Medium'
        WHEN t.amount < 20000000  THEN 'Large'
        ELSE 'Very Large'
    END AS amount_segment,
    CASE WHEN UPPER(t.status) = 'SUCCESS' THEN TRUE ELSE FALSE END AS is_success
FROM stg_transactions t
LEFT JOIN stg_fraud_labels f
       ON t.transaction_id = f.transaction_id
WHERE t.transaction_id IS NOT NULL
ORDER BY t.transaction_id;
