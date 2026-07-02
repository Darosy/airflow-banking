-- ============================================================
-- DDL: Staging tables
-- Prinsip: kolom id/angka pakai tipe asli (utk PK & join),
-- kolom lain (tanggal, boolean, teks) disimpan TEXT apa adanya.
-- Casting & cleansing dilakukan di layer transform (dim_*/fact_*).
-- ============================================================

CREATE TABLE IF NOT EXISTS stg_branches (
    branch_id     INT PRIMARY KEY,
    branch_code   TEXT,
    branch_name   TEXT,
    city          TEXT,
    province      TEXT,
    region        TEXT,
    branch_type   TEXT,
    open_date     TEXT,
    is_active     TEXT
);

CREATE TABLE IF NOT EXISTS stg_channels (
    channel_id        INT PRIMARY KEY,
    channel_code      TEXT,
    channel_name      TEXT,
    channel_category  TEXT,
    is_digital        TEXT,
    description       TEXT
);

CREATE TABLE IF NOT EXISTS stg_dim_date (
    date_id       INT PRIMARY KEY,
    full_date     TEXT,
    year          INT,
    quarter       INT,
    month         INT,
    month_name    TEXT,
    week_of_year  INT,
    day_of_month  INT,
    day_of_week   INT,
    day_name      TEXT,
    is_weekend    TEXT,
    is_holiday    TEXT
);

CREATE TABLE IF NOT EXISTS stg_customers (
    customer_id        INT PRIMARY KEY,
    customer_code       TEXT,
    full_name           TEXT,
    gender               TEXT,
    birth_date           TEXT,
    email                 TEXT,
    phone                 TEXT,
    segment               TEXT,
    job_segment           TEXT,
    city                  TEXT,
    province              TEXT,
    registration_date     TEXT,
    branch_id             INT,
    is_active             TEXT,
    credit_score          INT,
    estimated_salary      NUMERIC
);

CREATE TABLE IF NOT EXISTS stg_accounts (
    account_id     INT PRIMARY KEY,
    account_no     TEXT,
    account_type   TEXT,
    product_name   TEXT,
    currency       TEXT,
    open_date      TEXT,
    close_date     TEXT,
    status         TEXT,
    interest_rate  NUMERIC,
    customer_id    INT,
    branch_id      INT
);

CREATE TABLE IF NOT EXISTS stg_transactions (
    transaction_id     INT PRIMARY KEY,
    transaction_code   TEXT,
    account_id         INT,
    customer_id        INT,
    branch_id          INT,
    channel_id         INT,
    transaction_date   TEXT,
    transaction_at     TEXT,
    transaction_type   TEXT,
    amount             NUMERIC,
    balance_before     NUMERIC,
    balance_after      NUMERIC,
    status             TEXT,
    reference_no       TEXT
);

CREATE TABLE IF NOT EXISTS stg_fraud_labels (
    transaction_id     INT PRIMARY KEY,
    transaction_code   TEXT,
    is_fraud           TEXT,
    fraud_type         TEXT,
    fraud_score        NUMERIC,
    flagged_at         TEXT
);
