-- ============================================================
-- DDL: Star Schema (dw)
-- ============================================================

CREATE TABLE IF NOT EXISTS dim_branches (
    branch_id          INT PRIMARY KEY,
    branch_code        VARCHAR(20),
    branch_name        VARCHAR(100),
    city               VARCHAR(50),
    province           VARCHAR(50),
    region             VARCHAR(50),
    branch_type        VARCHAR(10),
    open_date          DATE,
    is_active          BOOLEAN,
    branch_age_years   SMALLINT
);

CREATE TABLE IF NOT EXISTS dim_channels (
    channel_id        INT PRIMARY KEY,
    channel_code      VARCHAR(20),
    channel_name      VARCHAR(50),
    channel_category  VARCHAR(20),
    is_digital        BOOLEAN,
    description       VARCHAR(200)
);

CREATE TABLE IF NOT EXISTS dim_date (
    date_id            INT PRIMARY KEY,
    full_date          DATE,
    year               INT,
    quarter            INT,
    month              INT,
    month_name         VARCHAR(20),
    week_of_year       INT,
    day_of_month       INT,
    day_of_week        INT,
    day_name           VARCHAR(20),
    is_weekend         BOOLEAN,
    is_holiday         BOOLEAN,
    is_business_day    BOOLEAN,
    month_year_label   VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS dim_customers (
    customer_id             INT PRIMARY KEY,
    customer_code           VARCHAR(20),
    full_name               VARCHAR(100),
    gender                  VARCHAR(1),
    birth_date               DATE,
    email                    VARCHAR(100),
    phone                    VARCHAR(20),
    segment                  VARCHAR(20),
    job_segment              VARCHAR(50),
    city                     VARCHAR(50),
    province                 VARCHAR(50),
    registration_date        DATE,
    branch_id                INT REFERENCES dim_branches(branch_id),
    is_active                BOOLEAN,
    credit_score             INT,
    estimated_salary         NUMERIC(15,2),
    age                      SMALLINT,
    credit_score_segment     VARCHAR(20),
    salary_segment           VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS dim_accounts (
    account_id         INT PRIMARY KEY,
    account_no         VARCHAR(20),
    account_type       VARCHAR(20),
    product_name       VARCHAR(50),
    currency           VARCHAR(5),
    open_date          DATE,
    close_date         DATE,
    status             VARCHAR(10),
    interest_rate      NUMERIC(5,2),
    customer_id        INT REFERENCES dim_customers(customer_id),
    branch_id          INT REFERENCES dim_branches(branch_id),
    is_closed          BOOLEAN,
    account_age_years  SMALLINT,
    tenure_segment     VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS fact_transaction (
    transaction_id           INT PRIMARY KEY,
    transaction_code         VARCHAR(20),
    account_id               INT REFERENCES dim_accounts(account_id),
    customer_id               INT REFERENCES dim_customers(customer_id),
    branch_id                 INT REFERENCES dim_branches(branch_id),
    channel_id                INT REFERENCES dim_channels(channel_id),
    date_id                   INT REFERENCES dim_date(date_id),
    transaction_at             TIMESTAMP,
    transaction_type           VARCHAR(20),
    amount                     NUMERIC(15,2),
    balance_before             NUMERIC(15,2),
    balance_after              NUMERIC(15,2),
    status                     VARCHAR(10),
    reference_no               VARCHAR(30),
    is_fraud                   BOOLEAN DEFAULT FALSE,
    fraud_type                 VARCHAR(30),
    fraud_score                NUMERIC(6,4),
    transaction_hour            SMALLINT,
    is_weekend_transaction       BOOLEAN,
    amount_segment                VARCHAR(20),
    is_success                    BOOLEAN
);
